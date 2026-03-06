"""Internal helpers for api_mesh.py: heartbeat parsing, local/remote plan detection."""

import concurrent.futures
import configparser
import json
import re
import subprocess
import time
from pathlib import Path

from lib.ssh import ssh_run
from middleware import PEERS_CONF, query

_remote_cache: dict = {}  # {peer_name: {"data": [...], "ts": float}}
_REMOTE_TTL = 30


def extract_heartbeat(hb: dict) -> tuple[float, int, float, float]:
    cpu, tasks, mem_used, mem_total = 0.0, 0, 0.0, 0.0
    lj = hb.get("load_json")
    if lj and lj != "null":
        try:
            d = json.loads(lj)
            if isinstance(d, dict):
                cpu = float(d.get("cpu_load", d.get("cpu_load_1", 0)))
                tasks = int(d.get("active_tasks", d.get("tasks_in_progress", 0)))
                mem_used = float(d.get("mem_used_gb", 0))
                mem_total = float(d.get("mem_total_gb", 0))
        except Exception:
            pass
    return (
        cpu or float(hb.get("cpu_load_1m") or 0),
        tasks or int(hb.get("active_tasks") or 0),
        mem_used,
        mem_total,
    )


def tailscale_online_ips() -> set[str]:
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


def local_active_plan_ids() -> set[int]:
    """Detect locally running plan executor processes (execute-plan.sh only)."""
    try:
        r = subprocess.run(
            ["ps", "-eo", "command"], capture_output=True, text=True, timeout=5
        )
        ids: set[int] = set()
        for line in r.stdout.splitlines():
            if "execute-plan" not in line:
                continue
            m = re.search(r"execute-plan\.sh\s+(\d+)", line)
            if m:
                ids.add(int(m.group(1)))
        return ids
    except Exception:
        return set()


def peer_execution_map() -> dict[str, list[dict]]:
    """Build map of plans assigned to hosts via execution_host column."""
    plans = query(
        "SELECT id,name,status,tasks_done,tasks_total,execution_host FROM plans"
        " WHERE status IN ('doing','todo') AND execution_host IS NOT NULL AND execution_host<>''"
    )
    result: dict[str, list[dict]] = {}
    for p in plans:
        active = query(
            "SELECT task_id,title,status,executor_agent FROM tasks"
            " WHERE plan_id=? AND status IN ('in_progress','submitted','blocked') ORDER BY id LIMIT 5",
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


_REMOTE_PROCS_CMD = (
    'export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"; '
    'echo "===HOSTNAME==="; hostname -s 2>/dev/null || hostname; '
    'echo "===PROCS==="; '
    'ps -eo command 2>/dev/null | grep -oE "execute-plan\\.sh [0-9]+" | awk "{print \\$2}" | sort -u; '
    'ps -eo command 2>/dev/null | grep -oE "plan-([0-9]+)" | grep -oE "[0-9]+" | sort -u; '
    'echo "===PLANS==="; '
    'sqlite3 ~/.claude/data/dashboard.db ".timeout 3000" '
    '"SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,'
    "COALESCE(p.execution_host,''),"
    "COALESCE(GROUP_CONCAT(CASE WHEN t.status IN ('in_progress','submitted','blocked') "
    "THEN t.task_id||'|'||COALESCE(t.title,'')||'|'||t.status END, ';;'), '') as active "
    "FROM plans p LEFT JOIN tasks t ON t.plan_id=p.id "
    "WHERE p.status='doing' GROUP BY p.id\""
)


def query_remote_plans(ssh_dest: str) -> list[dict]:
    """SSH to a remote peer and query only plans assigned to or running on that peer."""
    try:
        r = subprocess.run(
            [
                "ssh",
                "-n",
                "-o",
                "ConnectTimeout=3",
                "-o",
                "BatchMode=yes",
                ssh_dest,
                _REMOTE_PROCS_CMD,
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode != 0:
            return []
        section, remote_hostname = "", ""
        active_plan_ids: set[int] = set()
        all_plans: list[dict] = []
        for line in r.stdout.strip().splitlines():
            if line == "===HOSTNAME===":
                section = "hostname"
                continue
            if line == "===PROCS===":
                section = "procs"
                continue
            if line == "===PLANS===":
                section = "plans"
                continue
            if section == "hostname":
                remote_hostname = line.strip().lower()
            elif section == "procs" and line.strip().isdigit():
                active_plan_ids.add(int(line.strip()))
            elif section == "plans":
                parts = line.split("|", 6)
                if len(parts) < 6:
                    continue
                exec_host = parts[5].strip().lower()
                active_tasks = []
                if len(parts) > 6 and parts[6]:
                    for chunk in parts[6].split(";;"):
                        tp = chunk.split("|", 2)
                        if len(tp) >= 3 and tp[0]:
                            active_tasks.append(
                                {"task_id": tp[0], "title": tp[1], "status": tp[2]}
                            )
                all_plans.append(
                    {
                        "id": int(parts[0]),
                        "name": parts[1],
                        "status": parts[2],
                        "tasks_done": int(parts[3] or 0),
                        "tasks_total": int(parts[4] or 0),
                        "exec_host": exec_host,
                        "active_tasks": active_tasks,
                    }
                )
        # Filter: only plans assigned to this peer OR with active processes on it
        peer_name = ssh_dest.split("@")[-1].lower().replace("-", "").replace("_", "")
        rh = remote_hostname.replace("-", "").replace("_", "")

        def belongs_here(p: dict) -> bool:
            eh = (
                p["exec_host"]
                .replace("-", "")
                .replace("_", "")
                .replace(".lan", "")
                .replace(".local", "")
            )
            if p["id"] in active_plan_ids:
                return True
            if not eh:
                return False
            return eh == peer_name or eh == rh or peer_name in eh or rh in eh

        return [
            {k: v for k, v in p.items() if k != "exec_host"}
            for p in all_plans
            if belongs_here(p)
        ]
    except Exception:
        return []


def get_remote_plans(peer_name: str, ssh_dest: str) -> list[dict]:
    """Get remote plans with 30s cache."""
    now = time.time()
    cached = _remote_cache.get(peer_name)
    if cached and (now - cached["ts"]) < _REMOTE_TTL:
        return cached["data"]
    plans = query_remote_plans(ssh_dest)
    if plans:
        _remote_cache[peer_name] = {"data": plans, "ts": now}
    return plans or (cached["data"] if cached else [])


_sync_cache: dict = {"data": None, "ts": 0}
_UNREACHABLE = {"reachable": False, "config_synced": None, "last_heartbeat_age_sec": -1}


def _check_peer_sync(peer_name: str, user: str, host: str) -> dict:
    try:
        local_sha = subprocess.run(
            ["git", "-C", str(Path.home() / ".claude"), "log", "--oneline", "-1"],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout.strip()
    except (subprocess.TimeoutExpired, OSError):
        local_sha = ""
    dest = f"{user}@{host}" if user else host
    try:
        remote = ssh_run(dest, "git -C ~/.claude log --oneline -1", timeout=5)
        if remote.returncode != 0:
            return {"peer_name": peer_name, **_UNREACHABLE}
        remote_sha = remote.stdout.strip()
        synced = bool(local_sha and remote_sha and local_sha == remote_sha)
        return {
            "peer_name": peer_name,
            "reachable": True,
            "config_synced": synced,
            "last_heartbeat_age_sec": -1,
        }
    except (subprocess.TimeoutExpired, OSError):
        return {"peer_name": peer_name, **_UNREACHABLE}


def api_mesh_sync_status() -> list[dict]:
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
        }
        for s in cp.sections()
        if cp[s].get("status", "active") == "active"
    ]
    hb_map = {
        r["peer_name"]: r["last_seen"]
        for r in query("SELECT peer_name, last_seen FROM peer_heartbeats")
    }
    fn = lambda p: _check_peer_sync(p["peer_name"], p["user"], p["host"])  # noqa: E731
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        results = list(pool.map(fn, active_peers))
    for entry in results:
        entry["last_heartbeat_age_sec"] = (
            int(now - hb_map[entry["peer_name"]])
            if hb_map.get(entry["peer_name"])
            else -1
        )
    _sync_cache.update({"data": results, "ts": now})
    return results
