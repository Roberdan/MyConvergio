import concurrent.futures
import configparser
import json
import os
import shlex
import socket
import subprocess
import time

from pathlib import Path

from middleware import PEERS_CONF, query, query_one

_sync_cache: dict = {"data": None, "ts": 0}


def parse_peers_conf() -> list[dict]:
    if not PEERS_CONF.exists():
        return []
    cp = configparser.ConfigParser()
    cp.read(str(PEERS_CONF))
    return [
        {
            "peer_name": s,
            "os": cp[s].get("os", "unknown"),
            "role": cp[s].get("role", "worker"),
            "capabilities": cp[s].get("capabilities", ""),
            "status": cp[s].get("status", "active"),
            "tailscale_ip": cp[s].get("tailscale_ip", ""),
            "mac_address": cp[s].get("mac_address", ""),
            "ssh_alias": cp[s].get("ssh_alias", s),
            "user": cp[s].get("user", ""),
        }
        for s in cp.sections()
    ]


def find_peer_conf(peer_name: str) -> dict | None:
    return next((p for p in parse_peers_conf() if p["peer_name"] == peer_name), None)


def send_wol(mac: str, broadcast: str = "255.255.255.255", port: int = 9) -> bool:
    mac_clean = mac.replace(":", "").replace("-", "")
    if len(mac_clean) != 12:
        return False
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(b"\xff" * 6 + bytes.fromhex(mac_clean) * 16, (broadcast, port))
        sock.close()
        return True
    except OSError:
        return False


def peer_host_match(peer_name: str, host: str) -> bool:
    pn, eh = peer_name.lower().replace("-", "").replace("_", ""), host.lower().replace(
        "-", ""
    ).replace("_", "")
    return pn == eh or pn in eh or eh in pn


def resolve_host_to_peer(host: str) -> str:
    if not host or host == "None":
        return ""
    conf = parse_peers_conf()
    exact = next((p["peer_name"] for p in conf if p["peer_name"] == host), "")
    if exact:
        return exact
    h = host.lower().replace("-", "").replace("_", "")
    for p in conf:
        for c in [p["peer_name"], p.get("ssh_alias", ""), p.get("dns_name", "")]:
            if c and (
                c.lower().replace("-", "").replace("_", "") in h
                or h in c.lower().replace("-", "").replace("_", "")
            ):
                return p["peer_name"]
    return host


def _extract_heartbeat(hb: dict) -> tuple[float, int]:
    cpu, tasks, lj = 0.0, 0, hb.get("load_json")
    if lj and lj != "null":
        try:
            d = json.loads(lj)
            cpu = (
                float(d.get("cpu_load", d.get("cpu_load_1", 0)))
                if isinstance(d, dict)
                else 0
            )
            tasks = (
                int(d.get("active_tasks", d.get("tasks_in_progress", 0)))
                if isinstance(d, dict)
                else 0
            )
        except Exception:
            pass
    return (
        cpu or float(hb.get("cpu_load_1m") or 0),
        tasks or int(hb.get("active_tasks") or 0),
    )


def _tailscale_online_ips() -> set[str]:
    try:
        r = subprocess.run(
            ["tailscale", "status"], capture_output=True, text=True, timeout=5
        )
        return {
            ln.split()[0]
            for ln in r.stdout.splitlines()
            if ln.strip()
            and not ln.startswith("#")
            and "offline" not in ln
            and len(ln.split()) >= 2
        }
    except Exception:
        return set()


def _peer_execution_map() -> dict[str, list[dict]]:
    plans = query(
        "SELECT id,name,status,tasks_done,tasks_total,execution_host FROM plans WHERE status IN ('doing','todo') AND execution_host IS NOT NULL AND execution_host<>''"
    )
    result: dict[str, list[dict]] = {}
    for p in plans:
        active = query(
            "SELECT task_id,title,status,executor_agent FROM tasks WHERE plan_id=? AND status IN ('in_progress','submitted','blocked') ORDER BY id LIMIT 5",
            (p["id"],),
        )
        result.setdefault(p["execution_host"], []).append(
            {
                "id": p["id"],
                "name": p["name"],
                "status": p["status"],
                "tasks_done": p["tasks_done"],
                "tasks_total": p["tasks_total"],
                "active_tasks": active,
            }
        )
    return result


_remote_cache: dict = {}  # {peer_name: {"data": [...], "ts": float}}
_REMOTE_TTL = 30  # seconds


def _query_remote_plans(ssh_dest: str) -> list[dict]:
    """SSH to a remote peer and query its active plans + tasks."""
    sql = (
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,"
        "COALESCE(GROUP_CONCAT(CASE WHEN t.status IN ('in_progress','submitted','blocked') "
        "THEN t.task_id||'|'||COALESCE(t.title,'')||'|'||t.status END, ';;'), '') as active "
        "FROM plans p LEFT JOIN tasks t ON t.plan_id=p.id "
        "WHERE p.status IN ('doing','todo') GROUP BY p.id"
    )
    try:
        r = subprocess.run(
            [
                "ssh",
                "-o",
                "ConnectTimeout=3",
                "-o",
                "BatchMode=yes",
                ssh_dest,
                f'sqlite3 ~/.claude/data/dashboard.db ".timeout 3000" "{sql}"',
            ],
            capture_output=True,
            text=True,
            timeout=8,
        )
        if r.returncode != 0:
            return []
        plans = []
        for line in r.stdout.strip().splitlines():
            parts = line.split("|", 5)
            if len(parts) < 5:
                continue
            active_tasks = []
            if len(parts) > 5 and parts[5]:
                for chunk in parts[5].split(";;"):
                    tp = chunk.split("|", 2)
                    if len(tp) >= 3 and tp[0]:
                        active_tasks.append(
                            {"task_id": tp[0], "title": tp[1], "status": tp[2]}
                        )
            plans.append(
                {
                    "id": int(parts[0]),
                    "name": parts[1],
                    "status": parts[2],
                    "tasks_done": int(parts[3] or 0),
                    "tasks_total": int(parts[4] or 0),
                    "active_tasks": active_tasks,
                }
            )
        return plans
    except Exception:
        return []


def _get_remote_plans(peer_name: str, ssh_dest: str) -> list[dict]:
    """Get remote plans with 30s cache."""
    now = time.time()
    cached = _remote_cache.get(peer_name)
    if cached and (now - cached["ts"]) < _REMOTE_TTL:
        return cached["data"]
    plans = _query_remote_plans(ssh_dest)
    if plans:  # only cache successful results
        _remote_cache[peer_name] = {"data": plans, "ts": now}
    return plans or (cached["data"] if cached else [])


def api_mesh() -> list[dict]:
    conf, hb_map, ts_online, local_exec_map, now = (
        parse_peers_conf(),
        {r["peer_name"]: r for r in query("SELECT * FROM peer_heartbeats")},
        _tailscale_online_ips(),
        _peer_execution_map(),
        time.time(),
    )
    sources = (
        conf
        if conf
        else [
            {
                "peer_name": r["peer_name"],
                "os": "unknown",
                "role": "worker",
                "capabilities": r.get("capabilities", ""),
                "status": "active",
                "tailscale_ip": "",
            }
            for r in hb_map.values()
        ]
    )
    result = []
    for p in sources:
        if p["status"] != "active":
            continue
        hb, is_local = hb_map.get(p["peer_name"], {}), p["role"] == "coordinator"
        is_online = (
            is_local
            or (now - (hb.get("last_seen") or 0)) < 300
            or p.get("tailscale_ip", "") in ts_online
        )
        cpu, tasks = _extract_heartbeat(hb)
        # Local node: use local DB data
        if is_local:
            plans = [
                e
                for host, host_plans in local_exec_map.items()
                if peer_host_match(p["peer_name"], host)
                for e in host_plans
            ]
        elif is_online:
            # Remote online node: query its DB via SSH (cached 30s)
            plans = _get_remote_plans(
                p["peer_name"], p.get("ssh_alias", p["peer_name"])
            )
            # Fallback to local exec_map if SSH query returned nothing
            if not plans:
                plans = [
                    e
                    for host, host_plans in local_exec_map.items()
                    if peer_host_match(p["peer_name"], host)
                    for e in host_plans
                ]
        else:
            plans = [
                e
                for host, host_plans in local_exec_map.items()
                if peer_host_match(p["peer_name"], host)
                for e in host_plans
            ]
        result.append(
            {
                "peer_name": p["peer_name"],
                "os": p["os"],
                "role": p["role"],
                "capabilities": p["capabilities"],
                "tailscale_ip": p["tailscale_ip"],
                "is_online": is_online,
                "is_local": is_local,
                "cpu": cpu,
                "active_tasks": tasks,
                "plans": plans,
            }
        )
    return result


def _check_peer_sync(peer_name: str, user: str, host: str) -> dict:
    try:
        local_sha = subprocess.run(
            ["git", "-C", str(Path.home() / ".claude"), "log", "--oneline", "-1"],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout.strip()
    except Exception:
        local_sha = ""
    try:
        remote = subprocess.run(
            [
                "ssh",
                "-o",
                "ConnectTimeout=5",
                "-o",
                "BatchMode=yes",
                host,
                "-l",
                user,
                "git -C ~/.claude log --oneline -1",
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if remote.returncode != 0:
            return {
                "peer_name": peer_name,
                "reachable": False,
                "config_synced": None,
                "last_heartbeat_age_sec": -1,
            }
        remote_sha = remote.stdout.strip()
        return {
            "peer_name": peer_name,
            "reachable": True,
            "config_synced": bool(local_sha and remote_sha and local_sha == remote_sha),
            "last_heartbeat_age_sec": -1,
        }
    except Exception:
        return {
            "peer_name": peer_name,
            "reachable": False,
            "config_synced": None,
            "last_heartbeat_age_sec": -1,
        }


def api_mesh_sync_status() -> list[dict]:
    now = time.time()
    if _sync_cache["data"] is not None and (now - _sync_cache["ts"]) < 60:
        return _sync_cache["data"]
    cp = configparser.ConfigParser()
    cp.read(str(PEERS_CONF))
    peers = (
        [
            {
                "peer_name": s,
                "user": cp[s].get("user", ""),
                "host": cp[s].get("ssh_alias", s),
            }
            for s in cp.sections()
            if cp[s].get("status", "active") == "active"
        ]
        if PEERS_CONF.exists()
        else []
    )
    hb_map = {
        r["peer_name"]: r["last_seen"]
        for r in query("SELECT peer_name, last_seen FROM peer_heartbeats")
    }
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        results = list(
            pool.map(
                lambda p: _check_peer_sync(p["peer_name"], p["user"], p["host"]), peers
            )
        )
    for e in results:
        e["last_heartbeat_age_sec"] = (
            int(now - hb_map[e["peer_name"]]) if hb_map.get(e["peer_name"]) else -1
        )
    _sync_cache.update({"data": results, "ts": now})
    return results


def handle_mesh_action(qs: dict, safe_name) -> dict:
    scripts = Path.home() / ".claude" / "scripts"
    action = qs.get("action", [""])[0]
    peer = qs.get("peer", [""])[0]
    if not peer:
        return {"error": "missing peer", "output": ""}
    is_all = peer == "__all__"
    if not is_all and not safe_name.match(peer):
        return {"error": "invalid peer name", "output": ""}
    peer_flag = "" if is_all else f"--peer {shlex.quote(peer)}"
    cmd = {
        "sync": f"{scripts}/mesh-sync-all.sh {peer_flag}",
        "heartbeat": f"{scripts}/mesh-heartbeat.sh status",
        "auth": f"{scripts}/mesh-auth-sync.sh push {'--all' if is_all else f'--peer {shlex.quote(peer)}'}",
        "status": f"{scripts}/mesh-load-query.sh {'--json' if is_all else f'--peer {shlex.quote(peer)} --json'}",
    }.get(action)
    if not cmd:
        return {"error": "invalid action", "output": ""}
    try:
        r = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=120 if is_all else 30,
        )
        return {"output": r.stdout + r.stderr, "exit_code": r.returncode}
    except subprocess.TimeoutExpired:
        return {"output": f"Timeout ({120 if is_all else 30}s)", "exit_code": 1}


def _ssh_ok(dest: str, timeout: int = 5) -> bool:
    try:
        return (
            subprocess.run(
                [
                    "ssh",
                    "-o",
                    "ConnectTimeout=3",
                    "-o",
                    "BatchMode=yes",
                    dest,
                    "echo ok",
                ],
                capture_output=True,
                text=True,
                timeout=timeout,
            ).returncode
            == 0
        )
    except Exception:
        return False


def handle_power_action_sse(handler, action: str, peer: str):
    handler._start_sse()
    pc = find_peer_conf(peer)
    if not pc:
        handler._sse_send("log", f"✗ Peer '{peer}' not found in peers.conf")
        handler._sse_send("done", {"ok": False, "message": "Peer not found"})
        return
    ssh_dest = pc.get("ssh_alias", peer)
    if action == "wake":
        mac = pc.get("mac_address", "")
        handler._sse_send("log", f"▶ Wake-on-LAN — {peer}")
        if not mac:
            handler._sse_send(
                "log", f"✗ No mac_address configured for {peer} in peers.conf"
            )
            handler._sse_send(
                "done", {"ok": False, "message": "No MAC address configured"}
            )
            return
        handler._sse_send("log", f"  MAC: {mac}")
        handler._sse_send(
            "log", "  Sending magic packet (broadcast 255.255.255.255:9)…"
        )
        sent = 0
        for _ in range(3):
            sent += 1 if send_wol(mac) else 0
            time.sleep(0.3)
        if sent == 0:
            handler._sse_send("log", "✗ Failed to send magic packet")
            handler._sse_send("done", {"ok": False, "message": "WoL send failed"})
            return
        handler._sse_send("log", f"✓ {sent}/3 magic packets sent")
        handler._sse_send("log", "")
        handler._sse_send("log", "  Waiting 15s for node to boot…")
        for i in range(3):
            time.sleep(5)
            handler._sse_send("log", f"  Ping attempt {i + 1}/3…")
            if _ssh_ok(ssh_dest):
                handler._sse_send("log", f"✓ {peer} is online!")
                handler._sse_send("done", {"ok": True})
                return
        handler._sse_send(
            "log", "⚠ Node not responding yet — may need more time to boot"
        )
        handler._sse_send(
            "done", {"ok": True, "message": "WoL sent, node still booting"}
        )
        return
    handler._sse_send("log", f"▶ SSH Reboot — {peer}")
    user, target = pc.get("user", ""), pc.get("ssh_alias", peer)
    handler._sse_send("log", f"  Target: {f'{user}@{target}' if user else target}")
    handler._sse_send("log", "  Checking SSH connectivity…")
    if not _ssh_ok(ssh_dest, 8):
        handler._sse_send("log", f"✗ Cannot reach {peer}: unreachable")
        handler._sse_send("log", "  Try Wake-on-LAN first if the node is powered off")
        handler._sse_send("done", {"ok": False, "message": "SSH unreachable"})
        return
    handler._sse_send("log", "  ✓ Node reachable")
    handler._sse_send("log", "  Sending reboot command…")
    reboot_cmd = (
        "shutdown /r /t 5 /f 2>&1"
        if pc.get("os", "unknown") == "windows"
        else (
            "sudo shutdown -r now 2>&1 || sudo reboot 2>&1"
            if pc.get("os", "unknown") == "macos"
            else "sudo reboot 2>&1 || sudo shutdown -r now 2>&1"
        )
    )
    try:
        r = subprocess.run(
            [
                "ssh",
                "-o",
                "ConnectTimeout=5",
                "-o",
                "BatchMode=yes",
                ssh_dest,
                reboot_cmd,
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        output = (r.stdout + r.stderr).strip()
        if output:
            handler._sse_send("log", f"  {output}")
        handler._sse_send("log", "✓ Reboot command sent")
        handler._sse_send("log", "")
        handler._sse_send("log", "  Waiting 30s for node to come back…")
        time.sleep(20)
        for i in range(4):
            time.sleep(5)
            handler._sse_send("log", f"  Ping attempt {i + 1}/4…")
            if _ssh_ok(ssh_dest):
                handler._sse_send("log", f"✓ {peer} is back online!")
                handler._sse_send("done", {"ok": True})
                return
        handler._sse_send("log", "⚠ Node not back yet — may need more time")
        handler._sse_send("done", {"ok": True, "message": "Reboot sent, still booting"})
    except Exception:
        handler._sse_send("log", "  Connection dropped (expected during reboot)")
        handler._sse_send("log", "✓ Reboot likely in progress")
        handler._sse_send("done", {"ok": True, "message": "Reboot in progress"})


def handle_mesh_action_sse(handler, qs: dict, safe_name):
    action, peer = qs.get("action", [""])[0], qs.get("peer", [""])[0]
    if not peer or (peer != "__all__" and not safe_name.match(peer)):
        handler._json_response({"error": "invalid peer"}, 400)
        return
    if action in ("wake", "reboot"):
        handle_power_action_sse(handler, action, peer)
        return
    scripts, is_all = Path.home() / ".claude" / "scripts", peer == "__all__"
    peer_flag = "" if is_all else f"--peer {shlex.quote(peer)}"
    cmd = {
        "sync": f"{scripts}/mesh-sync-all.sh {peer_flag}",
        "heartbeat": f"{scripts}/mesh-heartbeat.sh status",
        "auth": f"{scripts}/mesh-auth-sync.sh push {'--all' if is_all else f'--peer {shlex.quote(peer)}'}",
        "status": f"{scripts}/mesh-load-query.sh {'--json' if is_all else f'--peer {shlex.quote(peer)} --json'}",
    }.get(action)
    if not cmd:
        handler._json_response({"error": "invalid action"}, 400)
        return
    label = {
        "sync": "Sync Config",
        "heartbeat": "Heartbeat Status",
        "auth": "Auth Sync",
        "status": "Load Status",
    }.get(action, action)
    handler._start_sse()
    handler._sse_send("log", f"▶ {label} — {'All Peers' if is_all else peer}")
    handler._sse_send("log", f"▶ Running: {cmd.split('/')[-1]}")
    try:
        proc = subprocess.Popen(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env={
                **os.environ,
                "PATH": str(scripts)
                + ":/opt/homebrew/bin:/usr/local/bin:"
                + os.environ.get("PATH", ""),
            },
        )
        for line in iter(proc.stdout.readline, ""):
            handler._sse_send("log", line.rstrip())
        proc.wait(timeout=120 if is_all else 60)
        handler._sse_send(
            "done", {"ok": proc.returncode == 0, "exit_code": proc.returncode}
        )
    except subprocess.TimeoutExpired:
        proc.terminate()
        handler._sse_send(
            "done",
            {
                "ok": False,
                "exit_code": 1,
                "message": f"Timeout ({120 if is_all else 60}s)",
            },
        )
    except Exception as e:
        handler._sse_send("done", {"ok": False, "message": str(e)})


def handle_fullsync_sse(handler, qs: dict):
    peer, force, scripts = (
        qs.get("peer", [""])[0],
        qs.get("force", [""])[0] == "1",
        Path.home() / ".claude" / "scripts",
    )
    cmd = (
        f"{scripts}/mesh-sync-all.sh"
        + (f" --peer {shlex.quote(peer)}" if peer else "")
        + (" --force" if force else "")
    )
    handler._start_sse()
    handler._sse_send("log", "▶ Full Bidirectional Sync")
    handler._sse_send("log", f"▶ Running: {cmd.split('/')[-1]}")
    try:
        proc = subprocess.Popen(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env={
                **os.environ,
                "PATH": str(scripts)
                + ":/opt/homebrew/bin:/usr/local/bin:"
                + os.environ.get("PATH", ""),
            },
        )
        for line in iter(proc.stdout.readline, ""):
            handler._sse_send("log", line.rstrip())
        proc.wait(timeout=180)
        handler._sse_send(
            "done", {"ok": proc.returncode == 0, "exit_code": proc.returncode}
        )
    except subprocess.TimeoutExpired:
        proc.terminate()
        handler._sse_send("done", {"ok": False, "message": "Timeout (180s)"})
    except Exception as e:
        handler._sse_send("done", {"ok": False, "message": str(e)})
