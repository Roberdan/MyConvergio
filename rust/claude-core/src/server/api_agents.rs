use super::state::{query_rows, ApiError, ServerState};
use axum::extract::State;
use axum::routing::get;
use axum::{Json, Router};
use serde_json::{json, Value};

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/agents", get(api_agents))
        .route("/api/sessions", get(api_sessions))
        .route("/api/brain", get(api_brain))
}

async fn api_agents(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let running = query_rows(
        db.connection(),
        "SELECT agent_id, agent_type AS type, model, description, task_db_id, plan_id, host, region, parent_session, tokens_in, tokens_out, tokens_total, cost_usd, started_at, ROUND((julianday('now') - julianday(started_at)) * 86400, 1) AS duration_s FROM agent_activity WHERE status='running' ORDER BY started_at DESC",
        [],
    )
    .unwrap_or_default();
    let recent = query_rows(
        db.connection(),
        "SELECT agent_id, status, duration_s, tokens_total, cost_usd, agent_type AS type, model, completed_at, parent_session, description FROM agent_activity WHERE status IN ('completed','failed') AND completed_at >= datetime('now', '-1 hour') ORDER BY completed_at DESC LIMIT 20",
        [],
    )
    .unwrap_or_default();
    let by_model = query_rows(
        db.connection(),
        "SELECT COALESCE(model,'unknown') AS model, COALESCE(SUM(tokens_total),0) AS tokens FROM agent_activity GROUP BY model ORDER BY tokens DESC",
        [],
    )
    .unwrap_or_default();
    Ok(Json(json!({
        "running": running,
        "recent": recent,
        "stats": {"active_count": running.len(), "by_model": by_model}
    })))
}

async fn api_sessions(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let sessions = query_rows(
        db.connection(),
        "SELECT agent_id, agent_type AS type, description, status, metadata, started_at, tokens_total, cost_usd, model, ROUND((julianday('now') - julianday(started_at)) * 86400, 1) AS duration_s FROM agent_activity WHERE agent_id LIKE 'session-%' AND status='running' ORDER BY started_at",
        [],
    )
    .unwrap_or_default();
    Ok(Json(Value::Array(sessions)))
}

/// Consolidated endpoint for the neural graph: sessions + sub-agents + plans + tasks
async fn api_brain(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;

    // Running sessions with full metadata
    let sessions = query_rows(
        db.connection(),
        "SELECT agent_id, agent_type AS type, description, status, metadata, started_at, tokens_in, tokens_out, tokens_total, cost_usd, model, ROUND((julianday('now') - julianday(started_at)) * 86400, 1) AS duration_s FROM agent_activity WHERE agent_id LIKE 'session-%' AND status='running' ORDER BY started_at",
        [],
    ).unwrap_or_default();

    // Running sub-agents with parent linkage
    let agents = query_rows(
        db.connection(),
        "SELECT agent_id, agent_type AS type, model, description, parent_session, task_db_id, plan_id, host, tokens_in, tokens_out, tokens_total, cost_usd, started_at, ROUND((julianday('now') - julianday(started_at)) * 86400, 1) AS duration_s FROM agent_activity WHERE status='running' AND agent_id NOT LIKE 'session-%' ORDER BY started_at DESC",
        [],
    ).unwrap_or_default();

    // Recent completed agents (last hour)
    let recent = query_rows(
        db.connection(),
        "SELECT agent_id, agent_type AS type, model, description, parent_session, status, tokens_total, cost_usd, duration_s, completed_at FROM agent_activity WHERE status IN ('completed','failed') AND completed_at >= datetime('now', '-1 hour') ORDER BY completed_at DESC LIMIT 30",
        [],
    ).unwrap_or_default();

    // Active plans with progress
    let plans = query_rows(
        db.connection(),
        "SELECT id, name, status, execution_host, tasks_done, tasks_total, ROUND(CASE WHEN tasks_total>0 THEN 100.0*tasks_done/tasks_total ELSE 0 END, 1) AS progress_pct FROM plans WHERE status='doing'",
        [],
    ).unwrap_or_default();

    // Tasks from active plans (all statuses for brain viz)
    let tasks = query_rows(
        db.connection(),
        "SELECT t.id, t.title, t.status, t.task_id, t.assignee, t.priority, t.type AS task_type, t.tokens, t.started_at, t.executor_session_id, t.executor_host, t.model, t.wave_id, t.output_data, p.name AS plan_name, p.id AS plan_id, w.name AS wave_name FROM tasks t JOIN plans p ON t.plan_id = p.id LEFT JOIN waves w ON t.wave_id_fk = w.id WHERE p.status = 'doing' ORDER BY t.status DESC, t.priority, t.id LIMIT 200",
        [],
    ).unwrap_or_default();

    // File changes from plan_commits (if any)
    let commits = query_rows(
        db.connection(),
        "SELECT pc.commit_sha, pc.commit_message, pc.lines_added, pc.lines_removed, pc.files_changed, pc.plan_id, pc.authored_at FROM plan_commits pc JOIN plans p ON pc.plan_id = p.id WHERE p.status = 'doing' OR pc.authored_at >= datetime('now', '-2 hours') ORDER BY pc.authored_at DESC LIMIT 20",
        [],
    ).unwrap_or_default();

    // Token totals per model (today)
    let token_summary = query_rows(
        db.connection(),
        "SELECT COALESCE(model,'unknown') AS model, COUNT(*) AS count, COALESCE(SUM(tokens_total),0) AS tokens, COALESCE(SUM(cost_usd),0) AS cost FROM agent_activity WHERE started_at >= date('now') GROUP BY model ORDER BY tokens DESC",
        [],
    ).unwrap_or_default();

    Ok(Json(json!({
        "sessions": sessions,
        "agents": agents,
        "recent": recent,
        "plans": plans,
        "tasks": tasks,
        "commits": commits,
        "token_summary": token_summary
    })))
}
