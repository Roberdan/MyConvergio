#[path = "daemon_sync.rs"]
mod daemon_sync;
#[cfg(test)]
#[path = "daemon_tests.rs"]
mod daemon_tests;

use crate::mesh::sync::DeltaChange;
use crate::mesh::ws::{text_frame, websocket_accept};
use crate::mesh::net::{apply_socket_tuning, load_tailscale_peer_ips, prefer_tailscale_peer_addr};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::fs;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::io::AsyncWriteExt;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{broadcast, RwLock};

pub(super) const WS_BRAIN_ROUTE: &str = "/ws/brain";

#[derive(Debug, Clone)]
pub struct DaemonConfig {
    pub bind_ip: String,
    pub port: u16,
    pub peers_conf_path: PathBuf,
    pub db_path: PathBuf,
    pub crsqlite_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(super) struct MeshEvent {
    pub(super) kind: String,
    pub(super) node: String,
    pub(super) ts: u64,
    pub(super) payload: Value,
}

#[derive(Clone)]
pub(super) struct DaemonState {
    pub(super) node_id: String,
    pub(super) tx: broadcast::Sender<MeshEvent>,
    pub(super) heartbeats: Arc<RwLock<HashMap<String, u64>>>,
}

pub async fn run_service(config: DaemonConfig) -> Result<(), String> {
    // T1-07: Validate config before starting
    validate_config(&config)?;

    // Ensure ALL tables are CRR-enabled at daemon startup
    {
        let conn = crate::mesh::sync::open_persistent_sync_conn(&config.db_path, config.crsqlite_path.as_deref())?;
        crate::mesh::sync::ensure_sync_schema_pub(&conn).map_err(|e| e.to_string())?;
    }

    let bind_addr = format!("{}:{}", config.bind_ip, config.port);
    let listener = TcpListener::bind(&bind_addr)
        .await
        .map_err(|e| format!("mesh listen failed on {bind_addr}: {e}"))?;
    let (tx, _) = broadcast::channel(256);
    let state = DaemonState {
        node_id: bind_addr.clone(),
        tx,
        heartbeats: Arc::new(RwLock::new(HashMap::new())),
    };
    let tailscale_lookup = load_tailscale_peer_ips();
    for peer in read_peers_conf(&config.peers_conf_path)
        .into_iter()
        .map(|peer| prefer_tailscale_peer_addr(&peer, &tailscale_lookup))
        .filter(|p| p != &bind_addr)
        .collect::<HashSet<_>>()
    {
        tokio::spawn(connect_peer_loop(peer, state.clone(), config.clone()));
    }
    // Prune stale heartbeats every 60s (remove entries older than 5 minutes)
    let hb_state = state.clone();
    tokio::spawn(async move {
        let mut ticker = tokio::time::interval(Duration::from_secs(60));
        loop {
            ticker.tick().await;
            let now = now_ts();
            let mut hb = hb_state.heartbeats.write().await;
            hb.retain(|_, ts| now.saturating_sub(*ts) < 300);
        }
    });

    // T2-00: HTTP API server on port+1 (e.g. 9421)
    let mesh_metrics = Arc::new(crate::mesh::observability::MeshMetrics::new());
    let log_buffer = Arc::new(crate::mesh::observability::LogBuffer::new(1000));
    let http_state = Arc::new(super::http_api::HttpState {
        daemon: state.clone(),
        db_path: config.db_path.clone(),
        crsqlite_path: config.crsqlite_path.clone(),
        start_time: std::time::Instant::now(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        metrics: mesh_metrics,
        logs: log_buffer,
    });
    let http_addr = format!("{}:{}", config.bind_ip, config.port + 1);
    let http_router = super::http_api::api_router().with_state(http_state);
    tokio::spawn(async move {
        let listener = tokio::net::TcpListener::bind(&http_addr).await
            .unwrap_or_else(|e| panic!("HTTP API bind failed on {http_addr}: {e}"));
        axum::serve(listener, http_router).await.ok();
    });

    // T2-03: Graceful shutdown handler
    let shutdown_state = state.clone();
    tokio::spawn(async move {
        tokio::signal::ctrl_c().await.ok();
        publish_event(&shutdown_state, "shutdown", &shutdown_state.node_id, serde_json::json!({}));
        // Give broadcast subscribers time to receive shutdown event
        tokio::time::sleep(Duration::from_millis(500)).await;
        std::process::exit(0);
    });

    loop {
        let (stream, remote) = listener
            .accept()
            .await
            .map_err(|e| format!("mesh accept failed: {e}"))?;
        let _ = apply_socket_tuning(&stream);
        let cfg = config.clone();
        let st = state.clone();
        tokio::spawn(async move {
            let conn_id = format!("inbound-{remote}");
            let _ = daemon_sync::handle_socket(stream, conn_id, st, cfg, false).await;
        });
    }
}

/// T1-07: Validate daemon config — fail fast with clear errors
fn validate_config(config: &DaemonConfig) -> Result<(), String> {
    // bind_ip must be a Tailscale IP (100.x.x.x) or localhost for security
    if !config.bind_ip.starts_with("100.") && config.bind_ip != "127.0.0.1" && config.bind_ip != "::1" {
        return Err(format!(
            "SECURITY: bind_ip '{}' is not a Tailscale IP (100.x.x.x) or localhost. \
             Binding to 0.0.0.0 would expose the mesh daemon to untrusted networks.",
            config.bind_ip
        ));
    }
    // DB path must exist
    if !config.db_path.exists() {
        return Err(format!("DB path does not exist: {:?}", config.db_path));
    }
    // crsqlite extension must exist if specified
    if let Some(ref ext) = config.crsqlite_path {
        let ext_path = std::path::Path::new(ext);
        // Check with platform extensions (.dylib, .so)
        let exists = ext_path.exists()
            || ext_path.with_extension("dylib").exists()
            || ext_path.with_extension("so").exists();
        if !exists {
            return Err(format!("crsqlite extension not found: {ext}"));
        }
    }
    // peers.conf must exist and be readable
    if !config.peers_conf_path.exists() {
        return Err(format!("peers.conf not found: {:?}", config.peers_conf_path));
    }
    Ok(())
}

pub fn detect_tailscale_ip() -> Option<String> {
    const CANDIDATES: &[&str] = &[
        "tailscale",
        "/usr/local/bin/tailscale",
        "/opt/homebrew/bin/tailscale",
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
    ];
    for cmd in CANDIDATES {
        if let Ok(output) = std::process::Command::new(cmd).arg("ip").arg("-4").output() {
            if output.status.success() {
                return String::from_utf8(output.stdout)
                    .ok()?
                    .lines()
                    .next()
                    .map(|line| line.trim().to_string());
            }
        }
    }
    None
}

pub(super) fn parse_peers_conf(content: &str) -> Vec<String> {
    // Parse INI-style peers.conf: extract tailscale_ip from each [peer] section
    // and return as "ip:9420" entries for daemon TCP connections.
    let mut peers = Vec::new();
    let mut current_ip: Option<String> = None;
    for line in content.lines().map(str::trim) {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if line.starts_with('[') && line.ends_with(']') {
            if let Some(ip) = current_ip.take() {
                peers.push(format!("{ip}:9420"));
            }
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            if key.trim() == "tailscale_ip" {
                current_ip = Some(value.trim().to_string());
            }
        }
    }
    if let Some(ip) = current_ip {
        peers.push(format!("{ip}:9420"));
    }
    peers
}

pub(super) fn is_ws_brain_request(request_head: &str) -> bool {
    request_head.starts_with("GET ") && request_head.contains(WS_BRAIN_ROUTE)
}

pub(super) fn websocket_key(request: &str) -> Option<String> {
    request.lines().find_map(|line| {
        let (name, value) = line.split_once(':')?;
        if name.eq_ignore_ascii_case("sec-websocket-key") {
            Some(value.trim().to_string())
        } else {
            None
        }
    })
}

pub(super) fn publish_event(state: &DaemonState, kind: &str, node: &str, payload: Value) {
    let _ = state.tx.send(MeshEvent {
        kind: kind.to_string(),
        node: node.to_string(),
        ts: now_ts(),
        payload,
    });
}

pub(super) fn relay_agent_activity_changes(state: &DaemonState, node: &str, changes: &[DeltaChange]) {
    let mut grouped: BTreeMap<Vec<u8>, HashMap<String, String>> = BTreeMap::new();
    for change in changes {
        if change.table_name != "agent_activity" {
            continue;
        }
        if let Some(value) = &change.val {
            grouped
                .entry(change.pk.clone())
                .or_default()
                .insert(change.cid.clone(), value.clone());
        }
    }
    for (pk, fields) in grouped {
        let pk_str = String::from_utf8_lossy(&pk).to_string();
        let status = fields.get("status").map_or("running", String::as_str);
        let event_type = match status {
            "running" => "start",
            "completed" | "failed" | "cancelled" => "complete",
            _ => "heartbeat",
        };
        let payload = json!({
            "event_type": event_type,
            "record_key": pk_str,
            "agent_id": fields.get("agent_id").cloned().unwrap_or_default(),
            "status": status,
            "task_db_id": fields.get("task_db_id").cloned(),
            "plan_id": fields.get("plan_id").cloned(),
            "agent_type": fields.get("agent_type").cloned(),
            "model": fields.get("model").cloned(),
            "description": fields.get("description").cloned(),
            "host": fields.get("host").cloned(),
            "region": fields.get("region").cloned(),
            "tokens_in": parse_i64(fields.get("tokens_in")),
            "tokens_out": parse_i64(fields.get("tokens_out")),
            "tokens_total": parse_i64(fields.get("tokens_total")),
        });
        publish_event(state, "agent_heartbeat", node, payload);
    }
}

fn parse_i64(value: Option<&String>) -> Option<i64> {
    value.and_then(|v| v.parse::<i64>().ok())
}

pub fn now_ts() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

pub(super) async fn handle_ws_client(
    mut stream: TcpStream,
    request: &str,
    state: DaemonState,
) -> Result<(), String> {
    let key = websocket_key(request).ok_or_else(|| "missing websocket key".to_string())?;
    let accept = websocket_accept(&key);
    let response = format!(
        "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n\r\n"
    );
    stream
        .write_all(response.as_bytes())
        .await
        .map_err(|e| e.to_string())?;
    let mut sub = state.tx.subscribe();
    let snapshot = {
        let heartbeats = state.heartbeats.read().await;
        json!({"kind":"heartbeat_snapshot","node":state.node_id,"ts":now_ts(),"payload":{"nodes":*heartbeats}})
    };
    stream
        .write_all(&text_frame(&snapshot.to_string()))
        .await
        .map_err(|e| e.to_string())?;
    while let Ok(event) = sub.recv().await {
        let payload = serde_json::to_string(&event).map_err(|e| e.to_string())?;
        if stream.write_all(&text_frame(&payload)).await.is_err() {
            break;
        }
    }
    Ok(())
}

fn read_peers_conf(path: &PathBuf) -> Vec<String> {
    fs::read_to_string(path)
        .ok()
        .map(|v| parse_peers_conf(&v))
        .unwrap_or_default()
}

async fn connect_peer_loop(peer: String, state: DaemonState, config: DaemonConfig) {
    let mut backoff_secs = 3u64;
    loop {
        match TcpStream::connect(&peer).await {
            Ok(stream) => {
                backoff_secs = 3; // reset on success
                let _ = apply_socket_tuning(&stream);
                let _ = daemon_sync::handle_socket(stream, format!("peer-{peer}"), state.clone(), config.clone(), true).await;
            }
            Err(_) => {
                tokio::time::sleep(Duration::from_secs(backoff_secs)).await;
                backoff_secs = (backoff_secs * 2).min(60); // exponential backoff, max 60s
            }
        }
    }
}
