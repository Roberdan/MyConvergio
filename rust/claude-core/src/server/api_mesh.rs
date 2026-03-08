use super::state::{query_rows, ApiError, ServerState};
use axum::extract::{Query, State};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};
use std::collections::HashMap;

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/mesh", get(api_mesh))
        .route("/api/mesh/sync-status", get(api_mesh_sync_status))
        .route("/api/mesh/init", post(api_mesh_init))
        .route("/api/mesh/action", get(handle_mesh_action))
}

async fn api_mesh(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let rows = query_rows(
        db.connection(),
        "SELECT peer_name, cpu_load AS cpu, tasks_in_progress AS active_tasks, mem_used_gb, mem_total_gb, last_seen FROM peer_heartbeats",
        [],
    )?;
    Ok(Json(Value::Array(rows)))
}

async fn api_mesh_sync_status(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let pending = query_rows(
        db.connection(),
        "SELECT status, COUNT(*) AS count FROM mesh_events GROUP BY status",
        [],
    )
    .unwrap_or_default();
    let latencies = query_rows(
        db.connection(),
        "SELECT COALESCE(last_latency_ms,0) AS latency_ms FROM mesh_sync_stats WHERE last_latency_ms IS NOT NULL",
        [],
    )
    .unwrap_or_default();
    let mut samples: Vec<i64> = latencies
        .iter()
        .filter_map(|row| row.get("latency_ms").and_then(Value::as_i64))
        .collect();
    samples.sort_unstable();
    let percentile = |p: f64| -> i64 {
        if samples.is_empty() {
            return 0;
        }
        let idx = ((samples.len() - 1) as f64 * p).round() as usize;
        samples[idx]
    };
    Ok(Json(json!({
        "ok": true,
        "events": pending,
        "latency": {
            "db_sync_p50_ms": percentile(0.50),
            "db_sync_p99_ms": percentile(0.99),
            "targets": {"lan_p50_lt_ms": 10, "wan_p99_lt_ms": 100}
        }
    })))
}

async fn api_mesh_init() -> Json<Value> {
    Json(json!({"status": "ok", "daemons_restarted": [], "hosts_needing_normalization": 0}))
}

async fn handle_mesh_action(Query(qs): Query<HashMap<String, String>>) -> Json<Value> {
    let action = qs.get("action").cloned().unwrap_or_default();
    let peer = qs.get("peer").cloned().unwrap_or_default();
    if action.is_empty() || peer.is_empty() {
        return Json(json!({"error": "missing action or peer", "output": ""}));
    }
    Json(json!({"output": format!("{action} -> {peer}"), "exit_code": 0}))
}
