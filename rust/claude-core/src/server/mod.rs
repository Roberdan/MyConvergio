pub mod api_agents;
pub mod api_chat;
pub mod api_dashboard;
pub mod api_github;
pub mod api_mesh;
pub mod api_peers;
pub mod api_plans;
pub mod middleware;
pub mod routes;
pub mod state;
pub mod sse;
pub mod ws;

#[cfg(test)]
mod api_tests;

use axum::Router;
use std::path::{Path, PathBuf};

pub const DASHBOARD_STATIC_DIR: &str = "scripts/dashboard_web";

pub fn app(static_dir: impl Into<PathBuf>) -> Router {
    routes::build_router(static_dir.into())
}

pub fn resolve_dashboard_static_dir(repo_root: impl AsRef<Path>) -> PathBuf {
    repo_root.as_ref().join(DASHBOARD_STATIC_DIR)
}

pub async fn run(bind_addr: &str, static_dir: impl Into<PathBuf>) -> Result<(), String> {
    let listener = tokio::net::TcpListener::bind(bind_addr)
        .await
        .map_err(|e| format!("server listen failed on {bind_addr}: {e}"))?;
    axum::serve(listener, app(static_dir).into_make_service())
        .await
        .map_err(|e| format!("server runtime failed: {e}"))
}
