use super::state::{query_rows, ApiError, ServerState};
use axum::extract::State;
use axum::routing::get;
use axum::{Json, Router};
use serde_json::{json, Value};

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/agents", get(api_agents))
        .route("/api/sessions", get(api_sessions))
}

async fn api_agents(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let running = query_rows(
        db.connection(),
        "SELECT agent_id, agent_type AS type, model, description, task_db_id, plan_id, host, region, parent_session, ROUND((julianday('now') - julianday(started_at)) * 86400, 1) AS duration_s FROM agent_activity WHERE status='running' ORDER BY started_at DESC",
        [],
    )
    .unwrap_or_default();
    let recent = query_rows(
        db.connection(),
        "SELECT agent_id, status, duration_s, tokens_total, cost_usd, agent_type AS type, model, completed_at, parent_session FROM agent_activity WHERE status IN ('completed','failed') AND completed_at >= datetime('now', '-1 hour') ORDER BY completed_at DESC LIMIT 20",
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
        "SELECT agent_id, agent_type AS type, description, status, metadata FROM agent_activity WHERE agent_id LIKE 'session-%' AND status='running'",
        [],
    )
    .unwrap_or_default();
    Ok(Json(Value::Array(sessions)))
}
