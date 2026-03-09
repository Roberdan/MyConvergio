//! WebSocket PTY terminal — spawns local shell or SSH to remote mesh nodes.
//!
//! Client connects to `/ws/pty?peer=<name>&tmux_session=<s>`.
//! Protocol: JSON `{"type":"resize","cols":N,"rows":N}` for resize, raw text for stdin.
//! Server sends raw bytes (PTY stdout).

use super::state::ServerState;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::response::Response;
use serde::Deserialize;

#[derive(Deserialize)]
pub struct PtyParams {
    #[serde(default = "default_peer")]
    pub(crate) peer: String,
    #[serde(default)]
    pub(crate) tmux_session: String,
}
fn default_peer() -> String { "local".into() }

/// Resolved peer target from Tailscale + peers.conf
#[derive(Debug, Clone)]
pub(crate) struct ResolvedPeer {
    pub ip: String,
    pub user: Option<String>,
    pub online: bool,
    pub is_self: bool,
}

/// Read all key=value pairs from a peers.conf section
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

/// Resolve peer → Tailscale IP using peers.conf IP/DNS + live Tailscale status.
pub(crate) fn tailscale_resolve(peer: &str) -> Option<(String, bool, bool)> {
    let output = std::process::Command::new("tailscale")
        .args(["status", "--json"])
        .output().ok()?;
    if !output.status.success() { return None; }
    let json: serde_json::Value = serde_json::from_slice(&output.stdout).ok()?;

    // Load peers.conf for IP/DNS matching
    let conf = read_peer_conf(peer);
    let conf_ip = conf.as_ref().and_then(|c| c.get("tailscale_ip").cloned());
    let conf_dns = conf.as_ref().and_then(|c| c.get("dns_name").cloned());

    // Check Self node
    if let Some(self_node) = json.get("Self") {
        if ts_node_matches(self_node, conf_ip.as_deref(), conf_dns.as_deref(), peer) {
            let ip = ts_first_ip(self_node)?;
            return Some((ip, true, true));
        }
    }

    // Search peers
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

/// Match a Tailscale node: (1) exact IP, (2) DNS name, (3) fuzzy hostname
fn ts_node_matches(node: &serde_json::Value, conf_ip: Option<&str>, conf_dns: Option<&str>, peer: &str) -> bool {
    if let Some(ip) = conf_ip {
        if let Some(ips) = node.get("TailscaleIPs").and_then(|v| v.as_array()) {
            if ips.iter().any(|v| v.as_str() == Some(ip)) { return true; }
        }
    }
    if let Some(dns) = conf_dns {
        if let Some(node_dns) = node.get("DNSName").and_then(|v| v.as_str()) {
            let a = dns.trim_end_matches('.');
            let b = node_dns.trim_end_matches('.');
            if a.eq_ignore_ascii_case(b) { return true; }
        }
    }
    ts_name_matches(node, &peer.to_lowercase().replace(['-', '_', ' ', '\''], ""))
}

pub(crate) fn ts_name_matches(node: &serde_json::Value, normalized_peer: &str) -> bool {
    // Match against HostName and DNSName (normalized: lowercase, no punctuation)
    for field in ["HostName", "DNSName"] {
        if let Some(val) = node.get(field).and_then(|v| v.as_str()) {
            let norm = val.to_lowercase().replace(['-', '_', ' ', '\'', '.'], "");
            if norm.contains(normalized_peer) || normalized_peer.contains(&norm.split("tail").next().unwrap_or("").trim_end_matches('.')) {
                return true;
            }
        }
    }
    false
}

pub(crate) fn ts_first_ip(node: &serde_json::Value) -> Option<String> {
    node.get("TailscaleIPs")
        .and_then(|v| v.as_array())
        .and_then(|a| a.first())
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}

/// Get SSH user from peers.conf (Tailscale doesn't know SSH usernames)
pub(crate) fn peer_ssh_user(peer: &str) -> Option<String> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    let path = std::path::PathBuf::from(home).join(".claude/config/peers.conf");
    let text = std::fs::read_to_string(path).ok()?;
    let mut found = false;
    for line in text.lines() {
        let line = line.trim();
        if line.starts_with('#') || line.is_empty() { continue; }
        if line.starts_with('[') && line.ends_with(']') {
            found = &line[1..line.len()-1] == peer;
            continue;
        }
        if found {
            if let Some((k, v)) = line.split_once('=') {
                if k.trim() == "user" { return Some(v.trim().to_string()); }
            }
        }
    }
    None
}

/// Resolve peer → SSH target via Tailscale (dynamic) + peers.conf (user)
pub(crate) fn resolve_peer(_state: &ServerState, peer: &str) -> Option<ResolvedPeer> {
    let (ip, online, is_self) = tailscale_resolve(peer)?;
    let user = peer_ssh_user(peer);
    Some(ResolvedPeer { ip, user, online, is_self })
}

pub(crate) fn peer_ssh_alias(state: &ServerState, peer: &str) -> Option<String> {
    let resolved = resolve_peer(state, peer)?;
    if resolved.is_self { return None; } // local — no SSH needed
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
    ws: WebSocketUpgrade,
    Query(params): Query<PtyParams>,
    State(state): State<ServerState>,
) -> Response {
    ws.on_upgrade(move |socket| handle_pty(socket, params, state))
}

async fn handle_pty(mut socket: WebSocket, params: PtyParams, state: ServerState) {
    let (master_fd, slave_fd) = match unsafe { open_pty() } {
        Ok(fds) => fds,
        Err(e) => {
            let _ = socket.send(Message::Text(format!("PTY error: {e}"))).await;
            return;
        }
    };

    let is_local = is_local_peer(&state, &params.peer);
    let (program, args): (String, Vec<String>) = if is_local {
        if params.tmux_session.is_empty() {
            let sh = std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".into());
            (sh, vec!["-l".into()])
        } else {
            ("tmux".into(), vec!["new-session".into(), "-A".into(), "-s".into(), params.tmux_session.clone()])
        }
    } else {
        let host = peer_ssh_alias(&state, &params.peer).unwrap_or_else(|| params.peer.clone());
        if params.tmux_session.is_empty() {
            // Login shell via SSH to get full PATH
            ("ssh".into(), vec!["-t".into(), host, "exec $SHELL -l".into()])
        } else {
            // Login shell ensures PATH includes /opt/homebrew/bin (macOS) etc.
            let tmux_cmd = format!(
                "exec $SHELL -lc 'tmux new-session -A -s {}'",
                params.tmux_session
            );
            ("ssh".into(), vec!["-t".into(), host, tmux_cmd])
        }
    };

    let child_pid = unsafe {
        let pid = libc::fork();
        if pid < 0 {
            libc::close(master_fd); libc::close(slave_fd);
            return;
        }
        if pid == 0 {
            libc::setsid();
            libc::ioctl(slave_fd, libc::TIOCSCTTY as libc::c_ulong, 0);
            libc::dup2(slave_fd, 0);
            libc::dup2(slave_fd, 1);
            libc::dup2(slave_fd, 2);
            if slave_fd > 2 { libc::close(slave_fd); }
            libc::close(master_fd);
            std::env::set_var("TERM", "xterm-256color");
            let c_prog = std::ffi::CString::new(program.as_str()).unwrap();
            let mut c_args: Vec<std::ffi::CString> = vec![c_prog.clone()];
            for a in &args { c_args.push(std::ffi::CString::new(a.as_str()).unwrap()); }
            let c_ptrs: Vec<*const libc::c_char> = c_args.iter().map(|a| a.as_ptr()).chain(std::iter::once(std::ptr::null())).collect();
            libc::execvp(c_prog.as_ptr(), c_ptrs.as_ptr());
            libc::_exit(1);
        }
        libc::close(slave_fd);
        pid
    };

    let (pty_out_tx, mut pty_out_rx) = tokio::sync::mpsc::channel::<Vec<u8>>(64);
    let (ws_in_tx, mut ws_in_rx) = tokio::sync::mpsc::channel::<Vec<u8>>(64);

    let rd_fd = unsafe { libc::dup(master_fd) };
    std::thread::spawn(move || {
        let mut buf = [0u8; 4096];
        loop {
            let n = unsafe { libc::read(rd_fd, buf.as_mut_ptr().cast(), buf.len()) };
            if n <= 0 { break; }
            if pty_out_tx.blocking_send(buf[..n as usize].to_vec()).is_err() { break; }
        }
        unsafe { libc::close(rd_fd); }
    });

    let wr_fd = unsafe { libc::dup(master_fd) };
    std::thread::spawn(move || {
        while let Some(data) = ws_in_rx.blocking_recv() {
            let mut off = 0;
            while off < data.len() {
                let n = unsafe { libc::write(wr_fd, data[off..].as_ptr().cast(), data.len() - off) };
                if n <= 0 { return; }
                off += n as usize;
            }
        }
        unsafe { libc::close(wr_fd); }
    });

    let resize_fd = master_fd;
    loop {
        tokio::select! {
            Some(data) = pty_out_rx.recv() => {
                if socket.send(Message::Binary(data.into())).await.is_err() { break; }
            }
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        if let Ok(v) = serde_json::from_str::<serde_json::Value>(&text) {
                            if v.get("type").and_then(|t| t.as_str()) == Some("resize") {
                                let cols = v.get("cols").and_then(|c| c.as_u64()).unwrap_or(80) as u16;
                                let rows = v.get("rows").and_then(|r| r.as_u64()).unwrap_or(24) as u16;
                                let ws = libc::winsize { ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0 };
                                unsafe { libc::ioctl(resize_fd, libc::TIOCSWINSZ as libc::c_ulong, &ws); }
                                continue;
                            }
                        }
                        let _ = ws_in_tx.send(text.into_bytes()).await;
                    }
                    Some(Ok(Message::Binary(data))) => {
                        let _ = ws_in_tx.send(data.to_vec()).await;
                    }
                    Some(Ok(Message::Close(_))) | None | Some(Err(_)) => break,
                    _ => {}
                }
            }
        }
    }

    drop(ws_in_tx);
    unsafe {
        libc::close(master_fd);
        libc::signal(libc::SIGHUP, libc::SIG_DFL);
        let _ = libc::waitpid(child_pid, std::ptr::null_mut(), libc::WNOHANG);
    }
}

pub(crate) unsafe fn open_pty() -> Result<(i32, i32), String> {
    let mut master: i32 = 0;
    let mut slave: i32 = 0;
    if libc::openpty(&mut master, &mut slave, std::ptr::null_mut(), std::ptr::null_mut(), std::ptr::null_mut()) != 0 {
        return Err(format!("openpty: {}", std::io::Error::last_os_error()));
    }
    Ok((master, slave))
}
