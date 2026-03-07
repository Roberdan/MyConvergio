"""API handler for /api/agents — real-time agent activity for brain visualization."""

import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.dashboard_web.middleware import query
else:
    from .middleware import query


def _build_sessions():
    """Build hierarchical session → children structure via single JOIN query."""
    rows = query(
        "SELECT s.agent_id AS session_id, s.agent_type AS session_type,"
        "  s.metadata AS session_meta,"
        "  c.agent_id AS child_id, c.agent_type AS child_type,"
        "  c.status AS child_status, c.description AS child_desc,"
        "  c.duration_s AS child_dur, c.model AS child_model,"
        "  c.started_at AS child_started"
        " FROM agent_activity s"
        " LEFT JOIN agent_activity c ON c.parent_session = s.agent_id"
        " WHERE s.agent_id LIKE 'session-%' AND s.status = 'running'"
        " ORDER BY s.agent_id, c.started_at DESC"
    )
    sess_map = {}
    for r in rows:
        sid = r["session_id"]
        if sid not in sess_map:
            parts = sid.split("-")  # session-{tool}-cli-{pid}
            pid = int(parts[-1]) if parts[-1].isdigit() else 0
            sess_map[sid] = {
                "session_id": sid, "type": r["session_type"],
                "pid": pid, "children": [],
            }
        if r.get("child_id"):
            sess_map[sid]["children"].append({
                "agent_id": r["child_id"], "type": r["child_type"],
                "status": r["child_status"], "description": r["child_desc"],
                "duration_s": r["child_dur"], "model": r["child_model"],
            })
    orphans = query(
        "SELECT agent_id, agent_type AS type, status, description,"
        "  duration_s, model"
        " FROM agent_activity"
        " WHERE parent_session IS NOT NULL"
        "  AND parent_session NOT IN"
        "    (SELECT agent_id FROM agent_activity WHERE agent_id LIKE 'session-%')"
        "  AND status = 'running'"
    )
    return list(sess_map.values()), orphans


def api_agents():
    """Return running agents, recent completions, sessions, and stats."""
    running = query(
        "SELECT agent_id, agent_type AS type, model, description,"
        " task_db_id, plan_id, host, region, parent_session,"
        " ROUND((julianday('now') - julianday(started_at)) * 86400, 1) AS duration_s"
        " FROM agent_activity WHERE status = 'running'"
        " ORDER BY started_at DESC"
    )
    recent = query(
        "SELECT agent_id, status, duration_s, tokens_total, cost_usd,"
        " agent_type AS type, model, completed_at, parent_session"
        " FROM agent_activity"
        " WHERE status IN ('completed', 'failed')"
        " AND completed_at >= datetime('now', '-1 hour')"
        " ORDER BY completed_at DESC LIMIT 20"
    )
    stats_row = query(
        "SELECT COALESCE(SUM(tokens_total), 0) AS total_tokens,"
        " COALESCE(SUM(cost_usd), 0) AS total_cost"
        " FROM agent_activity"
    )
    stats = stats_row[0] if stats_row else {"total_tokens": 0, "total_cost": 0}
    stats["active_count"] = len(running)
    ct = query(
        "SELECT COUNT(*) AS c FROM agent_activity"
        " WHERE status IN ('completed', 'failed')"
        " AND date(completed_at) = date('now')"
    )
    stats["completed_today"] = ct[0]["c"] if ct else 0
    by_model = query(
        "SELECT COALESCE(model, 'unknown') AS model,"
        " SUM(tokens_total) AS tokens"
        " FROM agent_activity GROUP BY model ORDER BY tokens DESC"
    )
    stats["by_model"] = {r["model"]: r["tokens"] for r in by_model}

    sessions, orphan_agents = _build_sessions()
    return {
        "running": running, "recent": recent, "stats": stats,
        "sessions": sessions, "orphan_agents": orphan_agents,
    }
