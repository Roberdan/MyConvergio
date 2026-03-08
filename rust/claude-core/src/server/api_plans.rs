use super::state::{ApiError, ServerState};
use axum::extract::{Path, Query, State};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};
use std::collections::HashMap;

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/plan/cancel", get(handle_plan_cancel))
        .route("/api/plan/reset", get(handle_plan_reset))
        .route("/api/plan/move", get(handle_plan_move))
        .route("/api/plans/:plan_id/validate", post(handle_plan_validate))
}

async fn handle_plan_validate(
    State(state): State<ServerState>,
    Path(plan_id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let count = db
        .connection()
        .execute(
            "UPDATE tasks SET status='done', validated_at=CURRENT_TIMESTAMP WHERE plan_id=?1 AND status='submitted'",
            rusqlite::params![plan_id],
        )
        .map_err(|err| ApiError::internal(format!("validate failed: {err}")))?;
    Ok(Json(json!({"ok": true, "plan_id": plan_id, "validated": count})))
}

async fn handle_plan_cancel(
    State(state): State<ServerState>,
    Query(qs): Query<HashMap<String, String>>,
) -> Result<Json<Value>, ApiError> {
    let plan_id = qs
        .get("plan_id")
        .ok_or_else(|| ApiError::bad_request("missing plan_id"))?
        .parse::<i64>()
        .map_err(|_| ApiError::bad_request("invalid plan_id"))?;
    let db = state.open_db()?;
    db.connection()
        .execute("UPDATE plans SET status='cancelled' WHERE id=?1", rusqlite::params![plan_id])
        .map_err(|err| ApiError::internal(format!("plan cancel failed: {err}")))?;
    db.connection()
        .execute(
            "UPDATE tasks SET status='cancelled' WHERE plan_id=?1 AND status NOT IN ('done','cancelled','skipped')",
            rusqlite::params![plan_id],
        )
        .map_err(|err| ApiError::internal(format!("task cancel failed: {err}")))?;
    Ok(Json(json!({"ok": true, "plan_id": plan_id, "action": "cancelled"})))
}

async fn handle_plan_reset(
    State(state): State<ServerState>,
    Query(qs): Query<HashMap<String, String>>,
) -> Result<Json<Value>, ApiError> {
    let plan_id = qs
        .get("plan_id")
        .ok_or_else(|| ApiError::bad_request("missing plan_id"))?
        .parse::<i64>()
        .map_err(|_| ApiError::bad_request("invalid plan_id"))?;
    let db = state.open_db()?;
    db.connection()
        .execute(
            "UPDATE plans SET status='todo', tasks_done=0, execution_host=NULL WHERE id=?1",
            rusqlite::params![plan_id],
        )
        .map_err(|err| ApiError::internal(format!("plan reset failed: {err}")))?;
    db.connection()
        .execute(
            "UPDATE tasks SET status='pending', executor_agent=NULL, executor_host=NULL, validated_at=NULL, started_at=NULL, completed_at=NULL WHERE plan_id=?1 AND status NOT IN ('done','skipped')",
            rusqlite::params![plan_id],
        )
        .map_err(|err| ApiError::internal(format!("task reset failed: {err}")))?;
    Ok(Json(json!({"ok": true, "plan_id": plan_id, "action": "reset"})))
}

async fn handle_plan_move(
    State(state): State<ServerState>,
    Query(qs): Query<HashMap<String, String>>,
) -> Result<Json<Value>, ApiError> {
    let plan_id = qs
        .get("plan_id")
        .ok_or_else(|| ApiError::bad_request("missing plan_id"))?
        .parse::<i64>()
        .map_err(|_| ApiError::bad_request("invalid plan_id"))?;
    let target = qs
        .get("target")
        .filter(|v| !v.is_empty())
        .ok_or_else(|| ApiError::bad_request("missing target"))?
        .clone();
    let db = state.open_db()?;
    db.connection()
        .execute(
            "UPDATE plans SET execution_host=?1 WHERE id=?2",
            rusqlite::params![target, plan_id],
        )
        .map_err(|err| ApiError::internal(format!("plan move failed: {err}")))?;
    Ok(Json(json!({"ok": true, "plan_id": plan_id, "target": target})))
}
