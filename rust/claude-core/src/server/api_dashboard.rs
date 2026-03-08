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
    // Use CTEs to avoid repeated full table scans
    let row = query_one(
        db.connection(),
        "WITH plan_stats AS (
           SELECT COUNT(*) AS total,
                  SUM(CASE WHEN status IN ('todo','doing') THEN 1 ELSE 0 END) AS active,
                  SUM(CASE WHEN status='done' THEN 1 ELSE 0 END) AS done
           FROM plans
         ), task_stats AS (
           SELECT SUM(CASE WHEN status='in_progress' THEN 1 ELSE 0 END) AS running,
                  SUM(CASE WHEN status='blocked' THEN 1 ELSE 0 END) AS blocked
           FROM tasks WHERE status IN ('in_progress','blocked')
         ), token_stats AS (
           SELECT COALESCE(SUM(input_tokens + output_tokens),0) AS total_tokens,
                  COALESCE(SUM(cost_usd),0) AS total_cost,
                  COALESCE(SUM(CASE WHEN date(created_at)=date('now') THEN input_tokens + output_tokens ELSE 0 END),0) AS today_tokens,
                  COALESCE(SUM(CASE WHEN date(created_at)=date('now') THEN cost_usd ELSE 0 END),0) AS today_cost
           FROM token_usage
         ), mesh_stats AS (
           SELECT COUNT(*) AS mesh_total,
                  SUM(CASE WHEN (strftime('%s','now') - COALESCE(last_seen,0)) < 300 THEN 1 ELSE 0 END) AS mesh_online
           FROM peer_heartbeats
         )
         SELECT p.total AS plans_total, p.active AS plans_active, p.done AS plans_done,
                COALESCE(t.running,0) AS agents_running, COALESCE(t.blocked,0) AS blocked,
                tk.total_tokens, tk.total_cost, tk.today_tokens, tk.today_cost,
                m.mesh_total, m.mesh_online
         FROM plan_stats p, task_stats t, token_stats tk, mesh_stats m",
        [],
    )?
    .unwrap_or_else(|| json!({}));
    Ok(Json(row))
}

async fn api_mission(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let plans = query_rows(
        db.connection(),
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.project_id,p.execution_host,p.human_summary,pr.name AS project_name FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.status IN ('todo','doing') UNION ALL SELECT * FROM (SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.project_id,p.execution_host,p.human_summary,pr.name AS project_name FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.status='cancelled' ORDER BY p.id DESC LIMIT 10)",
        [],
    )?;
    let mut result = Vec::new();
    for plan in plans {
        let plan_id = plan.get("id").and_then(Value::as_i64).unwrap_or(0);
        let waves = query_rows(
            db.connection(),
            "SELECT wave_id,name,status,tasks_done,tasks_total,position FROM waves WHERE plan_id=?1 ORDER BY position",
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
    let peers = query_rows(
        db.connection(),
        "SELECT peer_name, last_seen, load_json, capabilities FROM peer_heartbeats",
        [],
    )?;
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(0.0);
    let agents = query_rows(
        db.connection(),
        "SELECT id,agent_id,agent_type,model,status,task_db_id,plan_id,description,host FROM agent_activity ORDER BY started_at DESC LIMIT 50",
        [],
    )
    .unwrap_or_default();
    let mut units: Vec<Value> = Vec::new();
    let mut online_count = 0i64;
    let mut agent_pods = 0i64;
    let mut live_tasks = 0i64;
    for peer in &peers {
        let name = peer.get("peer_name").and_then(Value::as_str).unwrap_or("");
        let seen = peer.get("last_seen").and_then(Value::as_f64).unwrap_or(0.0);
        let is_online = now - seen < 300.0;
        if is_online {
            online_count += 1;
        }
        let mut mem_total: f64 = 0.0;
        let mut mem_used: f64 = 0.0;
        let mut cpu: f64 = 0.0;
        if let Some(load_str) = peer.get("load_json").and_then(Value::as_str) {
            if let Ok(load) = serde_json::from_str::<Value>(load_str) {
                mem_total = load.get("mem_total_gb").and_then(Value::as_f64).unwrap_or(0.0);
                mem_used = load.get("mem_used_gb").and_then(Value::as_f64).unwrap_or(0.0);
                cpu = load.get("cpu").and_then(Value::as_f64).unwrap_or(0.0);
            }
        }
        let node_role = if name.contains("m3max") || name.contains("local") {
            "coordinator"
        } else {
            "worker"
        };
        let node_agents: Vec<Value> = agents
            .iter()
            .filter(|a| {
                a.get("host").and_then(Value::as_str).unwrap_or("") == name
                    || (name.contains("m3max")
                        && a.get("host").and_then(Value::as_str).map_or(true, |h| h.is_empty()))
            })
            .map(|a| {
                if a.get("status").and_then(Value::as_str) == Some("running") {
                    agent_pods += 1;
                    live_tasks += 1;
                }
                json!({
                    "agent": a.get("agent_id").unwrap_or(&Value::Null),
                    "role": a.get("agent_type").unwrap_or(&Value::Null),
                    "model": a.get("model").unwrap_or(&Value::Null),
                    "task_count": 1,
                    "status": a.get("status").unwrap_or(&Value::Null)
                })
            })
            .collect();
        units.push(json!({
            "peer_name": name,
            "node_role": node_role,
            "is_online": is_online,
            "cpu": cpu,
            "mem_total_gb": mem_total,
            "mem_used_gb": mem_used,
            "capabilities": peer.get("capabilities").unwrap_or(&Value::Null),
            "agents": node_agents
        }));
    }
    Ok(Json(json!({
        "units": units,
        "summary": {
            "nodes_online": online_count,
            "nodes_total": peers.len(),
            "agent_pods": agent_pods,
            "live_tasks": live_tasks
        }
    })))
}

async fn api_live_system(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(0.0);
    let peers_raw = query_rows(
        db.connection(),
        "SELECT peer_name, last_seen, load_json, capabilities FROM peer_heartbeats",
        [],
    )?;
    let runs = query_rows(
        db.connection(),
        "SELECT id,plan_id,wave_id,task_id,agent_name,agent_role,model,peer_name,status,started_at,last_heartbeat,current_task FROM agent_runs ORDER BY COALESCE(last_heartbeat, started_at) DESC LIMIT 80",
        [],
    )
    .unwrap_or_default();
    let events = query_rows(
        db.connection(),
        "SELECT id,event_type,plan_id,source_peer,status,created_at FROM mesh_events ORDER BY created_at DESC LIMIT 20",
        [],
    )
    .unwrap_or_default();
    let mut online_peers = 0i64;
    let mut peer_nodes: Vec<Value> = Vec::new();
    for peer in &peers_raw {
        let name = peer.get("peer_name").and_then(Value::as_str).unwrap_or("");
        let seen = peer.get("last_seen").and_then(Value::as_f64).unwrap_or(0.0);
        let is_online = now - seen < 300.0;
        if is_online {
            online_peers += 1;
        }
        let mut cpu: f64 = 0.0;
        if let Some(load_str) = peer.get("load_json").and_then(Value::as_str) {
            if let Ok(load) = serde_json::from_str::<Value>(load_str) {
                cpu = load.get("cpu").and_then(Value::as_f64).unwrap_or(0.0);
            }
        }
        let active = runs
            .iter()
            .filter(|r| {
                r.get("peer_name").and_then(Value::as_str).unwrap_or("") == name
                    && r.get("status").and_then(Value::as_str) == Some("running")
            })
            .count();
        let role = if name.contains("m3max") || name.contains("local") {
            "coordinator"
        } else {
            "worker"
        };
        peer_nodes.push(json!({
            "peer_name": name,
            "is_online": is_online,
            "role": role,
            "active_runs": active,
            "cpu": cpu,
            "capabilities": peer.get("capabilities").unwrap_or(&Value::Null)
        }));
    }
    let active_runs = runs
        .iter()
        .filter(|r| r.get("status").and_then(Value::as_str) == Some("running"))
        .count();
    let open_handoffs = events
        .iter()
        .filter(|e| e.get("status").and_then(Value::as_str) == Some("pending"))
        .count();
    Ok(Json(json!({
        "peer_nodes": peer_nodes,
        "run_nodes": runs,
        "summary": {
            "online_peers": online_peers,
            "peer_nodes": peers_raw.len(),
            "active_runs": active_runs,
            "open_handoffs": open_handoffs,
            "recent_events": events.len()
        },
        "synapses": [],
        "recent_events": events
    })))
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
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.project_id,p.started_at,p.completed_at,p.human_summary,p.lines_added,p.lines_removed,pr.name AS project_name FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.status IN ('done','cancelled') ORDER BY p.id DESC LIMIT 20",
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
    // Try with job_name first; fall back without it for pre-migration DBs
    let rows = query_rows(
        db.connection(),
        "SELECT id,run_id,job_name,started_at,finished_at,host,status,sentry_unresolved,github_open_issues,processed_items,fixed_items,branch_name,pr_url,summary,report_json FROM nightly_jobs ORDER BY started_at DESC LIMIT 10",
        [],
    )
    .or_else(|_| {
        query_rows(
            db.connection(),
            "SELECT id,run_id,'guardian' AS job_name,started_at,finished_at,host,status,sentry_unresolved,github_open_issues,processed_items,fixed_items,branch_name,pr_url,summary,report_json FROM nightly_jobs ORDER BY started_at DESC LIMIT 10",
            [],
        )
    })?;
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
    if !matches!(payload.status.as_str(), "todo" | "doing" | "done" | "cancelled") {
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
