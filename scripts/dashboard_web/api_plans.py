import sqlite3
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.dashboard_web.api_mesh import (
        find_peer_conf,
        local_peer_name,
        peer_host_match,
    )
    from scripts.dashboard_web.middleware import DB_PATH, query
else:
    from .api_mesh import find_peer_conf, local_peer_name, peer_host_match
    from .middleware import DB_PATH, query


def handle_plan_validate(plan_id: int) -> dict:
    """Run plan-db.sh validate-task on all submitted tasks for a plan."""
    scripts = Path.home() / ".claude" / "scripts"
    tasks = query(
        "SELECT task_id FROM tasks WHERE plan_id=? AND status='submitted'",
        (plan_id,),
    )
    if not tasks:
        return {"ok": True, "validated": 0, "message": "No submitted tasks"}
    validated = 0
    for t in tasks:
        try:
            r = subprocess.run(
                [
                    str(scripts / "plan-db.sh"),
                    "validate-task",
                    t["task_id"],
                    str(plan_id),
                ],
                capture_output=True,
                text=True,
                timeout=15,
            )
            if r.returncode == 0:
                validated += 1
        except subprocess.TimeoutExpired:
            pass
    return {"ok": True, "validated": validated, "total": len(tasks)}


def handle_plan_cancel(qs: dict) -> dict:
    plan_id = qs.get("plan_id", [""])[0]
    if not plan_id or not plan_id.isdigit():
        return {"error": "missing plan_id"}
    pid = int(plan_id)
    try:
        with sqlite3.connect(str(DB_PATH), timeout=5) as conn:
            plan = conn.execute(
                "SELECT id, status FROM plans WHERE id=?", (pid,)
            ).fetchone()
            if not plan:
                return {"error": f"plan {pid} not found"}
            conn.execute("UPDATE plans SET status='cancelled' WHERE id=?", (pid,))
            conn.execute(
                "UPDATE waves SET status='cancelled' WHERE plan_id=? AND status NOT IN ('done','cancelled')",
                (pid,),
            )
            conn.execute(
                "UPDATE tasks SET status='cancelled' WHERE plan_id=? AND status NOT IN ('done','cancelled','skipped')",
                (pid,),
            )
        return {"ok": True, "plan_id": pid, "action": "cancelled"}
    except (sqlite3.OperationalError, sqlite3.DatabaseError) as e:
        return {"error": str(e)}


def handle_plan_reset(qs: dict) -> dict:
    plan_id = qs.get("plan_id", [""])[0]
    if not plan_id or not plan_id.isdigit():
        return {"error": "missing plan_id"}
    pid = int(plan_id)
    try:
        with sqlite3.connect(str(DB_PATH), timeout=5) as conn:
            plan = conn.execute(
                "SELECT id, status FROM plans WHERE id=?", (pid,)
            ).fetchone()
            if not plan:
                return {"error": f"plan {pid} not found"}
            conn.execute(
                "UPDATE plans SET status='todo', tasks_done=0, execution_host=NULL WHERE id=?",
                (pid,),
            )
            conn.execute(
                "UPDATE waves SET status='pending', tasks_done=0 WHERE plan_id=?", (pid,)
            )
            conn.execute(
                "UPDATE tasks SET status='pending', executor_agent=NULL, executor_host=NULL, tokens=NULL, validated_at=NULL, started_at=NULL, completed_at=NULL WHERE plan_id=? AND status NOT IN ('done','skipped')",
                (pid,),
            )
        return {"ok": True, "plan_id": pid, "action": "reset"}
    except (sqlite3.OperationalError, sqlite3.DatabaseError) as e:
        return {"error": str(e)}


def handle_plan_move(qs: dict) -> dict:
    plan_id, target = qs.get("plan_id", [""])[0], qs.get("target", [""])[0]
    if not plan_id or not plan_id.isdigit() or not target:
        return {"error": "missing plan_id or target"}
    pid = int(plan_id)
    try:
        with sqlite3.connect(str(DB_PATH), timeout=5) as conn:
            row = conn.execute(
                "SELECT status, COALESCE(execution_host, '') FROM plans WHERE id=?",
                (pid,),
            ).fetchone()
            if not row:
                return {"error": f"plan {pid} not found"}
            status, current_host = row
            if status == "doing" and current_host and current_host != target:
                conn.execute("UPDATE plans SET status='todo' WHERE id=?", (pid,))
            conn.execute("UPDATE plans SET execution_host=? WHERE id=?", (target, pid))
            if status == "doing":
                conn.execute("UPDATE plans SET status='doing' WHERE id=?", (pid,))
            conn.execute(
                "UPDATE tasks SET executor_host=? WHERE plan_id=? AND status IN ('pending','in_progress','submitted')",
                (target, pid),
            )
        return {"ok": True, "plan_id": pid, "target": target}
    except (sqlite3.OperationalError, sqlite3.DatabaseError) as e:
        return {"error": str(e)}


def _ssh_run(dest: str, cmd: str, timeout: int = 10) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", dest, cmd],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def handle_pull_remote_db(handler, _qs: dict):
    from mesh_handoff import pull_db_from_peer

    plans = query(
        "SELECT id, execution_host FROM plans WHERE status IN ('todo','doing') AND execution_host IS NOT NULL AND execution_host <> ''"
    )
    local_host = subprocess.run(
        ["hostname", "-s"], capture_output=True, text=True, timeout=5
    ).stdout.strip()
    peer_plans: dict[str, list[int]] = {}
    for p in plans:
        host = p["execution_host"]
        if peer_host_match(local_peer_name(), host) or host == local_host:
            continue
        pc = find_peer_conf(host)
        ssh_dest = pc.get("ssh_alias", host) if pc else host
        peer_plans.setdefault(ssh_dest, []).append(p["id"])
    results = [
        {"peer": ssh_dest, "plans": plan_ids, "ok": ok, "detail": detail}
        for ssh_dest, plan_ids in peer_plans.items()
        for ok, detail in [pull_db_from_peer(ssh_dest, plan_ids)]
    ]
    handler._json_response({"synced": results, "count": len(results)})
