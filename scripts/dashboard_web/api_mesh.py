"""Mesh dashboard data API: config parsing, peer data, sync status, non-SSE actions.

SSE streaming handlers live in api_mesh_actions.py.
Internal helpers (heartbeat, remote plans, tailscale) live in lib/mesh_helpers.py.
"""

import configparser
import shlex
import socket
import subprocess
import time

from pathlib import Path

from lib.mesh_helpers import (
    api_mesh_sync_status,
    extract_heartbeat,
    get_remote_plans,
    local_active_plan_ids,
    peer_execution_map,
    tailscale_online_ips,
)
from middleware import PEERS_CONF, query


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


def peer_host_match(peer_name: str, host: str, is_local: bool = False) -> bool:
    pn = peer_name.lower().replace("-", "").replace("_", "")
    eh = (
        host.lower()
        .replace("-", "")
        .replace("_", "")
        .replace(".lan", "")
        .replace(".local", "")
    )
    if pn == eh or pn in eh or eh in pn:
        return True
    if is_local:
        import socket

        local_h = (
            socket.gethostname().lower().replace("-", "").replace("_", "").split(".")[0]
        )
        return local_h == eh or local_h in eh or eh in local_h
    return False


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


def api_mesh() -> list[dict]:
    conf = parse_peers_conf()
    hb_map = {r["peer_name"]: r for r in query("SELECT * FROM peer_heartbeats")}
    ts_online = tailscale_online_ips()
    local_exec_map = peer_execution_map()
    local_proc_ids = local_active_plan_ids()
    now = time.time()
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
        hb = hb_map.get(p["peer_name"], {})
        is_local = p["role"] == "coordinator"
        is_online = (
            is_local
            or (now - (hb.get("last_seen") or 0)) < 300
            or p.get("tailscale_ip", "") in ts_online
        )
        cpu, tasks, mem_used, mem_total = extract_heartbeat(hb)
        if is_local:
            host_plans = [
                e
                for host, host_plans in local_exec_map.items()
                if peer_host_match(p["peer_name"], host, is_local=True)
                for e in host_plans
            ]
            host_plan_ids = {pl["id"] for pl in host_plans}
            proc_plan_ids = local_proc_ids - host_plan_ids
            if proc_plan_ids:
                for pid in proc_plan_ids:
                    rows = query(
                        "SELECT id,name,status,tasks_done,tasks_total FROM plans WHERE id=? AND status='doing'",
                        (pid,),
                    )
                    for row in rows:
                        active = query(
                            "SELECT task_id,title,status,executor_agent FROM tasks"
                            " WHERE plan_id=? AND status IN ('in_progress','submitted','blocked') ORDER BY id LIMIT 5",
                            (row["id"],),
                        )
                        host_plans.append(
                            {
                                "id": row["id"],
                                "name": row["name"],
                                "status": row["status"],
                                "tasks_done": row["tasks_done"],
                                "tasks_total": row["tasks_total"],
                                "active_tasks": active,
                            }
                        )
            plans = host_plans
        elif is_online:
            plans = get_remote_plans(p["peer_name"], p.get("ssh_alias", p["peer_name"]))
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
                "mem_used_gb": mem_used,
                "mem_total_gb": mem_total,
                "plans": plans,
            }
        )
    return result


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
