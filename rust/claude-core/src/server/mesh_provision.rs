//! Mesh node provisioning — ensure all peers are ready for Convergio sessions.
//!
//! On server start or `/api/mesh/provision`, checks each peer in `peers.conf`:
//! 1. SSH reachable (via Tailscale IP)
//! 2. tmux installed and in PATH
//! 3. Convergio tmux session exists (creates if missing)
//!
//! Auto-fixes: creates tmux session, fixes PATH issues.

use super::state::ServerState;
use super::ws_pty;
use axum::extract::State;
use axum::response::Json;
use serde_json::{json, Value};
use std::process::Command;

/// Per-peer readiness result
#[derive(Debug, Clone)]
struct PeerCheck {
    peer: String,
    ip: Option<String>,
    user: Option<String>,
    online: bool,
    ssh_ok: bool,
    tmux_ok: bool,
    session_ok: bool,
    error: Option<String>,
}

/// Check and provision all mesh peers. Returns JSON status per peer.
pub async fn provision_all(State(_state): State<ServerState>) -> Json<Value> {
    let peers = list_peers();
    let mut results = Vec::new();

    for peer in &peers {
        let check = check_and_provision_peer(peer);
        results.push(json!({
            "peer": check.peer,
            "ip": check.ip,
            "user": check.user,
            "online": check.online,
            "ssh_ok": check.ssh_ok,
            "tmux_ok": check.tmux_ok,
            "session_ok": check.session_ok,
            "error": check.error,
        }));
    }

    let all_ok = results.iter().all(|r| {
        r.get("session_ok").and_then(|v| v.as_bool()).unwrap_or(false)
            || !r.get("online").and_then(|v| v.as_bool()).unwrap_or(false)
    });

    Json(json!({ "ok": all_ok, "peers": results }))
}

/// List peer names from peers.conf
fn list_peers() -> Vec<String> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    let path = std::path::PathBuf::from(home).join(".claude/config/peers.conf");
    let Ok(text) = std::fs::read_to_string(path) else { return vec![] };
    text.lines()
        .filter(|l| l.starts_with('[') && l.ends_with(']'))
        .map(|l| l[1..l.len()-1].to_string())
        .collect()
}

fn check_and_provision_peer(peer: &str) -> PeerCheck {
    let mut check = PeerCheck {
        peer: peer.to_string(),
        ip: None, user: None,
        online: false, ssh_ok: false, tmux_ok: false, session_ok: false,
        error: None,
    };

    // Resolve via Tailscale
    let Some((ip, online, is_self)) = ws_pty::tailscale_resolve(peer) else {
        check.error = Some("Not found in Tailscale network".into());
        return check;
    };
    check.ip = Some(ip.clone());
    check.online = online;
    check.user = ws_pty::peer_ssh_user(peer);

    if !online && !is_self {
        check.error = Some("Peer offline".into());
        return check;
    }

    if is_self {
        check_local_node(&mut check);
    } else {
        check_remote_node(&mut check, &ip);
    }

    check
}

fn check_local_node(check: &mut PeerCheck) {
    check.ssh_ok = true;

    // Check tmux
    match Command::new("tmux").arg("-V").output() {
        Ok(o) if o.status.success() => { check.tmux_ok = true; }
        _ => {
            check.error = Some("tmux not installed locally".into());
            return;
        }
    }

    // Check/create Convergio session
    let has_session = Command::new("tmux")
        .args(["has-session", "-t", "Convergio"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    if has_session {
        check.session_ok = true;
    } else {
        // Create the session
        let created = Command::new("tmux")
            .args(["new-session", "-d", "-s", "Convergio"])
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);
        check.session_ok = created;
        if !created {
            check.error = Some("Failed to create Convergio tmux session".into());
        }
    }
}

fn check_remote_node(check: &mut PeerCheck, ip: &str) {
    let ssh_target = match &check.user {
        Some(u) => format!("{u}@{ip}"),
        None => ip.to_string(),
    };

    // SSH reachable? (timeout 5s)
    let ssh_ok = Command::new("ssh")
        .args(["-o", "ConnectTimeout=5", "-o", "BatchMode=yes", &ssh_target, "echo ok"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    if !ssh_ok {
        check.error = Some(format!("SSH unreachable: {ssh_target}"));
        return;
    }
    check.ssh_ok = true;

    // Check tmux via login shell (ensures PATH includes /opt/homebrew/bin)
    let tmux_check = Command::new("ssh")
        .args(["-o", "ConnectTimeout=5", &ssh_target, "$SHELL -lc 'tmux -V'"])
        .output();

    match tmux_check {
        Ok(o) if o.status.success() => { check.tmux_ok = true; }
        _ => {
            check.error = Some("tmux not found on peer (even with login shell PATH)".into());
            return;
        }
    }

    // Check/create Convergio session
    let has_session = Command::new("ssh")
        .args(["-o", "ConnectTimeout=5", &ssh_target,
            "$SHELL -lc 'tmux has-session -t Convergio 2>/dev/null && echo yes || echo no'"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "yes")
        .unwrap_or(false);

    if has_session {
        check.session_ok = true;
    } else {
        let created = Command::new("ssh")
            .args(["-o", "ConnectTimeout=5", &ssh_target,
                "$SHELL -lc 'tmux new-session -d -s Convergio'"])
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);
        check.session_ok = created;
        if !created {
            check.error = Some("Failed to create Convergio tmux session on peer".into());
        }
    }
}
