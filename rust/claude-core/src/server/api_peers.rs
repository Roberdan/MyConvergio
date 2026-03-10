use super::state::{query_rows, ApiError, ServerState};
use axum::extract::{Path, State};
use axum::routing::{get, post, put};
use axum::{Json, Router};
use serde::Deserialize;
use serde_json::{json, Value};

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/peers", get(api_peer_list).post(api_peer_create))
        .route("/api/peers/discover", get(api_peer_discover))
        .route("/api/peers/ssh-check", post(api_peer_ssh_check))
        .route("/api/peers/:name", put(api_peer_update).delete(api_peer_delete))
}

async fn api_peer_list(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let rows = query_rows(
        db.connection(),
        "SELECT peer_name, last_seen, load_json, capabilities FROM peer_heartbeats",
        [],
    )?;
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(0.0);
    let peers: Vec<Value> = rows.into_iter().map(|mut row| {
        let name = row.get("peer_name").and_then(Value::as_str).unwrap_or("").to_owned();
        let seen = row.get("last_seen").and_then(Value::as_f64).unwrap_or(0.0);
        let obj = row.as_object_mut().unwrap();
        obj.insert("is_online".to_string(), json!(now - seen < 3600.0));
        obj.insert("is_local".to_string(), json!(name.contains("m3max") || name.contains("local")));
        let role = if name.contains("m3max") || name.contains("local") { "coordinator" } else { "worker" };
        obj.insert("role".to_string(), json!(role));
        row
    }).collect();
    Ok(Json(json!({"peers": peers})))
}

#[derive(Deserialize)]
struct PeerPayload {
    peer_name: Option<String>,
}

async fn api_peer_create(axum::Json(payload): axum::Json<PeerPayload>) -> Json<Value> {
    if payload.peer_name.as_deref().unwrap_or("").is_empty() {
        return Json(json!({"error": "Invalid or missing peer_name"}));
    }
    Json(json!({"ok": true, "peer": payload.peer_name}))
}

async fn api_peer_update(
    Path(name): Path<String>,
    axum::Json(_payload): axum::Json<Value>,
) -> Json<Value> {
    Json(json!({"ok": true, "peer": name}))
}

async fn api_peer_delete(Path(name): Path<String>) -> Json<Value> {
    Json(json!({"ok": true, "deleted": true, "peer": name}))
}

async fn api_peer_ssh_check(axum::Json(_payload): axum::Json<Value>) -> Json<Value> {
    Json(json!({"ok": false, "error": "SSH unreachable", "latency_ms": -1}))
}

async fn api_peer_discover() -> Json<Value> {
    Json(json!({"discovered": []}))
}
