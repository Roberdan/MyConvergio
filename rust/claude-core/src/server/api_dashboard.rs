use super::state::{query_one, query_rows, ApiError, ServerState};
use axum::extract::{Path, State};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::Deserialize;
use serde_json::{json, Value};

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/overview", get(api_overview))
        .route("/api/mission", get(api_mission))
        .route("/api/organization", get(api_organization))
        .route("/api/live-system", get(api_live_system))
        .route("/api/tokens/daily", get(api_tokens_daily))
        .route("/api/tokens/models", get(api_tokens_models))
        .route("/api/history", get(api_history))
        .route("/api/tasks/distribution", get(api_tasks_distribution))
        .route("/api/tasks/blocked", get(api_tasks_blocked))
        .route("/api/plans/assignable", get(api_plans_assignable))
        .route("/api/notifications", get(api_notifications))
        .route("/api/nightly/jobs", get(api_nightly_jobs))
        .route("/api/nightly/jobs/create", post(api_nightly_job_create))
        .route("/api/projects", get(api_projects))
        .route("/api/events", get(api_events))
        .route("/api/coordinator/status", get(api_coordinator_status))
        .route("/api/coordinator/toggle", get(api_coordinator_toggle))
        .route("/api/plan/:plan_id", get(api_plan_detail))
        .route("/api/plan-status", post(api_plan_status))
}

async fn api_overview(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let row = query_one(
        db.connection(),
        "SELECT \
          (SELECT COUNT(*) FROM plans) AS plans_total,\
          (SELECT COUNT(*) FROM plans WHERE status IN ('todo','doing')) AS plans_active,\
          (SELECT COUNT(*) FROM plans WHERE status='done') AS plans_done,\
          (SELECT COUNT(*) FROM tasks WHERE status='in_progress') AS agents_running,\
          (SELECT COUNT(*) FROM tasks WHERE status='blocked') AS blocked,\
          COALESCE((SELECT SUM(input_tokens + output_tokens) FROM token_usage),0) AS total_tokens,\
          COALESCE((SELECT SUM(cost_usd) FROM token_usage),0) AS total_cost,\
          COALESCE((SELECT SUM(input_tokens + output_tokens) FROM token_usage WHERE date(created_at)=date('now')),0) AS today_tokens,\
          COALESCE((SELECT SUM(cost_usd) FROM token_usage WHERE date(created_at)=date('now')),0) AS today_cost,\
          (SELECT COUNT(*) FROM peer_heartbeats) AS mesh_total,\
          (SELECT COUNT(*) FROM peer_heartbeats WHERE (strftime('%s','now') - COALESCE(last_seen,0)) < 300) AS mesh_online",
        [],
    )?
    .unwrap_or_else(|| json!({}));
    Ok(Json(row))
}

async fn api_mission(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let plans = query_rows(
        db.connection(),
        "SELECT id,name,status,tasks_done,tasks_total,project_id,execution_host,human_summary FROM plans WHERE status IN ('todo','doing') ORDER BY id DESC",
        [],
    )?;
    let mut result = Vec::new();
    for plan in plans {
        let plan_id = plan.get("id").and_then(Value::as_i64).unwrap_or(0);
        let waves = query_rows(
            db.connection(),
            "SELECT wave_id,name,status,tasks_done,tasks_total,position,validated_at FROM waves WHERE plan_id=?1 ORDER BY position",
            rusqlite::params![plan_id],
        ).unwrap_or_default();
        let tasks = query_rows(
            db.connection(),
            "SELECT task_id,title,status,executor_agent,executor_host,tokens,validated_at,model,wave_id FROM tasks WHERE plan_id=?1 ORDER BY id",
            rusqlite::params![plan_id],
        ).unwrap_or_default();
        result.push(json!({"plan": plan, "waves": waves, "tasks": tasks}));
    }
    Ok(Json(json!({"plans": result})))
}

async fn api_organization(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let plans = query_rows(db.connection(), "SELECT id,name,status FROM plans ORDER BY id DESC LIMIT 10", [])?;
    let peers = query_rows(db.connection(), "SELECT peer_name,last_seen FROM peer_heartbeats", [])?;
    Ok(Json(json!({"plans": plans, "peers": peers})))
}

async fn api_live_system(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let runs = query_rows(
        db.connection(),
        "SELECT id,plan_id,wave_id,task_id,agent_name,agent_role,model,peer_name,status,started_at,last_heartbeat,current_task FROM agent_runs ORDER BY COALESCE(last_heartbeat, started_at) DESC LIMIT 80",
        [],
    )
    .unwrap_or_default();
    Ok(Json(json!({"agent_runs": runs})))
}

async fn api_tokens_daily(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT date(created_at) AS day, SUM(input_tokens) AS input, SUM(output_tokens) AS output, SUM(cost_usd) AS cost FROM token_usage GROUP BY day ORDER BY day",
        [],
    )?)))
}

async fn api_tokens_models(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT model, SUM(input_tokens + output_tokens) AS tokens, SUM(cost_usd) AS cost FROM token_usage WHERE model IS NOT NULL GROUP BY model ORDER BY tokens DESC LIMIT 8",
        [],
    )?)))
}

async fn api_history(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT id,name,status,tasks_done,tasks_total,project_id,started_at,completed_at,human_summary,lines_added,lines_removed FROM plans WHERE status IN ('done','cancelled') ORDER BY id DESC LIMIT 20",
        [],
    )?)))
}

async fn api_plan_detail(
    State(state): State<ServerState>,
    Path(plan_id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let tree = db
        .execution_tree(plan_id)
        .map_err(|err| ApiError::bad_request(format!("invalid plan id {plan_id}: {err}")))?;
    Ok(Json(json!(tree)))
}

async fn api_tasks_distribution(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT status, COUNT(*) AS count FROM tasks GROUP BY status ORDER BY count DESC",
        [],
    )?)))
}

async fn api_tasks_blocked(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT task_id,title,status,plan_id FROM tasks WHERE status='blocked'",
        [],
    )?)))
}

async fn api_plans_assignable(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT id,name,status,tasks_done,tasks_total,execution_host,human_summary FROM plans WHERE status IN ('todo','doing') ORDER BY id",
        [],
    )?)))
}

async fn api_notifications(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT id,type,title,message,link,link_type,is_read,created_at FROM notifications WHERE is_read=0 ORDER BY created_at DESC LIMIT 20",
        [],
    )?)))
}

async fn api_projects(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT id,name,path FROM projects ORDER BY name COLLATE NOCASE",
        [],
    )?)))
}

async fn api_nightly_jobs(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let rows = query_rows(
        db.connection(),
        "SELECT id,run_id,job_name,started_at,finished_at,host,status,sentry_unresolved,github_open_issues,processed_items,fixed_items,branch_name,pr_url,summary,report_json FROM nightly_jobs ORDER BY started_at DESC LIMIT 10",
        [],
    )?;
    let definitions = query_rows(
        db.connection(),
        "SELECT id,name,description,schedule,script_path,target_host,enabled,created_at FROM nightly_job_definitions ORDER BY name",
        [],
    ).unwrap_or_default();
    let latest = rows.first().cloned();
    Ok(Json(json!({"ok": true, "latest": latest, "history": rows, "definitions": definitions})))
}

#[derive(Deserialize)]
struct NightlyJobCreatePayload {
    name: String,
    script_path: String,
    #[serde(default = "default_schedule")]
    schedule: String,
    #[serde(default)]
    description: String,
    #[serde(default = "default_host")]
    target_host: String,
}
fn default_schedule() -> String { "0 3 * * *".to_string() }
fn default_host() -> String { "local".to_string() }

async fn api_nightly_job_create(
    State(state): State<ServerState>,
    axum::Json(payload): axum::Json<NightlyJobCreatePayload>,
) -> Result<Json<Value>, ApiError> {
    let name = payload.name.trim().to_string();
    let script = payload.script_path.trim().to_string();
    if name.is_empty() || script.is_empty() {
        return Err(ApiError::bad_request("name and script_path are required"));
    }
    let db = state.open_db()?;
    db.connection()
        .execute(
            "INSERT INTO nightly_job_definitions (name,description,schedule,script_path,target_host) VALUES (?1,?2,?3,?4,?5)",
            rusqlite::params![name, payload.description, payload.schedule, script, payload.target_host],
        )
        .map_err(|err| ApiError::internal(format!("create job failed: {err}")))?;
    Ok(Json(json!({"ok": true, "name": name})))
}

async fn api_events(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT id,event_type,plan_id,source_peer,payload,status,created_at FROM mesh_events ORDER BY created_at DESC LIMIT 50",
        [],
    )?)))
}

async fn api_coordinator_status(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let pending = query_one(
        db.connection(),
        "SELECT COUNT(*) AS pending_events FROM mesh_events WHERE status='pending'",
        [],
    )?
    .unwrap_or_else(|| json!({"pending_events": 0}));
    Ok(Json(json!({"running": false, "pid": "", "pending_events": pending["pending_events"]})))
}

async fn api_coordinator_toggle() -> Json<Value> {
    Json(json!({"ok": true, "action": "noop"}))
}

#[derive(Deserialize)]
struct PlanStatusPayload {
    plan_id: i64,
    status: String,
}

async fn api_plan_status(
    State(state): State<ServerState>,
    axum::Json(payload): axum::Json<PlanStatusPayload>,
) -> Result<Json<Value>, ApiError> {
    if !matches!(payload.status.as_str(), "todo" | "doing" | "done") {
        return Err(ApiError::bad_request("Invalid status"));
    }
    let db = state.open_db()?;
    db.connection()
        .execute(
            "UPDATE plans SET status=?1 WHERE id=?2",
            rusqlite::params![payload.status, payload.plan_id],
        )
        .map_err(|err| ApiError::internal(format!("status update failed: {err}")))?;
    Ok(Json(json!({"ok": true, "plan_id": payload.plan_id, "status": payload.status})))
}
