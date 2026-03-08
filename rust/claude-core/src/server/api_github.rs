use super::state::{query_rows, ApiError, ServerState};
use axum::extract::{Path, State};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/github/commits/:plan_id", get(handle_github_commits))
        .route("/api/github/events/:project_id", get(handle_github_events))
        .route("/api/github/stats/:plan_id", get(handle_github_stats))
        .route("/api/github/repo/create", post(handle_github_repo_create))
}

async fn handle_github_commits(
    State(state): State<ServerState>,
    Path(plan_id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let local_commits = query_rows(
        db.connection(),
        "SELECT commit_sha, commit_message, lines_added, lines_removed, files_changed, authored_at, created_at FROM plan_commits WHERE plan_id=?1 ORDER BY COALESCE(authored_at, created_at) DESC LIMIT 50",
        rusqlite::params![plan_id],
    )?;
    Ok(Json(json!({
        "ok": true,
        "plan_id": plan_id,
        "repo": "local/repo",
        "local_commits": local_commits,
        "remote_commits": []
    })))
}

async fn handle_github_events(
    State(state): State<ServerState>,
    Path(project_id): Path<String>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let local_events = query_rows(
        db.connection(),
        "SELECT ge.id, ge.plan_id, ge.event_type, ge.status, ge.created_at FROM github_events ge JOIN plans p ON p.id=ge.plan_id WHERE p.project_id=?1 ORDER BY ge.created_at DESC LIMIT 100",
        rusqlite::params![project_id],
    )
    .unwrap_or_default();
    Ok(Json(json!({"ok": true, "project_id": project_id, "repo": "local/repo", "local_events": local_events, "remote_events": []})))
}

async fn handle_github_stats(
    State(state): State<ServerState>,
    Path(plan_id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let plan_rows = query_rows(
        db.connection(),
        "SELECT id, name FROM plans WHERE id=?1",
        rusqlite::params![plan_id],
    )?;
    if plan_rows.is_empty() {
        return Err(ApiError::bad_request(format!("plan {plan_id} not found")));
    }
    let commit_totals = query_rows(
        db.connection(),
        "SELECT COUNT(*) AS commit_count, COALESCE(SUM(lines_added),0) AS lines_added, COALESCE(SUM(lines_removed),0) AS lines_removed, COALESCE(SUM(files_changed),0) AS files_changed FROM plan_commits WHERE plan_id=?1",
        rusqlite::params![plan_id],
    )
    .unwrap_or_default();
    let event_totals = query_rows(
        db.connection(),
        "SELECT status, COUNT(*) AS count FROM github_events WHERE plan_id=?1 GROUP BY status",
        rusqlite::params![plan_id],
    )
    .unwrap_or_default();
    Ok(Json(json!({
        "ok": true,
        "plan_id": plan_id,
        "repo": "local/repo",
        "github_issue": Value::Null,
        "commit_totals": commit_totals.first().cloned().unwrap_or_else(|| json!({})),
        "event_totals": event_totals,
        "repo_stats": {"nameWithOwner": "local/repo", "stargazerCount": 0, "forkCount": 0, "openIssues": 0}
    })))
}

async fn handle_github_repo_create(axum::Json(payload): axum::Json<Value>) -> Json<Value> {
    let name = payload.get("name").and_then(Value::as_str).unwrap_or("").trim();
    if name.is_empty() {
        return Json(json!({"ok": false, "error": "missing repository name"}));
    }
    Json(json!({"ok": true, "repo": {"nameWithOwner": name, "url": "", "isPrivate": true}, "create_output": ""}))
}
