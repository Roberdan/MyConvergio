use super::api_agents;
use super::api_ideas;
use super::api_chat;
use super::api_dashboard;
use super::api_github;
use super::api_mesh;
use super::api_peers;
use super::api_plans;
use super::middleware;
use super::sse;
use super::state::ServerState;
use super::ws;
use axum::extract::State;
use axum::routing::{get, get_service};
use axum::{Json, Router};
use std::env;
use std::path::PathBuf;
use tower_http::services::ServeDir;

pub const GET_ROUTES: &[&str] = &[
    "/api/ideas",
    "/api/ideas/:id",
    "/api/ideas/:id/notes",
    "/api/overview",
    "/api/mission",
    "/api/organization",
    "/api/live-system",
    "/api/tokens/daily",
    "/api/tokens/models",
    "/api/mesh",
    "/api/mesh/sync-status",
    "/api/history",
    "/api/tasks/distribution",
    "/api/tasks/blocked",
    "/api/plans/assignable",
    "/api/notifications",
    "/api/nightly/jobs",
    "/api/nightly/config/:project_id",
    "/api/nightly/jobs/:id",
    "/api/projects",
    "/api/events",
    "/api/coordinator/status",
    "/api/coordinator/toggle",
    "/api/health",
    "/api/peers",
    "/api/peers/discover",
    "/api/agents",
    "/api/sessions",
    "/api/chat/models",
    "/api/chat/sessions",
];
pub const POST_ROUTES: &[&str] = &[
    "/api/ideas",
    "/api/ideas/:id/notes",
    "/api/ideas/:id/promote",
    "/api/chat/session",
    "/api/chat/message",
    "/api/chat/approve",
    "/api/chat/execute",
    "/api/github/repo/create",
    "/api/mesh/init",
    "/api/nightly/jobs/create",
    "/api/nightly/jobs/trigger",
    "/api/nightly/jobs/definitions/:id/toggle",
    "/api/nightly/jobs/:id/retry",
    "/api/plan-status",
    "/api/peers",
    "/api/peers/ssh-check",
    "/api/plans/:plan_id/validate",
];
pub const PUT_ROUTES: &[&str] = &[
    "/api/ideas/:id",
    "/api/chat/requirement",
    "/api/peers/:name",
    "/api/nightly/config/:project_id",
];
pub const DELETE_ROUTES: &[&str] = &["/api/ideas/:id", "/api/chat/session", "/api/peers/:name"];
pub const SSE_ROUTES: &[&str] = &[
    "/api/chat/stream/:sid",
    "/api/mesh/action/stream",
    "/api/mesh/fullsync",
    "/api/plan/preflight",
    "/api/plan/delegate",
    "/api/plan/start",
    "/api/mesh/pull-db",
];
pub const WS_ROUTES: &[&str] = &["/ws/brain", "/ws/dashboard"];

pub fn build_router(static_dir: PathBuf) -> Router {
    let db_path = env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."))
        .join(".claude/data/dashboard.db");
    build_router_with_db(static_dir, db_path)
}

pub fn build_router_with_db(static_dir: PathBuf, db_path: PathBuf) -> Router {
    let static_files = ServeDir::new(static_dir).append_index_html_on_directories(true);
    let state = ServerState::new(db_path);

    Router::new()
        .merge(api_dashboard::router())
        .merge(api_ideas::router())
        .merge(api_plans::router())
        .merge(api_agents::router())
        .merge(api_mesh::router())
        .merge(api_peers::router())
        .merge(api_chat::router())
        .merge(api_github::router())
        .route("/api/chat/stream/:sid", get(sse::chat_stream_sse))
        .route("/api/mesh/action/stream", get(sse::mesh_action_sse))
        .route("/api/mesh/fullsync", get(sse::mesh_action_sse))
        .route("/api/plan/preflight", get(sse::plan_preflight_sse))
        .route("/api/plan/delegate", get(sse::plan_delegate_sse))
        .route("/api/plan/start", get(sse::plan_start_sse))
        .route("/api/mesh/pull-db", get(sse::mesh_action_sse))
        .route("/ws/brain", get(ws::ws_brain))
        .route("/ws/dashboard", get(ws::ws_dashboard))
        .route("/api/health", get(api_health))
        .layer(middleware::cors_layer())
        .layer(tower_http::trace::TraceLayer::new_for_http())
        .with_state(state)
        .fallback_service(get_service(static_files))
}

async fn api_health(State(state): State<ServerState>) -> Json<serde_json::Value> {
    let db_ok = state.open_db().is_ok();
    let table_count = state.open_db().ok().and_then(|db| {
        super::state::query_one(
            db.connection(),
            "SELECT COUNT(*) AS c FROM sqlite_master WHERE type='table'",
            [],
        ).ok().flatten().and_then(|v| v.get("c").and_then(serde_json::Value::as_i64))
    }).unwrap_or(0);
    let agent_activity_ok = state.open_db().ok().map(|db| {
        db.connection().prepare("SELECT 1 FROM agent_activity LIMIT 0").is_ok()
    }).unwrap_or(false);
    let peer_count = state.open_db().ok().and_then(|db| {
        super::state::query_one(db.connection(), "SELECT COUNT(*) AS c FROM peer_heartbeats", [])
            .ok().flatten().and_then(|v| v.get("c").and_then(serde_json::Value::as_i64))
    }).unwrap_or(0);
    Json(serde_json::json!({
        "ok": db_ok && agent_activity_ok,
        "db": db_ok,
        "tables": table_count,
        "agent_activity": agent_activity_ok,
        "peers": peer_count,
        "version": env!("CARGO_PKG_VERSION"),
    }))
}

#[cfg(test)]
mod tests {
    use super::{GET_ROUTES, POST_ROUTES, SSE_ROUTES, WS_ROUTES};

    #[test]
    fn includes_http_ws_and_sse_routes() {
        assert!(POST_ROUTES.contains(&"/api/mesh/init"));
        assert!(SSE_ROUTES.contains(&"/api/chat/stream/:sid"));
        assert!(WS_ROUTES.contains(&"/ws/brain"));
        assert!(WS_ROUTES.contains(&"/ws/dashboard"));
    }

    #[test]
    fn includes_ported_get_routes() {
        assert!(GET_ROUTES.contains(&"/api/overview"));
        assert!(GET_ROUTES.contains(&"/api/chat/sessions"));
        assert!(GET_ROUTES.contains(&"/api/projects"));
        assert!(GET_ROUTES.contains(&"/api/nightly/jobs/:id"));
        assert!(GET_ROUTES.contains(&"/api/nightly/config/:project_id"));
        assert!(POST_ROUTES.contains(&"/api/nightly/jobs/trigger"));
        assert!(POST_ROUTES.contains(&"/api/nightly/jobs/:id/retry"));
        assert!(POST_ROUTES.contains(&"/api/nightly/jobs/definitions/:id/toggle"));
    }
}
