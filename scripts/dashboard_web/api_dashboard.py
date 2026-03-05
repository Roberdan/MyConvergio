import json
import os
import subprocess
import threading
import time
from collections import defaultdict
from pathlib import Path

from middleware import query, query_one


# --- JSONL Token Scraper ---
# Claude Code sessions store token usage in ~/.claude/projects/*/session.jsonl
# This scraper reads those files and merges the data into the daily token view.

_jsonl_cache: dict = {"data": {}, "ts": 0, "file_state": {}}
_JSONL_CACHE_TTL = 600  # JSONL is a fallback supplement; DB hooks are primary
_jsonl_lock = threading.Lock()
_jsonl_bg_running = False


def _parse_jsonl_lines(fh) -> dict[str, dict]:
    """Parse token usage from JSONL lines. Returns {date: {input, output}}."""
    daily: dict[str, dict] = defaultdict(lambda: {"input": 0, "output": 0})
    for line in fh:
        try:
            obj = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            continue
        if obj.get("type") != "assistant":
            continue
        msg = obj.get("message")
        if not isinstance(msg, dict):
            continue
        usage = msg.get("usage")
        if not usage:
            continue
        ts = obj.get("timestamp", "")
        if len(ts) < 10:
            continue
        day = ts[:10]
        inp = (
            usage.get("input_tokens", 0)
            + usage.get("cache_creation_input_tokens", 0)
            + usage.get("cache_read_input_tokens", 0)
        )
        out = usage.get("output_tokens", 0)
        daily[day]["input"] += inp
        daily[day]["output"] += out
    return dict(daily)


def _scrape_jsonl_tokens_sync() -> dict[str, dict]:
    """Internal: do the actual JSONL scan (called from background thread)."""
    base = Path.home() / ".claude" / "projects"
    if not base.exists():
        return _jsonl_cache.get("data") or {}

    now = time.time()
    cutoff = now - 35 * 86400
    prev_state: dict = _jsonl_cache.get("file_state", {})
    merged: dict[str, dict] = defaultdict(lambda: {"input": 0, "output": 0})

    prev_file_data: dict = _jsonl_cache.get("file_data", {})

    current_files: set[str] = set()
    new_file_state: dict = {}
    new_file_data: dict = {}

    for jsonl_path in base.rglob("*.jsonl"):
        try:
            st = jsonl_path.stat()
            if st.st_mtime < cutoff:
                continue
        except (OSError, PermissionError):
            continue

        key = str(jsonl_path)
        current_files.add(key)
        prev = prev_state.get(key)
        cur_mtime = st.st_mtime
        cur_size = st.st_size

        if prev and prev["mtime"] == cur_mtime and prev["size"] == cur_size:
            new_file_state[key] = prev
            if key in prev_file_data:
                new_file_data[key] = prev_file_data[key]
            continue

        try:
            if prev and cur_size >= prev["size"] and prev.get("offset", 0) > 0:
                with open(jsonl_path, "r", encoding="utf-8", errors="ignore") as fh:
                    fh.seek(prev["offset"])
                    new_daily = _parse_jsonl_lines(fh)
                    new_offset = fh.tell()
                file_daily = dict(prev_file_data.get(key, {}))
                for day, vals in new_daily.items():
                    if day in file_daily:
                        file_daily[day] = {
                            "input": file_daily[day]["input"] + vals["input"],
                            "output": file_daily[day]["output"] + vals["output"],
                        }
                    else:
                        file_daily[day] = vals
            else:
                with open(jsonl_path, "r", encoding="utf-8", errors="ignore") as fh:
                    file_daily = _parse_jsonl_lines(fh)
                    new_offset = fh.tell()

            new_file_state[key] = {
                "mtime": cur_mtime,
                "size": cur_size,
                "offset": new_offset,
            }
            new_file_data[key] = file_daily
        except (OSError, PermissionError):
            continue

    for key in current_files:
        fd = new_file_data.get(key, prev_file_data.get(key, {}))
        if fd:
            new_file_data.setdefault(key, fd)
            for day, vals in fd.items():
                merged[day]["input"] += vals["input"]
                merged[day]["output"] += vals["output"]

    result = dict(merged)
    with _jsonl_lock:
        _jsonl_cache.update({
            "data": result,
            "ts": time.time(),
            "file_state": new_file_state,
            "file_data": new_file_data,
        })
    return result


def _scrape_jsonl_bg():
    """Run JSONL scan in background thread — never blocks HTTP."""
    global _jsonl_bg_running
    try:
        _scrape_jsonl_tokens_sync()
    finally:
        _jsonl_bg_running = False


def _scrape_jsonl_tokens() -> dict[str, dict]:
    """Non-blocking JSONL scraper. Returns cached data immediately;
    triggers background refresh if cache is stale."""
    global _jsonl_bg_running
    now = time.time()
    with _jsonl_lock:
        if _jsonl_cache["data"] and (now - _jsonl_cache["ts"]) < _JSONL_CACHE_TTL:
            return _jsonl_cache["data"]
    # Cache stale — kick off background scan, return stale data immediately
    if not _jsonl_bg_running:
        _jsonl_bg_running = True
        threading.Thread(target=_scrape_jsonl_bg, daemon=True).start()
    return _jsonl_cache.get("data") or {}


def api_overview() -> dict:
    ov = query_one(
        "SELECT COUNT(*) FILTER (WHERE status IN ('todo','doing')) AS active, COUNT(*) FILTER (WHERE status='done') AS done, COUNT(*) AS total FROM plans"
    ) or {"active": 0, "done": 0, "total": 0}
    running = query_one(
        "SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE t.status='in_progress' AND p.status='doing'"
    ) or {"c": 0}
    blocked = query_one(
        "SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE t.status='blocked' AND p.status='doing'"
    ) or {"c": 0}
    ts = query_one(
        "SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS total_tok, COALESCE(SUM(cost_usd),0) AS total_cost FROM token_usage"
    ) or {"total_tok": 0, "total_cost": 0}
    today_str = time.strftime("%Y-%m-%d")
    today_db = query_one(
        "SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS tok, COALESCE(SUM(cost_usd),0) AS cost FROM token_usage WHERE date(created_at)=date('now')"
    ) or {"tok": 0, "cost": 0}

    # Supplement with JSONL session data
    jsonl = _scrape_jsonl_tokens()
    jsonl_total = sum(d["input"] + d["output"] for d in jsonl.values())
    jsonl_today = jsonl.get(today_str, {})
    jsonl_today_tok = jsonl_today.get("input", 0) + jsonl_today.get("output", 0)

    total_tokens = max(ts["total_tok"], jsonl_total)
    today_tokens = max(today_db["tok"], jsonl_today_tok)

    return {
        "plans_total": ov["total"],
        "plans_active": ov["active"],
        "plans_done": ov["done"],
        "agents_running": running["c"],
        "blocked": blocked["c"],
        "total_tokens": total_tokens,
        "total_cost": ts["total_cost"],
        "today_tokens": today_tokens,
        "today_cost": today_db["cost"],
    }


def _detect_plan_health(plan: dict, waves: list, tasks: list) -> list[dict]:
    """Detect health issues for a plan. Returns list of {severity, code, message}."""
    alerts = []
    if plan["status"] != "doing":
        return alerts
    done_count = plan.get("tasks_done") or 0
    total_count = plan.get("tasks_total") or 0
    blocked = [t for t in tasks if t["status"] == "blocked"]
    in_progress = [t for t in tasks if t["status"] == "in_progress"]
    pending = [t for t in tasks if t["status"] == "pending"]
    submitted = [t for t in tasks if t["status"] == "submitted"]

    # BLOCKED: tasks stuck
    if blocked:
        alerts.append(
            {
                "severity": "critical",
                "code": "blocked",
                "message": f"{len(blocked)} task bloccati: {', '.join(t['task_id'] for t in blocked[:3])}",
            }
        )

    # STALE: doing but no in_progress and not finished
    if not in_progress and not submitted and done_count < total_count and pending:
        alerts.append(
            {
                "severity": "critical",
                "code": "stale",
                "message": f"Piano fermo: {len(pending)} task pending, nessuno in esecuzione",
            }
        )

    # STUCK DEPLOY: all dev waves done but deploy/closure wave pending
    done_waves = [w for w in waves if w["status"] == "done"]
    pending_waves = [w for w in waves if w["status"] == "pending"]
    if done_waves and pending_waves:
        last_pending = pending_waves[0]
        wid = (last_pending.get("wave_id") or "").lower()
        wname = (last_pending.get("name") or "").lower()
        if any(k in wid + wname for k in ("deploy", "closure", "release", "prod")):
            alerts.append(
                {
                    "severity": "warning",
                    "code": "stuck_deploy",
                    "message": f"Wave deploy '{last_pending['wave_id']}' non partita ({len(done_waves)} wave completate)",
                }
            )

    # MANUAL REQUIRED: pending tasks that truly need human intervention
    manual_keywords = (
        "manual test",
        "manual review",
        "manual deploy",
        "visual qa",
        "user acceptance",
        "manual approval",
    )
    manual_tasks = [
        t
        for t in pending
        if any(k in (t.get("title") or "").lower() for k in manual_keywords)
    ]
    if manual_tasks:
        alerts.append(
            {
                "severity": "warning",
                "code": "manual_required",
                "message": f"{len(manual_tasks)} task richiedono intervento: {', '.join(t['task_id'] for t in manual_tasks[:3])}",
            }
        )

    # THOR STUCK: submitted for too long (no validated_at, still submitted)
    thor_stuck = [t for t in submitted if not t.get("validated_at")]
    if thor_stuck:
        alerts.append(
            {
                "severity": "warning",
                "code": "thor_stuck",
                "message": f"{len(thor_stuck)} task in attesa Thor: {', '.join(t['task_id'] for t in thor_stuck[:3])}",
            }
        )

    # NO PROGRESS: high completion but stuck
    if total_count > 0:
        pct = round(100 * done_count / total_count)
        if pct >= 80 and pending and not in_progress and not submitted:
            alerts.append(
                {
                    "severity": "warning",
                    "code": "near_complete_stuck",
                    "message": f"{pct}% completato ma {len(pending)} task pending non avviati",
                }
            )

    return alerts


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
            "SELECT task_id,title,status,executor_agent,executor_host,tokens,validated_at,model,wave_id FROM tasks WHERE plan_id=? ORDER BY wave_id_fk,id",
            (p["id"],),
        )
        health = _detect_plan_health(p, waves, tasks)
        result.append({"plan": p, "waves": waves, "tasks": tasks, "health": health})
    return {
        "plans": result,
        "plan": plans[0],
        "waves": result[0]["waves"],
        "tasks": result[0]["tasks"],
    }


def api_tokens_daily() -> list[dict]:
    db_rows = query(
        "SELECT date(created_at) AS day, SUM(input_tokens) AS input, SUM(output_tokens) AS output, SUM(cost_usd) AS cost FROM token_usage WHERE date(created_at)>=date('now','-30 days') GROUP BY day ORDER BY day"
    )
    db_map: dict[str, dict] = {r["day"]: r for r in db_rows}

    jsonl_data = _scrape_jsonl_tokens()

    # Merge: for each day, use the higher of DB vs JSONL values
    all_days = sorted(set(db_map.keys()) | set(jsonl_data.keys()))
    result = []
    for day in all_days:
        db = db_map.get(day, {})
        jl = jsonl_data.get(day, {})
        result.append(
            {
                "day": day,
                "input": max(db.get("input") or 0, jl.get("input", 0)),
                "output": max(db.get("output") or 0, jl.get("output", 0)),
                "cost": db.get("cost") or 0,
            }
        )
    return result


def api_tokens_by_model() -> list[dict]:
    return query(
        "SELECT model, SUM(input_tokens+output_tokens) AS tokens, SUM(cost_usd) AS cost FROM token_usage WHERE model IS NOT NULL GROUP BY model ORDER BY tokens DESC LIMIT 8"
    )


def api_history() -> list[dict]:
    return query(
        "SELECT id,name,status,tasks_done,tasks_total,project_id,started_at,completed_at,human_summary,lines_added,lines_removed FROM plans WHERE status IN ('done','archived','cancelled') ORDER BY id DESC LIMIT 20"
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
        "SELECT task_id,title,status,executor_agent,executor_host,tokens,started_at,completed_at,validated_at,model,wave_id FROM tasks WHERE plan_id=? ORDER BY wave_id_fk,id",
        (plan_id,),
    )
    cost = query_one(
        "SELECT COALESCE(SUM(cost_usd),0) AS cost, COALESCE(SUM(input_tokens+output_tokens),0) AS tokens FROM token_usage WHERE project_id=(SELECT project_id FROM plans WHERE id=?)",
        (plan_id,),
    ) or {"cost": 0, "tokens": 0}
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
        "SELECT id,name,status,tasks_done,tasks_total,execution_host,human_summary FROM plans WHERE status IN ('todo','doing') ORDER BY id"
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
