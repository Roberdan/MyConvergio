import os
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.dashboard_web.lib.agent_organization import build_agent_organization
    from scripts.dashboard_web.lib.live_runtime import build_live_system_snapshot
    from scripts.dashboard_web.lib.plan_health import (
        detect_plan_health as _detect_plan_health,
    )
    from scripts.dashboard_web.middleware import ensure_live_runtime_schema
    from scripts.dashboard_web.middleware import query, query_one
else:
    from .lib.agent_organization import build_agent_organization
    from .lib.live_runtime import build_live_system_snapshot
    from .lib.plan_health import detect_plan_health as _detect_plan_health
    from .middleware import ensure_live_runtime_schema
    from .middleware import query, query_one


_ATTRIBUTED_TOKEN_WHERE = (
    "((plan_id IS NOT NULL AND CAST(plan_id AS TEXT) != 'NULL')"
    " OR (task_id IS NOT NULL AND task_id != ''))"
)


def _reconcile_progress(plan: dict, waves: list[dict], tasks: list[dict]) -> tuple[dict, list[dict]]:
    plan = dict(plan)
    waves = [dict(w) for w in waves]
    wave_map = {w["wave_id"]: w for w in waves}
    plan["tasks_total"] = len(tasks)
    plan["tasks_done"] = sum(1 for t in tasks if t.get("status") == "done")
    for wave in waves:
        wave["tasks_total"] = 0
        wave["tasks_done"] = 0
    for task in tasks:
        wave = wave_map.get(task.get("wave_id"))
        if not wave:
            continue
        wave["tasks_total"] += 1
        if task.get("status") == "done":
            wave["tasks_done"] += 1
    return plan, waves


def _merge_task_tokens(plan_id: int, tasks: list[dict]) -> list[dict]:
    rows = query(
        "SELECT task_id, SUM(input_tokens + output_tokens) AS tokens"
        f" FROM token_usage WHERE plan_id=? AND {_ATTRIBUTED_TOKEN_WHERE}"
        " GROUP BY task_id",
        (plan_id,),
    )
    token_map = {str(row["task_id"]): row["tokens"] for row in rows if row.get("task_id") is not None}
    delegation_rows = query(
        "SELECT task_db_id, SUM(prompt_tokens + response_tokens) AS tokens"
        " FROM delegation_log WHERE plan_id=? GROUP BY task_db_id",
        (plan_id,),
    )
    delegation_map = {
        int(row["task_db_id"]): row["tokens"] for row in delegation_rows if row.get("task_db_id") is not None
    }
    merged = []
    for task in tasks:
        task = dict(task)
        if not task.get("tokens"):
            task_key = str(task.get("task_id")) if task.get("task_id") is not None else None
            db_key = str(task.get("id")) if task.get("id") is not None else None
            if task_key in token_map:
                task["tokens"] = token_map[task_key]
            elif db_key in token_map:
                task["tokens"] = token_map[db_key]
            elif task.get("id") in delegation_map:
                task["tokens"] = delegation_map[task["id"]]
        merged.append(task)
    return merged


def api_overview() -> dict:
    ov = query_one(
        "SELECT COUNT(*) FILTER (WHERE status IN ('todo','doing')) AS active, COUNT(*) FILTER (WHERE status='done') AS done, COUNT(*) AS total FROM plans"
    ) or {"active": 0, "done": 0, "total": 0}
    running = query_one(
        "SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE t.status='in_progress' AND p.status='doing'"
    ) or {"c": 0}
    blocked = query_one(
        "SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id"
        " WHERE p.status='doing' AND (t.status='blocked'"
        " OR (t.status='submitted' AND COALESCE(t.executor_last_activity, t.executor_started_at, t.started_at) < datetime('now', '-5 minutes')))"
    ) or {"c": 0}
    ts = query_one(
        f"SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS total_tok, COALESCE(SUM(cost_usd),0) AS total_cost FROM token_usage WHERE {_ATTRIBUTED_TOKEN_WHERE}"
    ) or {"total_tok": 0, "total_cost": 0}
    delegation_total = query_one(
        "SELECT COALESCE(SUM(d.prompt_tokens + d.response_tokens), 0) AS total_tok"
        " FROM delegation_log d"
        " WHERE NOT EXISTS ("
        "   SELECT 1 FROM token_usage tu"
        f"   WHERE tu.plan_id = d.plan_id AND {_ATTRIBUTED_TOKEN_WHERE}"
        "     AND CAST(tu.task_id AS TEXT) = CAST(d.task_db_id AS TEXT)"
        " )"
    ) or {"total_tok": 0}
    today_db = query_one(
        f"SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS tok, COALESCE(SUM(cost_usd),0) AS cost FROM token_usage WHERE {_ATTRIBUTED_TOKEN_WHERE} AND date(created_at)=date('now')"
    ) or {"tok": 0, "cost": 0}
    delegation_today = query_one(
        "SELECT COALESCE(SUM(d.prompt_tokens + d.response_tokens), 0) AS tok"
        " FROM delegation_log d"
        " WHERE date(d.created_at)=date('now')"
        " AND NOT EXISTS ("
        "   SELECT 1 FROM token_usage tu"
        f"   WHERE tu.plan_id = d.plan_id AND {_ATTRIBUTED_TOKEN_WHERE}"
        "     AND CAST(tu.task_id AS TEXT) = CAST(d.task_db_id AS TEXT)"
        " )"
    ) or {"tok": 0}

    return {
        "plans_total": ov["total"],
        "plans_active": ov["active"],
        "plans_done": ov["done"],
        "agents_running": running["c"],
        "blocked": blocked["c"],
        "total_tokens": ts["total_tok"] + delegation_total["total_tok"],
        "total_cost": ts["total_cost"],
        "today_tokens": today_db["tok"] + delegation_today["tok"],
        "today_cost": today_db["cost"],
    }


def api_mission(resolve_host_to_peer) -> dict:
    plans = query(
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.human_summary,p.execution_host,p.parallel_mode,p.project_id,p.worktree_path,pr.name AS project_name,pr.path AS project_path FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.status IN ('todo','doing') ORDER BY p.id DESC"
    )
    if not plans:
        return {"plans": []}
    result = []
    for p in plans:
        p["execution_peer"] = resolve_host_to_peer(p.get("execution_host", ""))
        waves = query(
            "SELECT wave_id,name,status,tasks_done,tasks_total,position FROM waves WHERE plan_id=? ORDER BY position",
            (p["id"],),
        )
        tasks = query(
            "SELECT id,task_id,title,status,executor_agent,executor_host,tokens,validated_at,model,wave_id FROM tasks WHERE plan_id=? ORDER BY wave_id_fk,id",
            (p["id"],),
        )
        tasks = _merge_task_tokens(p["id"], tasks)
        p, waves = _reconcile_progress(p, waves, tasks)
        for w in waves:
            wt = [t for t in tasks if t.get("wave_id") == w["wave_id"]]
            done_tasks = [t for t in wt if t["status"] == "done"]
            if done_tasks and all(t.get("validated_at") for t in done_tasks):
                w["validated_at"] = min(t["validated_at"] for t in done_tasks)
            else:
                w["validated_at"] = None
        health = _detect_plan_health(p, waves, tasks)
        result.append({"plan": p, "waves": waves, "tasks": tasks, "health": health})
    return {
        "plans": result,
        "plan": plans[0],
        "waves": result[0]["waves"],
        "tasks": result[0]["tasks"],
    }


def api_organization(resolve_host_to_peer, mesh_provider) -> dict:
    mission = api_mission(resolve_host_to_peer)
    peers = mesh_provider()
    return build_agent_organization(mission.get("plans", []), peers)


def api_live_system(resolve_host_to_peer, mesh_provider) -> dict:
    ensure_live_runtime_schema()
    mission = api_mission(resolve_host_to_peer)
    peers = mesh_provider()
    agent_runs = query(
        "SELECT id,plan_id,wave_id,task_id,agent_name,agent_role,model,peer_name,status,started_at,last_heartbeat,current_task"
        " FROM agent_runs ORDER BY COALESCE(last_heartbeat, started_at) DESC LIMIT 80"
    )
    task_events = query(
        "SELECT id,plan_id,wave_id,task_id,run_id,event_type,status,source_agent,target_agent,peer_name,message,created_at"
        " FROM task_events ORDER BY created_at DESC LIMIT 80"
    )
    handoffs = query(
        "SELECT id,plan_id,task_id,from_run_id,to_run_id,handoff_kind,status,created_at,accepted_at"
        " FROM agent_handoffs ORDER BY created_at DESC LIMIT 40"
    )
    return build_live_system_snapshot(mission.get("plans", []), peers, agent_runs, task_events, handoffs)


def api_tokens_daily() -> list[dict]:
    db_rows = query(
        "SELECT date(created_at) AS day, SUM(input_tokens) AS input, SUM(output_tokens) AS output, SUM(cost_usd) AS cost"
        f" FROM token_usage WHERE {_ATTRIBUTED_TOKEN_WHERE} AND date(created_at)>=date('now','-30 days') GROUP BY day ORDER BY day"
    )
    db_map: dict[str, dict] = {r["day"]: r for r in db_rows}
    fallback_rows = query(
        "SELECT date(created_at) AS day, SUM(prompt_tokens) AS input, SUM(response_tokens) AS output"
        " FROM delegation_log d"
        " WHERE date(created_at)>=date('now','-30 days')"
        " AND NOT EXISTS ("
        "   SELECT 1 FROM token_usage tu"
        f"   WHERE tu.plan_id = d.plan_id AND {_ATTRIBUTED_TOKEN_WHERE}"
        "     AND CAST(tu.task_id AS TEXT) = CAST(d.task_db_id AS TEXT)"
        " ) GROUP BY day ORDER BY day"
    )
    fallback_map = {r["day"]: r for r in fallback_rows}
    all_days = sorted(set(db_map.keys()) | set(fallback_map.keys()))
    return [
        {
            "day": day,
            "input": (db_map.get(day, {}).get("input") or 0) + (fallback_map.get(day, {}).get("input") or 0),
            "output": (db_map.get(day, {}).get("output") or 0) + (fallback_map.get(day, {}).get("output") or 0),
            "cost": db_map.get(day, {}).get("cost") or 0,
        }
        for day in all_days
    ]


def api_tokens_by_model() -> list[dict]:
    rows = query(
        f"SELECT model, SUM(input_tokens+output_tokens) AS tokens, SUM(cost_usd) AS cost FROM token_usage WHERE {_ATTRIBUTED_TOKEN_WHERE} AND model IS NOT NULL GROUP BY model ORDER BY tokens DESC LIMIT 8"
    )
    combined = {row["model"]: {"model": row["model"], "tokens": row["tokens"], "cost": row["cost"]} for row in rows}
    fallback = query(
        "SELECT model, SUM(prompt_tokens + response_tokens) AS tokens"
        " FROM delegation_log d"
        " WHERE model IS NOT NULL"
        " AND NOT EXISTS ("
        "   SELECT 1 FROM token_usage tu"
        f"   WHERE tu.plan_id = d.plan_id AND {_ATTRIBUTED_TOKEN_WHERE}"
        "     AND CAST(tu.task_id AS TEXT) = CAST(d.task_db_id AS TEXT)"
        " ) GROUP BY model"
    )
    for row in fallback:
        model = row["model"]
        if model not in combined:
            combined[model] = {"model": model, "tokens": 0, "cost": 0}
        combined[model]["tokens"] += row["tokens"] or 0
    return sorted(combined.values(), key=lambda row: row["tokens"], reverse=True)[:8]


def api_history() -> list[dict]:
    return query(
        "SELECT p.id,p.name,p.status,"
        " COALESCE((SELECT COUNT(*) FROM tasks t WHERE t.plan_id=p.id AND t.status='done'),0) AS tasks_done,"
        " COALESCE((SELECT COUNT(*) FROM tasks t WHERE t.plan_id=p.id),0) AS tasks_total,"
        " p.project_id,p.started_at,p.completed_at,p.human_summary,p.lines_added,p.lines_removed"
        " FROM plans p WHERE p.status IN ('done','cancelled') ORDER BY p.id DESC LIMIT 20"
    )


def api_plan_detail(plan_id: int) -> dict | None:
    p = query_one(
        "SELECT id,name,status,tasks_done,tasks_total,project_id,human_summary,started_at,completed_at,parallel_mode,lines_added,lines_removed,execution_host FROM plans WHERE id=?",
        (plan_id,),
    )
    if not p:
        return None
    waves = query(
        "SELECT wave_id,name,status,tasks_done,tasks_total,branch_name,pr_number,pr_url,position FROM waves WHERE plan_id=? ORDER BY position",
        (plan_id,),
    )
    tasks = query(
        "SELECT id,task_id,title,status,executor_agent,executor_host,tokens,started_at,completed_at,validated_at,model,wave_id FROM tasks WHERE plan_id=? ORDER BY wave_id_fk,id",
        (plan_id,),
    )
    tasks = _merge_task_tokens(plan_id, tasks)
    p, waves = _reconcile_progress(p, waves, tasks)
    task_total_tokens = sum((task.get("tokens") or 0) for task in tasks)
    # Derive wave validated_at from child tasks (waves table has no validated_at column)
    for w in waves:
        wt = [t for t in tasks if t.get("wave_id") == w["wave_id"]]
        done_tasks = [t for t in wt if t["status"] == "done"]
        if done_tasks and all(t.get("validated_at") for t in done_tasks):
            w["validated_at"] = min(t["validated_at"] for t in done_tasks)
        else:
            w["validated_at"] = None
    cost = query_one(
        f"SELECT COALESCE(SUM(cost_usd),0) AS cost, COALESCE(SUM(input_tokens+output_tokens),0) AS tokens FROM token_usage WHERE plan_id=? AND {_ATTRIBUTED_TOKEN_WHERE}",
        (plan_id,),
    ) or {"cost": 0, "tokens": 0}
    if task_total_tokens > cost["tokens"]:
        cost["tokens"] = task_total_tokens
    return {"plan": p, "waves": waves, "tasks": tasks, "cost": cost}


def api_task_status_dist() -> list[dict]:
    return query(
        "SELECT t.status, COUNT(*) AS count FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE p.status='doing' GROUP BY t.status ORDER BY count DESC"
    )


def api_tasks_blocked() -> list[dict]:
    return query(
        "SELECT t.task_id, t.title, t.status, p.id AS plan_id, p.name AS plan_name FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE t.status='blocked' AND p.status IN ('doing','todo')"
    )


def api_assignable_plans() -> list[dict]:
    return query(
        "SELECT p.id,p.name,p.status,"
        " COALESCE((SELECT COUNT(*) FROM tasks t WHERE t.plan_id=p.id AND t.status='done'),0) AS tasks_done,"
        " COALESCE((SELECT COUNT(*) FROM tasks t WHERE t.plan_id=p.id),0) AS tasks_total,"
        " p.execution_host,p.human_summary FROM plans p WHERE p.status IN ('todo','doing') ORDER BY p.id"
    )


def api_notifications() -> list[dict]:
    return query(
        "SELECT id, type, title, message, link, link_type, is_read, created_at FROM notifications WHERE is_read=0 ORDER BY created_at DESC LIMIT 20"
    )


def api_events() -> list[dict]:
    return query(
        "SELECT id, event_type, plan_id, source_peer, payload, status, created_at FROM mesh_events ORDER BY created_at DESC LIMIT 50"
    )


def api_coordinator_status() -> dict:
    pid_file = os.path.expanduser("~/.claude/data/mesh-coordinator.pid")
    running, pid = False, ""
    try:
        with open(pid_file, "r", encoding="utf-8") as f:
            pid = f.read().strip()
        if pid:
            os.kill(int(pid), 0)
            running = True
    except Exception:
        pass
    pending = query_one(
        "SELECT COUNT(*) AS c FROM mesh_events WHERE status='pending'"
    ) or {"c": 0}
    return {"running": running, "pid": pid, "pending_events": pending["c"]}


def api_coordinator_toggle() -> dict:
    scripts = os.path.expanduser("~/.claude/scripts")
    status = api_coordinator_status()
    cmd = [f"{scripts}/mesh-coordinator.sh", "stop" if status["running"] else "start"]
    subprocess.run(cmd, capture_output=True, timeout=10)
    return {"action": "stopped" if status["running"] else "started", "ok": True}
