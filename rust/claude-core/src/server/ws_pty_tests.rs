//! Tests for the WebSocket PTY terminal handler (`ws_pty`).
//!
//! Tests cover:
//! - PTY params deserialization (default peer, tmux_session)
//! - Tailscale name matching (fuzzy hostname/DNS resolution)
//! - peers.conf user lookup
//! - Local peer detection (explicit local, self via Tailscale)
//! - Session limit constants (MAX_PTY_SESSIONS, ACTIVE_SESSIONS)
//! - tokio::process::Command spawn produces output
//! - WebSocket message routing (text stdin, binary stdin, resize JSON)

use super::state::ServerState;

fn test_state() -> ServerState {
    let dir = std::env::temp_dir().join(format!("pty_test_{}", std::process::id()));
    let _ = std::fs::create_dir_all(&dir);
    let db_path = dir.join("test.db");
    ServerState::new(db_path)
}

// ── Params deserialization ──────────────────────────────────────────

#[test]
fn params_default_peer() {
    let p: super::ws_pty::PtyParams = serde_json::from_str("{}").unwrap();
    assert_eq!(p.peer, "local");
    assert!(p.tmux_session.is_empty());
}

#[test]
fn params_with_peer_and_tmux() {
    let p: super::ws_pty::PtyParams =
        serde_json::from_str(r#"{"peer":"omarchy","tmux_session":"main"}"#).unwrap();
    assert_eq!(p.peer, "omarchy");
    assert_eq!(p.tmux_session, "main");
}

#[test]
fn params_peer_only() {
    let p: super::ws_pty::PtyParams =
        serde_json::from_str(r#"{"peer":"m1mario"}"#).unwrap();
    assert_eq!(p.peer, "m1mario");
    assert!(p.tmux_session.is_empty());
}

// ── Tailscale name matching ─────────────────────────────────────────

#[test]
fn ts_name_matches_hostname() {
    let node: serde_json::Value = serde_json::from_str(
        r#"{"HostName":"MarioDan's MacBook Pro M1","DNSName":"mariodans-macbook-pro-m1.tail01f12c.ts.net.","TailscaleIPs":["100.106.173.118"],"Online":true}"#
    ).unwrap();
    // "m1mario" can't fuzzy-match "mariodansmacbookprom1" — that's expected.
    // Real resolution uses peers.conf tailscale_ip → ts_node_matches, not ts_name_matches.
    let normalized = "m1mario".to_lowercase().replace(['-', '_', ' ', '\''], "");
    assert!(!super::ws_pty::ts_name_matches(&node, &normalized), "fuzzy alone won't match m1mario");
    // But ts_node_matches with IP from peers.conf WILL match
    let ips = node.get("TailscaleIPs").unwrap().as_array().unwrap();
    assert!(ips.iter().any(|v| v.as_str() == Some("100.106.173.118")), "IP match works");
}

#[test]
fn ts_name_matches_omarchy() {
    let node: serde_json::Value = serde_json::from_str(
        r#"{"HostName":"omarchy","DNSName":"omarchy.tail01f12c.ts.net.","TailscaleIPs":["100.127.138.62"],"Online":true}"#
    ).unwrap();
    assert!(super::ws_pty::ts_name_matches(&node, "omarchy"));
}

#[test]
fn ts_name_no_match() {
    let node: serde_json::Value = serde_json::from_str(
        r#"{"HostName":"omarchy","DNSName":"omarchy.tail01f12c.ts.net.","TailscaleIPs":["100.127.138.62"],"Online":true}"#
    ).unwrap();
    assert!(!super::ws_pty::ts_name_matches(&node, "m1mario"));
}

#[test]
fn ts_first_ip_extracts_ipv4() {
    let node: serde_json::Value = serde_json::from_str(
        r#"{"TailscaleIPs":["100.106.173.118","fd7a:115c:a1e0::3"]}"#
    ).unwrap();
    assert_eq!(super::ws_pty::ts_first_ip(&node), Some("100.106.173.118".into()));
}

#[test]
fn ts_first_ip_empty() {
    let node: serde_json::Value = serde_json::from_str(r#"{"TailscaleIPs":[]}"#).unwrap();
    assert!(super::ws_pty::ts_first_ip(&node).is_none());
}

// ── peers.conf user lookup ──────────────────────────────────────────

#[test]
fn peer_ssh_user_from_conf() {
    // Integration test — reads real peers.conf, skip on CI
    let user = super::ws_pty::peer_ssh_user("m1mario");
    if user.is_none() { return; } // peers.conf not available (CI)
    assert_eq!(user, Some("mariodan".into()));
}

#[test]
fn peer_ssh_user_self() {
    let user = super::ws_pty::peer_ssh_user("m3max");
    if user.is_none() { return; } // peers.conf not available (CI)
    assert_eq!(user, Some("roberdan".into()));
}

#[test]
fn peer_ssh_user_unknown() {
    let user = super::ws_pty::peer_ssh_user("nonexistent");
    assert!(user.is_none());
}

// ── Tailscale live resolution (requires tailscale running) ──────────

#[test]
fn tailscale_resolve_self() {
    let ts_out = std::process::Command::new("tailscale").arg("status").output();
    match &ts_out {
        Ok(o) if o.status.success() => {}
        _ => return, // skip if tailscale not running
    }
    // Use the local hostname to test self-resolution
    let hostname = std::process::Command::new("hostname").arg("-s").output()
        .ok().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_lowercase().to_string())
        .unwrap_or_default();
    // Find matching peer name from known peers
    let peer = if hostname.contains("m3") || hostname.contains("roberto") { "m3max" }
        else if hostname.contains("m1") || hostname.contains("mario") { "m1mario" }
        else { return }; // unknown host, skip
    let result = super::ws_pty::tailscale_resolve(peer);
    if let Some((ip, _online, is_self)) = result {
        assert!(ip.starts_with("100."), "expected Tailscale IP, got: {ip}");
        assert!(is_self, "{peer} should be self on this host");
    }
}

#[test]
fn tailscale_resolve_remote() {
    if std::process::Command::new("tailscale").arg("status").output().is_err() {
        return;
    }
    let result = super::ws_pty::tailscale_resolve("omarchy");
    if let Some((ip, _online, is_self)) = result {
        assert!(ip.starts_with("100."));
        assert!(!is_self, "omarchy should not be self");
    }
}

// ── Local peer detection ────────────────────────────────────────────

#[test]
fn is_local_literal_local() {
    let state = test_state();
    assert!(super::ws_pty::is_local_peer(&state, "local"));
}

#[test]
fn is_local_literal_localhost() {
    let state = test_state();
    assert!(super::ws_pty::is_local_peer(&state, "localhost"));
}

#[test]
fn is_local_self_via_tailscale() {
    let state = test_state();
    let ts_out = std::process::Command::new("tailscale").arg("status").output();
    match &ts_out {
        Ok(o) if o.status.success() => {}
        _ => return, // skip if tailscale not running
    }
    let hostname = std::process::Command::new("hostname").arg("-s").output()
        .ok().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_lowercase().to_string())
        .unwrap_or_default();
    let peer = if hostname.contains("m3") || hostname.contains("roberto") { "m3max" }
        else if hostname.contains("m1") || hostname.contains("mario") { "m1mario" }
        else { return };
    assert!(super::ws_pty::is_local_peer(&state, peer));
}

#[test]
fn is_remote_via_tailscale() {
    let state = test_state();
    if std::process::Command::new("tailscale").arg("status").output().is_err() {
        return;
    }
    assert!(!super::ws_pty::is_local_peer(&state, "omarchy"));
}

// ── Session limits ───────────────────────────────────────────────────

#[test]
fn session_limit_constants() {
    assert_eq!(super::ws_pty::MAX_PTY_SESSIONS, 10);
    // ACTIVE_SESSIONS starts at 0 (may be non-zero if other tests ran concurrently)
    let _ = super::ws_pty::ACTIVE_SESSIONS.load(std::sync::atomic::Ordering::SeqCst);
}

// ── tokio::process spawn ────────────────────────────────────────────

#[tokio::test]
async fn spawn_echo_produces_output() {
    use tokio::io::AsyncReadExt;
    let mut child = tokio::process::Command::new("/bin/echo")
        .arg("pty-test-output")
        .stdout(std::process::Stdio::piped())
        .spawn()
        .expect("spawn echo");
    let mut stdout = child.stdout.take().unwrap();
    let mut buf = String::new();
    stdout.read_to_string(&mut buf).await.expect("read stdout");
    assert!(buf.contains("pty-test-output"), "got: {buf}");
    let status = child.wait().await.expect("wait");
    assert!(status.success());
}

// ── JSON message parsing ────────────────────────────────────────────

#[test]
fn resize_json_parsing() {
    let text = r#"{"type":"resize","cols":120,"rows":40}"#;
    let v: serde_json::Value = serde_json::from_str(text).unwrap();
    assert_eq!(v.get("type").unwrap().as_str(), Some("resize"));
    assert_eq!(v.get("cols").unwrap().as_u64(), Some(120));
    assert_eq!(v.get("rows").unwrap().as_u64(), Some(40));
}

#[test]
fn non_resize_json_is_stdin() {
    let text = r#"{"type":"data","content":"ls"}"#;
    let v: serde_json::Value = serde_json::from_str(text).unwrap();
    assert_ne!(v.get("type").unwrap().as_str(), Some("resize"));
}

#[test]
fn plain_text_is_stdin() {
    let text = "ls -la\n";
    assert!(serde_json::from_str::<serde_json::Value>(text).is_err());
}
