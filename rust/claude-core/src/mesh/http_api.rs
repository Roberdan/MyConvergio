//! T2-00: Daemon HTTP/REST API server — axum-based, runs alongside TCP mesh on port+1.
//! Provides /health, /api/status, /api/peers, /api/metrics endpoints.
//! Foundation for W3-W5 endpoints (logs, traces, capabilities, budgets).

use axum::extract::State;
use axum::routing::get;
use axum::{Json, Router};
use serde_json::{json, Value};
use std::sync::Arc;

use crate::mesh::daemon::{DaemonState, now_ts};

use crate::mesh::observability::{LogBuffer, MeshMetrics};

/// Shared state for HTTP handlers
#[derive(Clone)]
pub struct HttpState {
    pub daemon: DaemonState,
    pub db_path: std::path::PathBuf,
    pub crsqlite_path: Option<String>,
    pub start_time: std::time::Instant,
    pub version: String,
    pub metrics: Arc<MeshMetrics>,
    pub logs: Arc<LogBuffer>,
}

/// Build the axum Router with all API routes
pub fn api_router() -> Router<Arc<HttpState>> {
    Router::new()
        .route("/health", get(health))
        .route("/api/status", get(status))
        .route("/api/peers", get(peers))
        .route("/api/metrics", get(daemon_metrics))
        .route("/api/sync-stats", get(sync_stats))
        .route("/api/logs", get(logs))
}

async fn health(State(state): State<Arc<HttpState>>) -> Json<Value> {
    let uptime = state.start_time.elapsed().as_secs();
    Json(json!({
        "status": "ok",
        "node": state.daemon.node_id,
        "version": state.version,
        "uptime_secs": uptime,
    }))
}

async fn status(State(state): State<Arc<HttpState>>) -> Json<Value> {
    let heartbeats = state.daemon.heartbeats.read().await;
    let now = now_ts();
    let peers: Vec<Value> = heartbeats.iter().map(|(name, ts)| {
        let age = now.saturating_sub(*ts);
        json!({ "node": name, "last_seen": ts, "age_secs": age, "online": age < 30 })
    }).collect();
    Json(json!({
        "node": state.daemon.node_id,
        "peers": peers,
        "peer_count": heartbeats.len(),
        "uptime_secs": state.start_time.elapsed().as_secs(),
    }))
}

async fn peers(State(state): State<Arc<HttpState>>) -> Json<Value> {
    let heartbeats = state.daemon.heartbeats.read().await;
    let now = now_ts();
    let list: Vec<Value> = heartbeats.iter().map(|(name, ts)| {
        json!({ "name": name, "last_seen": ts, "online": now.saturating_sub(*ts) < 30 })
    }).collect();
    Json(json!({ "peers": list }))
}

async fn daemon_metrics(State(state): State<Arc<HttpState>>) -> Json<Value> {
    let mut snapshot = state.metrics.snapshot();
    if let Some(obj) = snapshot.as_object_mut() {
        obj.insert("node".to_string(), json!(state.daemon.node_id));
        obj.insert("broadcast_receivers".to_string(), json!(state.daemon.tx.receiver_count()));
    }
    Json(snapshot)
}

async fn logs(State(state): State<Arc<HttpState>>) -> Json<Value> {
    let entries = state.logs.recent(100);
    Json(json!({ "logs": entries, "count": entries.len() }))
}

async fn sync_stats(State(state): State<Arc<HttpState>>) -> Json<Value> {
    let db = state.db_path.clone();
    let crsql = state.crsqlite_path.clone();
    // Run DB query in blocking task
    let result = tokio::task::spawn_blocking(move || {
        let conn = crate::mesh::sync::open_persistent_sync_conn(&db, crsql.as_deref()).ok()?;
        let mut stmt = conn.prepare(
            "SELECT peer_name, total_sent, total_received, total_applied, last_sync_at, last_latency_ms, last_db_version, last_error FROM mesh_sync_stats"
        ).ok()?;
        let rows: Vec<Value> = stmt.query_map([], |row| {
            Ok(json!({
                "peer": row.get::<_, String>(0)?,
                "total_sent": row.get::<_, i64>(1)?,
                "total_received": row.get::<_, i64>(2)?,
                "total_applied": row.get::<_, i64>(3)?,
                "last_sync_at": row.get::<_, Option<i64>>(4)?,
                "last_latency_ms": row.get::<_, Option<i64>>(5)?,
                "last_db_version": row.get::<_, i64>(6)?,
                "last_error": row.get::<_, Option<String>>(7)?,
            }))
        }).ok()?.flatten().collect();
        Some(rows)
    }).await.ok().flatten().unwrap_or_default();
    Json(json!({ "sync_stats": result }))
}
