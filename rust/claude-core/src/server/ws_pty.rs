//! WebSocket PTY terminal — spawns local shell or SSH to remote mesh nodes.
//! Protocol: JSON `{"type":"resize","cols":N,"rows":N}` for resize, raw text for stdin.
use super::state::ServerState;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::response::Response;
use serde::Deserialize;
use std::process::Stdio;
use std::sync::atomic::{AtomicUsize, Ordering};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::time::{Duration, Instant};

pub(crate) static ACTIVE_SESSIONS: AtomicUsize = AtomicUsize::new(0);
pub(crate) const MAX_PTY_SESSIONS: usize = 10;
const IDLE_TIMEOUT: Duration = Duration::from_secs(300);

struct SessionGuard;
impl Drop for SessionGuard {
    fn drop(&mut self) { ACTIVE_SESSIONS.fetch_sub(1, Ordering::SeqCst); }
}

#[derive(Deserialize)]
pub struct PtyParams {
    #[serde(default = "default_peer")]
    pub(crate) peer: String,
    #[serde(default)]
    pub(crate) tmux_session: String,
}
fn default_peer() -> String { "local".into() }

#[derive(Debug, Clone)]
pub(crate) struct ResolvedPeer {
    pub ip: String,
    pub user: Option<String>,
    pub is_self: bool,
}

fn read_peer_conf(peer: &str) -> Option<std::collections::HashMap<String, String>> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    let path = std::path::PathBuf::from(home).join(".claude/config/peers.conf");
    let text = std::fs::read_to_string(path).ok()?;
    let mut found = false;
    let mut map = std::collections::HashMap::new();
    for line in text.lines() {
        let line = line.trim();
        if line.starts_with('#') || line.is_empty() { continue; }
        if line.starts_with('[') && line.ends_with(']') {
            if found { break; }
            found = &line[1..line.len()-1] == peer;
            continue;
        }
        if found {
            if let Some((k, v)) = line.split_once('=') {
                map.insert(k.trim().to_string(), v.trim().to_string());
            }
        }
    }
    if found { Some(map) } else { None }
}

pub(crate) fn tailscale_resolve(peer: &str) -> Option<(String, bool, bool)> {
    let output = std::process::Command::new("tailscale")
        .args(["status", "--json"]).output().ok()?;
    if !output.status.success() { return None; }
    let json: serde_json::Value = serde_json::from_slice(&output.stdout).ok()?;
    let conf = read_peer_conf(peer);
    let conf_ip = conf.as_ref().and_then(|c| c.get("tailscale_ip").cloned());
    let conf_dns = conf.as_ref().and_then(|c| c.get("dns_name").cloned());
    if let Some(self_node) = json.get("Self") {
        if ts_node_matches(self_node, conf_ip.as_deref(), conf_dns.as_deref(), peer) {
            return Some((ts_first_ip(self_node)?, true, true));
        }
    }
    if let Some(peers) = json.get("Peer").and_then(|p| p.as_object()) {
        for (_key, node) in peers {
            if ts_node_matches(node, conf_ip.as_deref(), conf_dns.as_deref(), peer) {
                let ip = ts_first_ip(node)?;
                let online = node.get("Online").and_then(|v| v.as_bool()).unwrap_or(false);
                return Some((ip, online, false));
            }
        }
    }
    None
}

fn ts_node_matches(
    node: &serde_json::Value, conf_ip: Option<&str>, conf_dns: Option<&str>, peer: &str,
) -> bool {
    if let Some(ip) = conf_ip {
        if let Some(ips) = node.get("TailscaleIPs").and_then(|v| v.as_array()) {
            if ips.iter().any(|v| v.as_str() == Some(ip)) { return true; }
        }
    }
    if let Some(dns) = conf_dns {
        if let Some(node_dns) = node.get("DNSName").and_then(|v| v.as_str()) {
            let (a, b) = (dns.trim_end_matches('.'), node_dns.trim_end_matches('.'));
            if a.eq_ignore_ascii_case(b) { return true; }
        }
    }
    ts_name_matches(node, &peer.to_lowercase().replace(['-', '_', ' ', '\''], ""))
}

pub(crate) fn ts_name_matches(node: &serde_json::Value, normalized_peer: &str) -> bool {
    for field in ["HostName", "DNSName"] {
        if let Some(val) = node.get(field).and_then(|v| v.as_str()) {
            let norm = val.to_lowercase().replace(['-', '_', ' ', '\'', '.'], "");
            if norm.contains(normalized_peer) || normalized_peer.contains(
                norm.split("tail").next().unwrap_or("").trim_end_matches('.'),
            ) { return true; }
        }
    }
    false
}

pub(crate) fn ts_first_ip(node: &serde_json::Value) -> Option<String> {
    node.get("TailscaleIPs").and_then(|v| v.as_array())
        .and_then(|a| a.first()).and_then(|v| v.as_str()).map(|s| s.to_string())
}

pub(crate) fn peer_ssh_user(peer: &str) -> Option<String> {
    read_peer_conf(peer).and_then(|m| m.get("user").cloned())
}

pub(crate) fn resolve_peer(_state: &ServerState, peer: &str) -> Option<ResolvedPeer> {
    let (ip, _online, is_self) = tailscale_resolve(peer)?;
    Some(ResolvedPeer { ip, user: peer_ssh_user(peer), is_self })
}

pub(crate) fn peer_ssh_alias(state: &ServerState, peer: &str) -> Option<String> {
    let resolved = resolve_peer(state, peer)?;
    if resolved.is_self { return None; }
    match resolved.user {
        Some(u) => Some(format!("{u}@{}", resolved.ip)),
        None => Some(resolved.ip),
    }
}

pub(crate) fn is_local_peer(state: &ServerState, peer: &str) -> bool {
    if peer == "local" || peer == "localhost" { return true; }
    matches!(resolve_peer(state, peer), Some(r) if r.is_self)
}

pub async fn ws_pty(
    ws: WebSocketUpgrade, Query(params): Query<PtyParams>, State(state): State<ServerState>,
) -> Response {
    ws.on_upgrade(move |socket| handle_pty(socket, params, state))
}

fn build_pty_command(
    state: &ServerState, params: &PtyParams, is_local: bool,
) -> (String, Vec<String>) {
    if is_local {
        if params.tmux_session.is_empty() {
            let sh = std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".into());
            (sh, vec!["-l".into()])
        } else {
            ("tmux".into(), vec![
                "new-session".into(), "-A".into(), "-s".into(), params.tmux_session.clone(),
            ])
        }
    } else {
        let host = peer_ssh_alias(state, &params.peer)
            .unwrap_or_else(|| params.peer.clone());
        if params.tmux_session.is_empty() {
            ("ssh".into(), vec!["-tt".into(), host, "exec $SHELL -l".into()])
        } else {
            let cmd = format!("exec $SHELL -lc 'tmux new-session -A -s {}'", params.tmux_session);
            ("ssh".into(), vec!["-tt".into(), host, cmd])
        }
    }
}

async fn handle_pty(mut socket: WebSocket, params: PtyParams, state: ServerState) {
    let prev = ACTIVE_SESSIONS.fetch_add(1, Ordering::SeqCst);
    if prev >= MAX_PTY_SESSIONS {
        ACTIVE_SESSIONS.fetch_sub(1, Ordering::SeqCst);
        let _ = socket.send(Message::Text(
            format!("Max PTY sessions ({MAX_PTY_SESSIONS}) reached"),
        )).await;
        return;
    }
    let _guard = SessionGuard;
    let is_local = is_local_peer(&state, &params.peer);
    let (program, args) = build_pty_command(&state, &params, is_local);
    let mut child = match tokio::process::Command::new(&program)
        .args(&args)
        .stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::piped())
        .env("TERM", "xterm-256color").kill_on_drop(true).spawn()
    {
        Ok(c) => c,
        Err(e) => {
            let _ = socket.send(Message::Text(format!("Spawn error: {e}"))).await;
            return;
        }
    };
    let mut stdin = child.stdin.take().expect("stdin piped");
    let mut stdout = child.stdout.take().expect("stdout piped");
    let mut stderr = child.stderr.take().expect("stderr piped");
    let (tx, mut rx) = tokio::sync::mpsc::channel::<Vec<u8>>(64);
    let tx2 = tx.clone();
    tokio::spawn(async move {
        let mut buf = [0u8; 4096];
        while let Ok(n) = stdout.read(&mut buf).await {
            if n == 0 || tx.send(buf[..n].to_vec()).await.is_err() { break; }
        }
    });
    tokio::spawn(async move {
        let mut buf = [0u8; 4096];
        while let Ok(n) = stderr.read(&mut buf).await {
            if n == 0 || tx2.send(buf[..n].to_vec()).await.is_err() { break; }
        }
    });
    let mut last_activity = Instant::now();
    loop {
        tokio::select! {
            Some(data) = rx.recv() => {
                last_activity = Instant::now();
                if socket.send(Message::Binary(data)).await.is_err() { break; }
            }
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        last_activity = Instant::now();
                        if let Ok(v) = serde_json::from_str::<serde_json::Value>(&text) {
                            if v.get("type").and_then(|t| t.as_str()) == Some("resize") {
                                continue;
                            }
                        }
                        if stdin.write_all(text.as_bytes()).await.is_err() { break; }
                    }
                    Some(Ok(Message::Binary(data))) => {
                        last_activity = Instant::now();
                        if stdin.write_all(&data).await.is_err() { break; }
                    }
                    Some(Ok(Message::Close(_))) | None | Some(Err(_)) => break,
                    _ => {}
                }
            }
            _ = tokio::time::sleep_until(last_activity + IDLE_TIMEOUT) => {
                let _ = socket.send(Message::Text("Session timed out (5min idle)".into())).await;
                break;
            }
        }
    }
    drop(stdin);
    let _ = child.kill().await;
}
