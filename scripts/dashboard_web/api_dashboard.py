import os
import subprocess

from middleware import query, query_one


def api_overview() -> dict:
    ov = query_one("SELECT COUNT(*) FILTER (WHERE status IN ('todo','doing')) AS active, COUNT(*) FILTER (WHERE status='done') AS done, COUNT(*) AS total FROM plans") or {"active": 0, "done": 0, "total": 0}
    running = query_one("SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE t.status='in_progress' AND p.status='doing'") or {"c": 0}
    blocked = query_one("SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE t.status='blocked' AND p.status='doing'") or {"c": 0}
    ts = query_one("SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS total_tok, COALESCE(SUM(cost_usd),0) AS total_cost FROM token_usage") or {"total_tok": 0, "total_cost": 0}
    today = query_one("SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS tok, COALESCE(SUM(cost_usd),0) AS cost FROM token_usage WHERE date(created_at)=date('now')") or {"tok": 0, "cost": 0}
    return {"plans_total": ov["total"], "plans_active": ov["active"], "plans_done": ov["done"], "agents_running": running["c"], "blocked": blocked["c"], "total_tokens": ts["total_tok"], "total_cost": ts["total_cost"], "today_tokens": today["tok"], "today_cost": today["cost"]}


def api_mission(resolve_host_to_peer) -> dict:
    plans = query("SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.human_summary,p.execution_host,p.parallel_mode,p.project_id,pr.name AS project_name,pr.path AS project_path FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.status IN ('todo','doing') ORDER BY p.id DESC")
    if not plans:
        return {"plans": []}
    result = []
    for p in plans:
        p["execution_peer"] = resolve_host_to_peer(p.get("execution_host", ""))
        waves = query("SELECT wave_id,name,status,tasks_done,tasks_total,position,validated_at FROM waves WHERE plan_id=? ORDER BY position", (p["id"],))
        tasks = query("SELECT task_id,title,status,executor_agent,executor_host,tokens,validated_at,model,wave_id FROM tasks WHERE plan_id=? ORDER BY wave_id_fk,id", (p["id"],))
        result.append({"plan": p, "waves": waves, "tasks": tasks})
    return {"plans": result, "plan": plans[0], "waves": result[0]["waves"], "tasks": result[0]["tasks"]}


def api_tokens_daily() -> list[dict]:
    return query("SELECT date(created_at) AS day, SUM(input_tokens) AS input, SUM(output_tokens) AS output, SUM(cost_usd) AS cost FROM token_usage WHERE date(created_at)>=date('now','-30 days') GROUP BY day ORDER BY day")


def api_tokens_by_model() -> list[dict]:
    return query("SELECT model, SUM(input_tokens+output_tokens) AS tokens, SUM(cost_usd) AS cost FROM token_usage WHERE model IS NOT NULL GROUP BY model ORDER BY tokens DESC LIMIT 8")


def api_history() -> list[dict]:
    return query("SELECT id,name,status,tasks_done,tasks_total,project_id,started_at,completed_at,human_summary,lines_added,lines_removed FROM plans WHERE status IN ('done','archived','cancelled') ORDER BY id DESC LIMIT 20")


def api_plan_detail(plan_id: int) -> dict | None:
    p = query_one("SELECT id,name,status,tasks_done,tasks_total,project_id,human_summary,started_at,completed_at,parallel_mode,lines_added,lines_removed,execution_host FROM plans WHERE id=?", (plan_id,))
    if not p:
        return None
    waves = query("SELECT wave_id,name,status,tasks_done,tasks_total,branch_name,pr_number,pr_url,position,validated_at FROM waves WHERE plan_id=? ORDER BY position", (plan_id,))
    tasks = query("SELECT task_id,title,status,executor_agent,executor_host,tokens,started_at,completed_at,validated_at,model,wave_id FROM tasks WHERE plan_id=? ORDER BY wave_id_fk,id", (plan_id,))
    cost = query_one("SELECT COALESCE(SUM(cost_usd),0) AS cost, COALESCE(SUM(input_tokens+output_tokens),0) AS tokens FROM token_usage WHERE project_id=(SELECT project_id FROM plans WHERE id=?)", (plan_id,)) or {"cost": 0, "tokens": 0}
    return {"plan": p, "waves": waves, "tasks": tasks, "cost": cost}


def api_task_status_dist() -> list[dict]:
    return query("SELECT t.status, COUNT(*) AS count FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE p.status='doing' GROUP BY t.status ORDER BY count DESC")


def api_tasks_blocked() -> list[dict]:
    return query("SELECT t.task_id, t.title, t.status, p.id AS plan_id, p.name AS plan_name FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE t.status='blocked' AND p.status IN ('doing','todo')")


def api_assignable_plans() -> list[dict]:
    return query("SELECT id,name,status,tasks_done,tasks_total,execution_host,human_summary FROM plans WHERE status IN ('todo','doing') ORDER BY id")


def api_notifications() -> list[dict]:
    return query("SELECT id, type, title, message, link, link_type, is_read, created_at FROM notifications WHERE is_read=0 ORDER BY created_at DESC LIMIT 20")


def api_events() -> list[dict]:
    return query("SELECT id, event_type, plan_id, source_peer, payload, status, created_at FROM mesh_events ORDER BY created_at DESC LIMIT 50")


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
    pending = query_one("SELECT COUNT(*) AS c FROM mesh_events WHERE status='pending'") or {"c": 0}
    return {"running": running, "pid": pid, "pending_events": pending["c"]}


def api_coordinator_toggle() -> dict:
    scripts = os.path.expanduser("~/.claude/scripts")
    status = api_coordinator_status()
    cmd = [f"{scripts}/mesh-coordinator.sh", "stop" if status["running"] else "start"]
    subprocess.run(cmd, capture_output=True, timeout=10)
    return {"action": "stopped" if status["running"] else "started", "ok": True}
