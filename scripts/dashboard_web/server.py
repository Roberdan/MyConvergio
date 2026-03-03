"""Convergio Control Room — Web Dashboard Server.

Zero-dependency Python HTTP server serving the web UI + JSON API.
Reads from ~/.claude/data/dashboard.db.

Usage: python3 server.py [--port 8420]
"""

import concurrent.futures
import configparser
import json
import os
import re
import shlex
import sqlite3
import subprocess
import sys
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from socketserver import ThreadingMixIn
from urllib.parse import urlparse, parse_qs

DB_PATH = Path.home() / ".claude" / "data" / "dashboard.db"
PEERS_CONF = Path.home() / ".claude" / "config" / "peers.conf"
STATIC_DIR = Path(__file__).parent
PORT = 8420
ALLOWED_ORIGINS = {f"http://localhost:{PORT}", f"http://127.0.0.1:{PORT}"}
_SAFE_NAME = re.compile(r"^[a-zA-Z0-9_.-]+$")


def query(sql: str, params: tuple = ()) -> list[dict]:
    try:
        conn = sqlite3.connect(str(DB_PATH), timeout=5)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(sql, params).fetchall()
        conn.close()
        return [dict(r) for r in rows]
    except (sqlite3.OperationalError, sqlite3.DatabaseError):
        return []


def query_one(sql: str, params: tuple = ()) -> dict | None:
    rows = query(sql, params)
    return rows[0] if rows else None


def api_overview() -> dict:
    ov = query_one(
        "SELECT COUNT(*) FILTER (WHERE status IN ('todo','doing')) AS active,"
        " COUNT(*) FILTER (WHERE status='done') AS done,"
        " COUNT(*) AS total FROM plans"
    ) or {"active": 0, "done": 0, "total": 0}
    running = query_one(
        "SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id"
        " JOIN plans p ON w.plan_id=p.id WHERE t.status='in_progress' AND p.status='doing'"
    ) or {"c": 0}
    blocked = query_one(
        "SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id"
        " JOIN plans p ON w.plan_id=p.id WHERE t.status='blocked' AND p.status='doing'"
    ) or {"c": 0}
    ts = query_one(
        "SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS total_tok,"
        " COALESCE(SUM(cost_usd),0) AS total_cost FROM token_usage"
    ) or {"total_tok": 0, "total_cost": 0}
    today = query_one(
        "SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS tok,"
        " COALESCE(SUM(cost_usd),0) AS cost FROM token_usage"
        " WHERE date(created_at)=date('now')"
    ) or {"tok": 0, "cost": 0}
    return {
        "plans_total": ov["total"],
        "plans_active": ov["active"],
        "plans_done": ov["done"],
        "agents_running": running["c"],
        "blocked": blocked["c"],
        "total_tokens": ts["total_tok"],
        "total_cost": ts["total_cost"],
        "today_tokens": today["tok"],
        "today_cost": today["cost"],
    }


def api_mission() -> dict:
    plans = query(
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,"
        "p.human_summary,p.execution_host,p.parallel_mode,p.project_id,"
        "pr.name AS project_name,pr.path AS project_path"
        " FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id"
        " WHERE p.status IN ('todo','doing') ORDER BY p.id DESC"
    )
    if not plans:
        return {"plans": []}
    result = []
    for p in plans:
        waves = query(
            "SELECT wave_id,name,status,tasks_done,tasks_total,position,validated_at"
            " FROM waves WHERE plan_id=? ORDER BY position",
            (p["id"],),
        )
        tasks = query(
            "SELECT task_id,title,status,executor_agent,executor_host,tokens"
            ",validated_at,model,wave_id"
            " FROM tasks WHERE plan_id=? ORDER BY wave_id_fk,id",
            (p["id"],),
        )
        result.append({"plan": p, "waves": waves, "tasks": tasks})
    # Backward compat: "plan"/"waves"/"tasks" = first (most recent) plan
    return {
        "plans": result,
        "plan": plans[0],
        "waves": result[0]["waves"],
        "tasks": result[0]["tasks"],
    }


def api_tokens_daily() -> list[dict]:
    return query(
        "SELECT date(created_at) AS day,"
        " SUM(input_tokens) AS input, SUM(output_tokens) AS output,"
        " SUM(cost_usd) AS cost FROM token_usage"
        " WHERE date(created_at)>=date('now','-30 days')"
        " GROUP BY day ORDER BY day"
    )


def api_tokens_by_model() -> list[dict]:
    return query(
        "SELECT model, SUM(input_tokens+output_tokens) AS tokens,"
        " SUM(cost_usd) AS cost FROM token_usage"
        " WHERE model IS NOT NULL GROUP BY model ORDER BY tokens DESC LIMIT 8"
    )


def _parse_peers_conf() -> list[dict]:
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


def _send_wol(mac: str, broadcast: str = "255.255.255.255", port: int = 9) -> bool:
    """Send Wake-on-LAN magic packet. Pure Python, no external tools."""
    import socket
    mac_clean = mac.replace(":", "").replace("-", "")
    if len(mac_clean) != 12:
        return False
    mac_bytes = bytes.fromhex(mac_clean)
    magic = b"\xff" * 6 + mac_bytes * 16
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(magic, (broadcast, port))
        sock.close()
        return True
    except OSError:
        return False


def _find_peer_conf(peer_name: str) -> dict | None:
    conf = _parse_peers_conf()
    for p in conf:
        if p["peer_name"] == peer_name:
            return p
    return None


def _extract_heartbeat(hb: dict) -> tuple[float, int]:
    cpu, tasks = 0.0, 0
    lj = hb.get("load_json")
    if lj and lj != "null":
        try:
            d = json.loads(lj)
            if isinstance(d, dict):
                cpu = float(d.get("cpu_load", d.get("cpu_load_1", 0)))
                tasks = int(d.get("active_tasks", d.get("tasks_in_progress", 0)))
        except (json.JSONDecodeError, TypeError, ValueError):
            pass
    if cpu == 0:
        cpu = float(hb.get("cpu_load_1m") or 0)
    if tasks == 0:
        tasks = int(hb.get("active_tasks") or 0)
    return cpu, tasks


def _tailscale_online_ips() -> set[str]:
    """Get set of reachable Tailscale IPs. 'idle'/'active'/'-' = online."""
    try:
        r = subprocess.run(
            ["tailscale", "status"], capture_output=True, text=True, timeout=5
        )
        online = set()
        for line in r.stdout.splitlines():
            if line.startswith("#") or not line.strip():
                continue
            parts = line.split()
            if len(parts) >= 2 and "offline" not in line:
                online.add(parts[0])
        return online
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return set()


def _peer_host_match(peer_name: str, host: str) -> bool:
    pn, eh = peer_name.lower(), host.lower()
    return pn == eh or pn in eh


def _peer_execution_map() -> dict[str, list[dict]]:
    """Active plans+tasks grouped by execution_host."""
    plans = query(
        "SELECT id,name,status,tasks_done,tasks_total,execution_host"
        " FROM plans WHERE status IN ('doing','todo')"
        " AND execution_host IS NOT NULL AND execution_host<>''"
    )
    result: dict[str, list[dict]] = {}
    for p in plans:
        host = p["execution_host"]
        active = query(
            "SELECT task_id,title,status,executor_agent FROM tasks"
            " WHERE plan_id=? AND status IN ('in_progress','submitted','blocked')"
            " ORDER BY id LIMIT 5",
            (p["id"],),
        )
        entry = {
            "id": p["id"],
            "name": p["name"],
            "status": p["status"],
            "tasks_done": p["tasks_done"],
            "tasks_total": p["tasks_total"],
            "active_tasks": active,
        }
        result.setdefault(host, []).append(entry)
    return result


def api_mesh() -> list[dict]:
    conf = _parse_peers_conf()
    hb_map = {r["peer_name"]: r for r in query("SELECT * FROM peer_heartbeats")}
    ts_online = _tailscale_online_ips()
    exec_map = _peer_execution_map()
    now = time.time()
    result = []
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
    for p in sources:
        if p["status"] != "active":
            continue
        hb = hb_map.get(p["peer_name"], {})
        is_local = p["role"] == "coordinator"
        hb_online = (now - (hb.get("last_seen") or 0)) < 300
        ts_reachable = p.get("tailscale_ip", "") in ts_online
        is_online = is_local or hb_online or ts_reachable
        cpu, tasks = _extract_heartbeat(hb)
        # Match execution data to this peer
        plans = []
        for host, host_plans in exec_map.items():
            if _peer_host_match(p["peer_name"], host):
                plans.extend(host_plans)
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


_sync_cache: dict = {"data": None, "ts": 0}


def _check_peer_sync(peer_name: str, user: str, host: str) -> dict:
    """SSH to peer and compare ~/.claude git HEAD with local HEAD.

    Returns dict with peer_name, reachable, config_synced, last_heartbeat_age_sec.
    last_heartbeat_age_sec is -1 here; caller overwrites from DB.
    """
    git_cmd = "git -C ~/.claude log --oneline -1"

    # Get local HEAD
    try:
        local = subprocess.run(
            ["git", "-C", str(Path.home() / ".claude"), "log", "--oneline", "-1"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        local_sha = local.stdout.strip()
    except (subprocess.TimeoutExpired, OSError):
        local_sha = ""

    # SSH to remote peer
    ssh_cmd = [
        "ssh",
        "-o",
        "ConnectTimeout=5",
        "-o",
        "BatchMode=yes",
        host,
        "-l",
        user,
        git_cmd,
    ]
    try:
        remote = subprocess.run(
            ssh_cmd,
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
        synced = bool(local_sha and remote_sha and local_sha == remote_sha)
        return {
            "peer_name": peer_name,
            "reachable": True,
            "config_synced": synced,
            "last_heartbeat_age_sec": -1,
        }
    except (subprocess.TimeoutExpired, OSError):
        return {
            "peer_name": peer_name,
            "reachable": False,
            "config_synced": None,
            "last_heartbeat_age_sec": -1,
        }


def api_mesh_sync_status() -> list[dict]:
    """Return per-peer sync status; cached for 60s."""
    now = time.time()
    if _sync_cache["data"] is not None and (now - _sync_cache["ts"]) < 60:
        return _sync_cache["data"]

    if not PEERS_CONF.exists():
        return []

    cp = configparser.ConfigParser()
    cp.read(str(PEERS_CONF))
    active_peers = [
        {
            "peer_name": s,
            "user": cp[s].get("user", ""),
            "host": cp[s].get("ssh_alias", s),
            "status": cp[s].get("status", "active"),
        }
        for s in cp.sections()
        if cp[s].get("status", "active") == "active"
    ]

    # Build heartbeat age map from DB
    hb_rows = query("SELECT peer_name, last_seen FROM peer_heartbeats")
    hb_map = {r["peer_name"]: r["last_seen"] for r in hb_rows}

    def _run(peer: dict) -> dict:
        return _check_peer_sync(peer["peer_name"], peer["user"], peer["host"])

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        results = list(pool.map(_run, active_peers))

    # Overwrite last_heartbeat_age_sec from DB
    for entry in results:
        last_seen = hb_map.get(entry["peer_name"])
        if last_seen:
            entry["last_heartbeat_age_sec"] = int(now - last_seen)
        else:
            entry["last_heartbeat_age_sec"] = -1

    _sync_cache["data"] = results
    _sync_cache["ts"] = now
    return results


def api_assignable_plans() -> list[dict]:
    return query(
        "SELECT id,name,status,tasks_done,tasks_total,execution_host,human_summary"
        " FROM plans WHERE status IN ('todo','doing') ORDER BY id"
    )


def api_preflight_sse(handler, qs: dict):
    """SSE endpoint: stream pre-delegation checks one by one."""
    plan_id = qs.get("plan_id", [""])[0]
    target = qs.get("target", [""])[0]
    if not plan_id or not target:
        handler.send_response(400)
        handler.send_header("Content-Type", "application/json")
        handler.end_headers()
        handler.wfile.write(json.dumps({"error": "missing plan_id or target"}).encode())
        return

    handler.send_response(200)
    handler.send_header("Content-Type", "text/event-stream")
    handler.send_header("Cache-Control", "no-cache")
    handler.send_header("Connection", "keep-alive")
    origin = handler.headers.get("Origin", "")
    if origin in ALLOWED_ORIGINS:
        handler.send_header("Access-Control-Allow-Origin", origin)
    handler.end_headers()

    all_ok = True

    def _send(event: str, data):
        try:
            msg = f"event: {event}\ndata: {json.dumps(data, default=str)}\n\n"
            handler.wfile.write(msg.encode())
            handler.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _check(name: str, ok: bool, detail: str, blocking: bool = True):
        nonlocal all_ok
        if not ok and blocking:
            all_ok = False
        _send("check", {"name": name, "ok": ok, "detail": detail, "blocking": blocking})

    # Announce start
    _send("start", {"plan_id": plan_id, "target": target, "total_checks": 6})

    # Resolve SSH alias from peers.conf (peer_name → ssh_alias)
    pc = _find_peer_conf(target)
    ssh_dest = pc.get("ssh_alias", target) if pc else target

    # 1. Plan exists and is active
    _send("checking", {"name": "Plan status"})
    plan = query_one(
        "SELECT id,name,status,execution_host FROM plans WHERE id=?",
        (int(plan_id),),
    )
    if not plan:
        _check("Plan status", False, "Not found in DB")
        _send("done", {"ok": False})
        return
    active = plan["status"] in ("todo", "doing")
    _check("Plan status", active,
           f"#{plan_id} is '{plan['status']}'" + ("" if active else " — must be todo/doing"))

    # 2. SSH reachability
    _send("checking", {"name": "SSH reachable"})
    reachable = False
    ssh_err = ""
    try:
        r = subprocess.run(
            ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", ssh_dest, "echo ok"],
            capture_output=True, text=True, timeout=8,
        )
        reachable = r.returncode == 0
        if not reachable:
            ssh_err = (r.stderr.strip().split("\n")[-1] or f"exit code {r.returncode}")[:80]
    except subprocess.TimeoutExpired:
        ssh_err = "Connection timed out after 8s"
    except OSError as e:
        ssh_err = str(e)[:80]
    ssh_label = f"{target} via {ssh_dest}" if ssh_dest != target else target
    _check("SSH reachable", reachable,
           f"{ssh_label} ✓" if reachable else f"{ssh_label} — {ssh_err}")

    # Detect target OS from peers.conf for cross-platform commands
    target_os = "unknown"
    conf = _parse_peers_conf()
    for pc in conf:
        if pc["peer_name"] == target:
            target_os = pc.get("os", "unknown")
            break

    # 3. Heartbeat — if stale, restart daemon on remote
    _send("checking", {"name": "Heartbeat"})
    hb = query_one(
        "SELECT last_seen FROM peer_heartbeats WHERE peer_name=?", (target,)
    )
    hb_ok = False
    if hb and hb["last_seen"]:
        age = int(time.time() - hb["last_seen"])
        hb_ok = age < 300
    if hb_ok:
        _check("Heartbeat", True, f"{age}s ago")
    elif reachable:
        # Auto-fix: start heartbeat daemon on remote
        _send("checking", {"name": "Heartbeat — restarting daemon"})
        try:
            scripts_path = "$HOME/.claude/scripts"
            start_cmd = (
                f"nohup {scripts_path}/mesh-heartbeat.sh start >/dev/null 2>&1 & "
                f"sleep 2 && {scripts_path}/mesh-heartbeat.sh ping 2>/dev/null && echo HB_OK || echo HB_FAIL"
            )
            r = subprocess.run(
                ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", ssh_dest, start_cmd],
                capture_output=True, text=True, timeout=10,
            )
            if "HB_OK" in r.stdout:
                _check("Heartbeat", True, "was stale — daemon restarted ✓")
            else:
                _check("Heartbeat", True, "daemon start sent (may take a moment)")
        except (subprocess.TimeoutExpired, OSError):
            _check("Heartbeat", True, "daemon restart attempted")
    else:
        _check("Heartbeat", False, "SSH unreachable — cannot restart")

    # 4. Config sync — if out of sync, auto-sync via rsync
    _send("checking", {"name": "Config sync"})
    if reachable:
        try:
            local = subprocess.run(
                ["git", "-C", str(Path.home() / ".claude"), "log", "--oneline", "-1"],
                capture_output=True, text=True, timeout=5,
            )
            git_remote_cmd = "git -C $HOME/.claude log --oneline -1" if target_os != "windows" \
                else "git -C %USERPROFILE%\\.claude log --oneline -1"
            remote = subprocess.run(
                ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", ssh_dest,
                 git_remote_cmd],
                capture_output=True, text=True, timeout=8,
            )
            local_sha = local.stdout.strip().split()[0] if local.stdout.strip() else ""
            remote_sha = remote.stdout.strip().split()[0] if remote.stdout.strip() else ""
            synced = bool(local_sha and remote_sha and local_sha == remote_sha)
            if synced:
                _check("Config sync", True, f"both at {local_sha[:8]}")
            else:
                # Auto-fix: run sync
                _send("checking", {"name": "Config sync — syncing"})
                scripts = Path.home() / ".claude" / "scripts"
                sync_cmd = f"{scripts}/mesh-sync-all.sh --peer {shlex.quote(target)}"
                try:
                    sr = subprocess.run(
                        sync_cmd, shell=True, capture_output=True, text=True, timeout=120,
                        env={**os.environ, "PATH": str(scripts) + ":/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "")},
                    )
                    # Re-check after sync
                    remote2 = subprocess.run(
                        ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", ssh_dest,
                         git_remote_cmd],
                        capture_output=True, text=True, timeout=8,
                    )
                    remote_sha2 = remote2.stdout.strip().split()[0] if remote2.stdout.strip() else ""
                    synced2 = bool(local_sha and remote_sha2 and local_sha == remote_sha2)
                    if synced2:
                        _check("Config sync", True, f"was {remote_sha[:8]} — synced to {local_sha[:8]} ✓")
                    else:
                        _check("Config sync", False,
                               f"local={local_sha[:8]} remote={remote_sha2[:8]} — sync attempted but diverged")
                except (subprocess.TimeoutExpired, OSError):
                    _check("Config sync", False, "Sync timed out")
        except (subprocess.TimeoutExpired, OSError):
            _check("Config sync", False, "Check failed")
    else:
        _check("Config sync", False, "Skipped — SSH unreachable")

    # 5. Claude CLI — search extended PATH
    _send("checking", {"name": "Claude CLI"})
    if reachable:
        try:
            if target_os == "windows":
                check_cmd = "where claude >nul 2>&1 && claude --version || echo missing"
            else:
                check_cmd = (
                    "export PATH=\"$HOME/.local/bin:$HOME/.claude/local/bin:"
                    "/opt/homebrew/bin:/usr/local/bin:$PATH\"; "
                    "which claude >/dev/null 2>&1 && claude --version 2>/dev/null || echo missing"
                )
            r = subprocess.run(
                ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", ssh_dest, check_cmd],
                capture_output=True, text=True, timeout=15,
            )
            has_claude = "missing" not in r.stdout and r.returncode == 0
            ver = r.stdout.strip().split("\n")[-1][:40] if has_claude else "not found"
            _check("Claude CLI", has_claude, ver)
        except (subprocess.TimeoutExpired, OSError):
            _check("Claude CLI", False, "Check timeout")
    else:
        _check("Claude CLI", False, "Skipped — SSH unreachable")

    # 6. Disk space
    _send("checking", {"name": "Disk space"})
    if reachable:
        try:
            # Cross-platform disk check: Python one-liner works everywhere
            disk_cmd = (
                "python3 -c \"import shutil; u=shutil.disk_usage('.'); "
                "print(u.free//(1024**3))\" 2>/dev/null || "
                "python -c \"import shutil; u=shutil.disk_usage('.'); "
                "print(u.free//(1024**3))\" 2>/dev/null || echo -1"
            )
            r = subprocess.run(
                ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", ssh_dest, disk_cmd],
                capture_output=True, text=True, timeout=10,
            )
            free_gb = int(r.stdout.strip().split("\n")[-1])
            if free_gb < 0:
                _check("Disk space", False, "Could not detect (python missing?)")
            else:
                enough = free_gb >= 5
                _check("Disk space", enough,
                       f"{free_gb}GB free" + ("" if enough else " — need ≥5GB"))
        except (subprocess.TimeoutExpired, OSError, ValueError):
            _check("Disk space", False, "Check skipped")
    else:
        _check("Disk space", False, "Skipped — SSH unreachable")

    # Final result
    _send("done", {"ok": all_ok})


def api_history() -> list[dict]:
    return query(
        "SELECT id,name,status,tasks_done,tasks_total,project_id,"
        "started_at,completed_at,human_summary,lines_added,lines_removed"
        " FROM plans WHERE status IN ('done','archived','cancelled')"
        " ORDER BY id DESC LIMIT 20"
    )


def api_plan_detail(plan_id: int) -> dict | None:
    p = query_one(
        "SELECT id,name,status,tasks_done,tasks_total,project_id,"
        "human_summary,started_at,completed_at,parallel_mode,"
        "lines_added,lines_removed,execution_host FROM plans WHERE id=?",
        (plan_id,),
    )
    if not p:
        return None
    waves = query(
        "SELECT wave_id,name,status,tasks_done,tasks_total,branch_name,"
        "pr_number,pr_url,position,validated_at FROM waves WHERE plan_id=? ORDER BY position",
        (plan_id,),
    )
    tasks = query(
        "SELECT task_id,title,status,executor_agent,executor_host,tokens,"
        "started_at,completed_at,validated_at,model,wave_id"
        " FROM tasks WHERE plan_id=? ORDER BY wave_id_fk,id",
        (plan_id,),
    )
    cost = query_one(
        "SELECT COALESCE(SUM(cost_usd),0) AS cost,"
        "COALESCE(SUM(input_tokens+output_tokens),0) AS tokens"
        " FROM token_usage WHERE project_id=("
        "SELECT project_id FROM plans WHERE id=?)",
        (plan_id,),
    ) or {"cost": 0, "tokens": 0}
    return {"plan": p, "waves": waves, "tasks": tasks, "cost": cost}


def api_task_status_dist() -> list[dict]:
    return query(
        "SELECT t.status, COUNT(*) AS count FROM tasks t"
        " JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id"
        " WHERE p.status='doing' GROUP BY t.status ORDER BY count DESC"
    )


def api_tasks_blocked() -> list[dict]:
    return query(
        "SELECT t.task_id, t.title, t.status,"
        " p.id AS plan_id, p.name AS plan_name"
        " FROM tasks t"
        " JOIN waves w ON t.wave_id_fk=w.id"
        " JOIN plans p ON w.plan_id=p.id"
        " WHERE t.status='blocked'"
        " AND p.status IN ('doing','todo')"
    )


ROUTES = {
    "/api/overview": api_overview,
    "/api/mission": api_mission,
    "/api/tokens/daily": api_tokens_daily,
    "/api/tokens/models": api_tokens_by_model,
    "/api/mesh": api_mesh,
    "/api/mesh/sync-status": api_mesh_sync_status,
    "/api/history": api_history,
    "/api/tasks/distribution": api_task_status_dist,
    "/api/tasks/blocked": api_tasks_blocked,
    "/api/plans/assignable": api_assignable_plans,
}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(STATIC_DIR), **kw)

    def _json_response(self, data, status=200):
        body = json.dumps(data, default=str).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        origin = self.headers.get("Origin", "")
        if origin in ALLOWED_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", origin)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)
        if path in ROUTES:
            self._json_response(ROUTES[path]())
        elif path == "/api/mesh/action":
            self._json_response(self._handle_mesh_action(qs))
        elif path == "/api/mesh/action/stream":
            self._handle_mesh_action_sse(qs)
        elif path == "/api/terminal":
            self._json_response(self._handle_terminal(qs))
        elif path == "/api/plan/move":
            self._json_response(self._handle_plan_move(qs))
        elif path == "/api/plan/preflight":
            api_preflight_sse(self, qs)
        elif path == "/api/plan/delegate":
            self._handle_plan_delegate(qs)
        elif path.startswith("/api/plan/"):
            pid = path.split("/")[-1]
            if pid.isdigit():
                self._json_response(api_plan_detail(int(pid)))
            else:
                self._json_response({"error": "invalid plan id"}, 400)
        elif path in ("", "/"):
            self.path = "/index.html"
            super().do_GET()
        else:
            super().do_GET()

    def _handle_mesh_action(self, qs: dict) -> dict:
        """Fallback JSON endpoint (used by sync-btn in preflight)."""
        SCRIPTS = Path.home() / ".claude" / "scripts"
        action = qs.get("action", [""])[0]
        peer = qs.get("peer", [""])[0]
        if not peer:
            return {"error": "missing peer", "output": ""}
        is_all = peer == "__all__"
        if not is_all and not _SAFE_NAME.match(peer):
            return {"error": "invalid peer name", "output": ""}
        peer_flag = "" if is_all else f"--peer {shlex.quote(peer)}"
        cmds = {
            "sync": f"{SCRIPTS}/mesh-sync-all.sh {peer_flag}",
            "heartbeat": f"{SCRIPTS}/mesh-heartbeat.sh status",
            "auth": f"{SCRIPTS}/mesh-auth-sync.sh push {'--all' if is_all else f'--peer {shlex.quote(peer)}'}",
            "status": f"{SCRIPTS}/mesh-load-query.sh {'--json' if is_all else f'--peer {shlex.quote(peer)} --json'}",
        }
        cmd = cmds.get(action)
        if not cmd:
            return {"error": "invalid action", "output": ""}
        timeout = 120 if is_all else 30
        try:
            r = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=timeout
            )
            return {"output": r.stdout + r.stderr, "exit_code": r.returncode}
        except subprocess.TimeoutExpired:
            return {"output": f"Timeout ({timeout}s)", "exit_code": 1}

    def _handle_mesh_action_sse(self, qs: dict):
        """SSE streaming endpoint for mesh actions incl. wake/reboot."""
        SCRIPTS = Path.home() / ".claude" / "scripts"
        action = qs.get("action", [""])[0]
        peer = qs.get("peer", [""])[0]
        if not peer or (peer != "__all__" and not _SAFE_NAME.match(peer)):
            self._json_response({"error": "invalid peer"}, 400)
            return

        # Handle wake/reboot separately (not shell scripts)
        if action in ("wake", "reboot"):
            self._handle_power_action_sse(action, peer)
            return

        is_all = peer == "__all__"
        peer_flag = "" if is_all else f"--peer {shlex.quote(peer)}"
        action_labels = {
            "sync": "Sync Config",
            "heartbeat": "Heartbeat Status",
            "auth": "Auth Sync",
            "status": "Load Status",
        }
        cmds = {
            "sync": f"{SCRIPTS}/mesh-sync-all.sh {peer_flag}",
            "heartbeat": f"{SCRIPTS}/mesh-heartbeat.sh status",
            "auth": f"{SCRIPTS}/mesh-auth-sync.sh push {'--all' if is_all else f'--peer {shlex.quote(peer)}'}",
            "status": f"{SCRIPTS}/mesh-load-query.sh {'--json' if is_all else f'--peer {shlex.quote(peer)} --json'}",
        }
        cmd = cmds.get(action)
        if not cmd:
            self._json_response({"error": "invalid action"}, 400)
            return

        label = action_labels.get(action, action)
        target = "All Peers" if is_all else peer
        timeout = 120 if is_all else 60

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        origin = self.headers.get("Origin", "")
        if origin in ALLOWED_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", origin)
        self.end_headers()

        def _send(event: str, data: str):
            try:
                msg = f"event: {event}\ndata: {data}\n\n"
                self.wfile.write(msg.encode())
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass

        _send("log", f"▶ {label} — {target}")
        _send("log", f"▶ Running: {cmd.split('/')[-1]}")

        try:
            proc = subprocess.Popen(
                cmd, shell=True,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                env={**os.environ, "PATH": str(SCRIPTS) + ":/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "")},
            )
            for line in iter(proc.stdout.readline, ""):
                _send("log", line.rstrip())
            proc.wait(timeout=timeout)
            if proc.returncode == 0:
                _send("done", json.dumps({"ok": True, "exit_code": 0}))
            else:
                _send("done", json.dumps({"ok": False, "exit_code": proc.returncode}))
        except subprocess.TimeoutExpired:
            proc.kill()
            _send("done", json.dumps({"ok": False, "exit_code": 1, "message": f"Timeout ({timeout}s)"}))
        except Exception as e:
            _send("done", json.dumps({"ok": False, "message": str(e)}))

    def _handle_power_action_sse(self, action: str, peer: str):
        """SSE endpoint for wake (WoL) and reboot (SSH) actions."""
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        origin = self.headers.get("Origin", "")
        if origin in ALLOWED_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", origin)
        self.end_headers()

        def _send(event: str, data: str):
            try:
                msg = f"event: {event}\ndata: {data}\n\n"
                self.wfile.write(msg.encode())
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass

        pc = _find_peer_conf(peer)
        if not pc:
            _send("log", f"✗ Peer '{peer}' not found in peers.conf")
            _send("done", json.dumps({"ok": False, "message": "Peer not found"}))
            return
        ssh_dest = pc.get("ssh_alias", peer)

        if action == "wake":
            label = "Wake-on-LAN"
            _send("log", f"▶ {label} — {peer}")
            mac = pc.get("mac_address", "")
            if not mac:
                _send("log", f"✗ No mac_address configured for {peer} in peers.conf")
                _send("done", json.dumps({"ok": False, "message": "No MAC address configured"}))
                return
            _send("log", f"  MAC: {mac}")
            _send("log", f"  Sending magic packet (broadcast 255.255.255.255:9)…")
            # Send 3 packets for reliability
            sent = 0
            for i in range(3):
                if _send_wol(mac):
                    sent += 1
                time.sleep(0.3)
            if sent > 0:
                _send("log", f"✓ {sent}/3 magic packets sent")
                _send("log", "")
                _send("log", "  Waiting 15s for node to boot…")
                # Poll SSH reachability
                for attempt in range(3):
                    time.sleep(5)
                    _send("log", f"  Ping attempt {attempt + 1}/3…")
                    try:
                        r = subprocess.run(
                            ["ssh", "-o", "ConnectTimeout=3", "-o", "BatchMode=yes",
                             ssh_dest, "echo ok"],
                            capture_output=True, text=True, timeout=5,
                        )
                        if r.returncode == 0:
                            _send("log", f"✓ {peer} is online!")
                            _send("done", json.dumps({"ok": True}))
                            return
                    except (subprocess.TimeoutExpired, OSError):
                        pass
                _send("log", f"⚠ Node not responding yet — may need more time to boot")
                _send("done", json.dumps({"ok": True, "message": "WoL sent, node still booting"}))
            else:
                _send("log", "✗ Failed to send magic packet")
                _send("done", json.dumps({"ok": False, "message": "WoL send failed"}))

        elif action == "reboot":
            label = "SSH Reboot"
            _send("log", f"▶ {label} — {peer}")
            ssh_target = pc.get("ssh_alias", peer)
            user = pc.get("user", "")
            dest = f"{user}@{ssh_target}" if user else ssh_target
            _send("log", f"  Target: {dest}")
            # First check if reachable
            _send("log", "  Checking SSH connectivity…")
            try:
                r = subprocess.run(
                    ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes",
                     ssh_dest, "echo ok"],
                    capture_output=True, text=True, timeout=8,
                )
                if r.returncode != 0:
                    err = r.stderr.strip().split("\n")[-1][:60] if r.stderr.strip() else "unreachable"
                    _send("log", f"✗ Cannot reach {peer}: {err}")
                    _send("log", "  Try Wake-on-LAN first if the node is powered off")
                    _send("done", json.dumps({"ok": False, "message": f"SSH unreachable: {err}"}))
                    return
            except (subprocess.TimeoutExpired, OSError):
                _send("log", f"✗ SSH connection timed out")
                _send("log", "  Try Wake-on-LAN first if the node is powered off")
                _send("done", json.dumps({"ok": False, "message": "SSH timed out"}))
                return

            _send("log", "  ✓ Node reachable")
            _send("log", "  Sending reboot command…")
            # Detect OS for reboot command
            target_os = pc.get("os", "unknown")
            if target_os == "macos":
                reboot_cmd = "sudo shutdown -r now 2>&1 || sudo reboot 2>&1"
            elif target_os == "windows":
                reboot_cmd = "shutdown /r /t 5 /f 2>&1"
            else:
                reboot_cmd = "sudo reboot 2>&1 || sudo shutdown -r now 2>&1"

            try:
                r = subprocess.run(
                    ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes",
                     ssh_dest, reboot_cmd],
                    capture_output=True, text=True, timeout=10,
                )
                output = (r.stdout + r.stderr).strip()
                if output:
                    _send("log", f"  {output}")
                # SSH may return error because connection drops during reboot — that's OK
                _send("log", "✓ Reboot command sent")
                _send("log", "")
                _send("log", "  Waiting 30s for node to come back…")
                time.sleep(20)
                for attempt in range(4):
                    time.sleep(5)
                    _send("log", f"  Ping attempt {attempt + 1}/4…")
                    try:
                        r2 = subprocess.run(
                            ["ssh", "-o", "ConnectTimeout=3", "-o", "BatchMode=yes",
                             ssh_dest, "echo ok"],
                            capture_output=True, text=True, timeout=5,
                        )
                        if r2.returncode == 0:
                            _send("log", f"✓ {peer} is back online!")
                            _send("done", json.dumps({"ok": True}))
                            return
                    except (subprocess.TimeoutExpired, OSError):
                        pass
                _send("log", f"⚠ Node not back yet — may need more time")
                _send("done", json.dumps({"ok": True, "message": "Reboot sent, still booting"}))
            except (subprocess.TimeoutExpired, OSError) as e:
                _send("log", f"  Connection dropped (expected during reboot)")
                _send("log", "✓ Reboot likely in progress")
                _send("done", json.dumps({"ok": True, "message": "Reboot in progress"}))

    def _handle_terminal(self, qs: dict) -> dict:
        cmd = qs.get("cmd", [""])[0]
        peer = qs.get("peer", [""])[0]
        if not cmd:
            return {"output": "", "exit_code": 1}
        if peer and peer != "local":
            if not _SAFE_NAME.match(peer):
                return {"output": "Invalid peer name", "exit_code": 1}
            full = f"ssh {shlex.quote(peer)} {shlex.quote(cmd)}"
        else:
            full = cmd
        try:
            r = subprocess.run(
                full,
                shell=True,
                capture_output=True,
                text=True,
                timeout=60,
                env={
                    **os.environ,
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:"
                    + os.environ.get("PATH", ""),
                },
            )
            return {"output": (r.stdout + r.stderr)[:10000], "exit_code": r.returncode}
        except subprocess.TimeoutExpired:
            return {"output": "Timeout (60s)", "exit_code": 1}

    def _handle_plan_move(self, qs: dict) -> dict:
        plan_id = qs.get("plan_id", [""])[0]
        target = qs.get("target", [""])[0]
        if not plan_id or not plan_id.isdigit() or not target:
            return {"error": "missing plan_id or target"}
        try:
            conn = sqlite3.connect(str(DB_PATH), timeout=5)
            conn.execute(
                "UPDATE plans SET execution_host=? WHERE id=?",
                (target, int(plan_id)),
            )
            conn.execute(
                "UPDATE tasks SET executor_host=? WHERE plan_id=?"
                " AND status IN ('pending','in_progress')",
                (target, int(plan_id)),
            )
            conn.commit()
            conn.close()
            return {"ok": True, "plan_id": int(plan_id), "target": target}
        except (sqlite3.OperationalError, sqlite3.DatabaseError) as e:
            return {"error": str(e)}

    def _handle_plan_delegate(self, qs: dict):
        """SSE endpoint: pre-validate → auto-fix → sync → migrate with retry."""
        plan_id = qs.get("plan_id", [""])[0]
        target = qs.get("target", [""])[0]
        if not plan_id or not plan_id.isdigit() or not target:
            self._json_response({"error": "missing plan_id or target"}, 400)
            return
        if not _SAFE_NAME.match(target):
            self._json_response({"error": "invalid target name"}, 400)
            return

        scripts = Path.home() / ".claude" / "scripts"
        env = {
            **os.environ,
            "PATH": str(scripts) + ":/opt/homebrew/bin:/usr/local/bin:"
            + os.environ.get("PATH", ""),
        }

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        origin = self.headers.get("Origin", "")
        if origin in ALLOWED_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", origin)
        self.end_headers()

        def _send_sse(event: str, data: str):
            try:
                msg = f"event: {event}\ndata: {data}\n\n"
                self.wfile.write(msg.encode())
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass

        def _stream_cmd(cmd: str, timeout: int = 300) -> int:
            """Run cmd, stream stdout line-by-line. Return exit code."""
            proc = subprocess.Popen(
                cmd, shell=True,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, env=env,
            )
            for line in iter(proc.stdout.readline, ""):
                _send_sse("log", line.rstrip())
            proc.wait(timeout=timeout)
            return proc.returncode

        def _ssh_ok(dest: str) -> bool:
            """Quick SSH check."""
            try:
                r = subprocess.run(
                    ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes",
                     dest, "echo ok"],
                    capture_output=True, text=True, timeout=8,
                )
                return r.returncode == 0
            except Exception:
                return False

        def _auto_fix_ssh(peer_name: str) -> str | None:
            """Resolve SSH dest, test it, auto-fix common issues. Returns working dest or None."""
            # 1. Resolve via peers.conf
            pc = _find_peer_conf(peer_name)
            ssh_alias = pc.get("ssh_alias", "") if pc else ""
            ts_ip = pc.get("tailscale_ip", "") if pc else ""

            candidates = []
            if ssh_alias:
                candidates.append(("ssh_alias", ssh_alias))
            if ts_ip:
                user = pc.get("user", "") if pc else ""
                candidates.append(("tailscale_ip", f"{user}@{ts_ip}" if user else ts_ip))
            # Last resort: raw name
            candidates.append(("raw", peer_name))

            for label, dest in candidates:
                _send_sse("log", f"  Testing SSH → {dest} ({label})…")
                if _ssh_ok(dest):
                    _send_sse("log", f"  ✓ SSH connected via {label}: {dest}")
                    return dest
                _send_sse("log", f"  ✗ {dest} unreachable")

            # All failed — try Wake-on-LAN if we have MAC
            mac = pc.get("mac_address", "") if pc else ""
            if mac:
                _send_sse("log", f"  ⚡ Sending Wake-on-LAN to {mac}…")
                try:
                    _send_wol(mac)
                    time.sleep(3)
                    _send_wol(mac)
                except Exception:
                    pass
                # Wait and retry
                for wait_sec in [5, 10, 15]:
                    _send_sse("log", f"  Waiting {wait_sec}s for node to wake…")
                    time.sleep(wait_sec)
                    for label, dest in candidates:
                        if _ssh_ok(dest):
                            _send_sse("log", f"  ✓ Node woke up! Connected via {label}")
                            return dest
            return None

        try:
            # ━━━ PRE-VALIDATION: resolve SSH before calling any script ━━━
            _send_sse("phase", "prevalidate")
            _send_sse("log", f"━━━ PRE-VALIDATION: {target} ━━━")
            _send_sse("log", "")

            # Resolve SSH destination from peers.conf (the #1 failure cause)
            pc = _find_peer_conf(target)
            ssh_dest = pc.get("ssh_alias", target) if pc else target
            _send_sse("log", f"▶ Resolving {target} → SSH destination")
            if pc:
                _send_sse("log", f"  peers.conf: ssh_alias={ssh_dest}")
            else:
                _send_sse("log", f"  ⚠ {target} not in peers.conf — using raw name")

            # Test SSH connectivity with auto-fix
            _send_sse("log", f"▶ Testing SSH connectivity")
            working_dest = _auto_fix_ssh(target)
            if not working_dest:
                _send_sse("log", "")
                _send_sse("log", f"✗ FAILED: {target} unreachable via all methods")
                _send_sse("log", "  Tried: ssh_alias, tailscale_ip, Wake-on-LAN")
                _send_sse("log", "  Check: is the machine on? SSH running? VPN connected?")
                _send_sse("error", json.dumps({
                    "ok": False,
                    "message": f"{target} unreachable — tried SSH alias, Tailscale IP, WoL"
                }))
                return
            _send_sse("log", "")

            # Ensure peers.conf ssh_alias matches working dest
            # (auto-heal: if ssh_alias was wrong but tailscale worked, update conf)
            if pc and working_dest != ssh_dest and working_dest != target:
                _send_sse("log", f"⚠ ssh_alias '{ssh_dest}' didn't work but '{working_dest}' did")
                _send_sse("log", f"  Consider updating peers.conf ssh_alias for {target}")

            # Quick sanity: claude home exists on remote
            _send_sse("log", "▶ Checking remote .claude directory")
            try:
                r = subprocess.run(
                    ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes",
                     working_dest, "test -d $HOME/.claude && echo EXISTS || echo MISSING"],
                    capture_output=True, text=True, timeout=8,
                )
                if "EXISTS" in r.stdout:
                    _send_sse("log", "  ✓ ~/.claude exists on remote")
                else:
                    _send_sse("log", "  ⚠ ~/.claude missing — sync will create it")
            except Exception:
                _send_sse("log", "  ⚠ Could not verify (non-blocking)")
            _send_sse("log", "")
            _send_sse("log", "✓ Pre-validation passed")
            _send_sse("log", "")

            # --- PHASE 0: Full sync ---
            _send_sse("phase", "sync")
            _send_sse("log", f"━━━ PHASE 0: Full Sync → {target} ━━━")
            _send_sse("log", "")
            sync_cmd = f"{scripts}/mesh-sync-all.sh --peer {shlex.quote(target)}"
            _send_sse("log", f"▶ Running: mesh-sync-all.sh --peer {target}")
            sync_rc = _stream_cmd(sync_cmd, timeout=120)
            if sync_rc != 0:
                _send_sse("log", "")
                _send_sse("log", f"⚠ Sync exited with code {sync_rc} — continuing with migration")
            else:
                _send_sse("log", "")
                _send_sse("log", "✓ Sync completed")
            _send_sse("log", "")

            # --- PHASE 1-5: Migration (with auto-retry) ---
            _send_sse("phase", "migrate")
            _send_sse("log", f"━━━ PHASE 1-5: Migrate Plan #{plan_id} → {target} ━━━")
            _send_sse("log", "")
            migrate_cmd = f"{scripts}/mesh-migrate.sh {plan_id} {shlex.quote(target)}"
            max_attempts = 2
            for attempt in range(1, max_attempts + 1):
                if attempt > 1:
                    _send_sse("log", "")
                    _send_sse("log", f"━━━ RETRY {attempt}/{max_attempts}: auto-fixing and retrying ━━━")
                    _send_sse("log", "")
                    # Auto-fix before retry: re-sync and re-verify SSH
                    _send_sse("log", "▶ Auto-fix: re-syncing config…")
                    _stream_cmd(sync_cmd, timeout=120)
                    _send_sse("log", "▶ Auto-fix: re-verifying SSH…")
                    if not _ssh_ok(working_dest):
                        working_dest = _auto_fix_ssh(target)
                        if not working_dest:
                            _send_sse("log", "✗ SSH still unreachable after auto-fix")
                            break
                    _send_sse("log", "")

                _send_sse("log", f"▶ Running: mesh-migrate.sh {plan_id} {target}")
                migrate_rc = _stream_cmd(migrate_cmd, timeout=300)

                if migrate_rc == 0:
                    _send_sse("done", json.dumps({
                        "ok": True, "plan_id": int(plan_id), "target": target
                    }))
                    return

                # Analyze failure for retryable errors
                if attempt < max_attempts:
                    _send_sse("log", "")
                    _send_sse("log", f"⚠ mesh-migrate exited with code {migrate_rc} — analyzing…")
                    # Most failures are SSH/sync related → retry helps
                    _send_sse("log", "  Retryable error detected — will auto-fix and retry")

            # All attempts failed
            _send_sse("error", json.dumps({
                "ok": False, "exit_code": migrate_rc,
                "message": f"mesh-migrate failed after {max_attempts} attempts (exit code {migrate_rc})"
            }))
        except subprocess.TimeoutExpired:
            _send_sse("error", json.dumps({
                "ok": False, "message": "Timeout"
            }))
        except Exception as e:
            _send_sse("error", json.dumps({
                "ok": False, "message": str(e)
            }))

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass


def main():
    port = PORT
    if "--port" in sys.argv:
        idx = sys.argv.index("--port")
        port = int(sys.argv[idx + 1])

    class ThreadedServer(ThreadingMixIn, HTTPServer):
        daemon_threads = True

    server = ThreadedServer(("127.0.0.1", port), Handler)
    print(f"\033[1;36m◈ Convergio Control Room\033[0m → http://localhost:{port}")
    print(f"  DB: {DB_PATH}")
    print(f"  Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutdown.")
        server.server_close()


if __name__ == "__main__":
    main()
