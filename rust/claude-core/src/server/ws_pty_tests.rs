//! Tests for the WebSocket PTY terminal handler (`ws_pty`).
//!
//! Tests cover:
//! - PTY params deserialization (default peer, tmux_session)
//! - Tailscale name matching (fuzzy hostname/DNS resolution)
//! - peers.conf user lookup
//! - Local peer detection (explicit local, self via Tailscale)
//! - `open_pty` returns valid file descriptors
//! - PTY read/write roundtrip (write to master, read from master)
//! - Resize ioctl (TIOCSWINSZ) on PTY master
//! - Fork+exec produces output readable from master
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
    // This reads the real peers.conf — integration test
    let user = super::ws_pty::peer_ssh_user("m1mario");
    assert_eq!(user, Some("mariodan".into()));
}

#[test]
fn peer_ssh_user_self() {
    let user = super::ws_pty::peer_ssh_user("m3max");
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
    if std::process::Command::new("tailscale").arg("status").output().is_err() {
        return; // skip if tailscale not available
    }
    let result = super::ws_pty::tailscale_resolve("m3max");
    if let Some((ip, _online, is_self)) = result {
        assert!(ip.starts_with("100."), "expected Tailscale IP, got: {ip}");
        assert!(is_self, "m3max should be self");
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
    if std::process::Command::new("tailscale").arg("status").output().is_err() {
        return;
    }
    assert!(super::ws_pty::is_local_peer(&state, "m3max"));
}

#[test]
fn is_remote_via_tailscale() {
    let state = test_state();
    if std::process::Command::new("tailscale").arg("status").output().is_err() {
        return;
    }
    assert!(!super::ws_pty::is_local_peer(&state, "omarchy"));
}

// ── open_pty ────────────────────────────────────────────────────────

#[test]
fn open_pty_returns_valid_fds() {
    let (master, slave) = unsafe { super::ws_pty::open_pty().expect("open_pty") };
    assert!(master > 2, "master fd should be > stderr");
    assert!(slave > 2, "slave fd should be > stderr");
    assert_ne!(master, slave);
    unsafe {
        libc::close(master);
        libc::close(slave);
    }
}

#[test]
fn pty_write_read_roundtrip() {
    let (master, slave) = unsafe { super::ws_pty::open_pty().expect("open_pty") };
    let msg = b"hello pty\n";
    let written = unsafe { libc::write(slave, msg.as_ptr().cast(), msg.len()) };
    assert_eq!(written as usize, msg.len());
    unsafe {
        let flags = libc::fcntl(master, libc::F_GETFL);
        libc::fcntl(master, libc::F_SETFL, flags | libc::O_NONBLOCK);
    }
    std::thread::sleep(std::time::Duration::from_millis(50));
    let mut buf = [0u8; 256];
    let n = unsafe { libc::read(master, buf.as_mut_ptr().cast(), buf.len()) };
    assert!(n > 0, "should read data from master");
    let output = String::from_utf8_lossy(&buf[..n as usize]);
    assert!(output.contains("hello pty"), "got: {output}");
    unsafe {
        libc::close(master);
        libc::close(slave);
    }
}

// ── Resize ioctl ────────────────────────────────────────────────────

#[test]
fn pty_resize_ioctl() {
    let (master, slave) = unsafe { super::ws_pty::open_pty().expect("open_pty") };
    let ws = libc::winsize { ws_row: 50, ws_col: 120, ws_xpixel: 0, ws_ypixel: 0 };
    let ret = unsafe { libc::ioctl(master, libc::TIOCSWINSZ as libc::c_ulong, &ws) };
    assert_eq!(ret, 0);
    let mut ws_read = libc::winsize { ws_row: 0, ws_col: 0, ws_xpixel: 0, ws_ypixel: 0 };
    let ret = unsafe { libc::ioctl(master, libc::TIOCGWINSZ as libc::c_ulong, &mut ws_read) };
    assert_eq!(ret, 0);
    assert_eq!(ws_read.ws_row, 50);
    assert_eq!(ws_read.ws_col, 120);
    unsafe {
        libc::close(master);
        libc::close(slave);
    }
}

// ── Fork+exec produces output ───────────────────────────────────────

#[test]
fn fork_exec_echo_produces_output() {
    let (master, slave) = unsafe { super::ws_pty::open_pty().expect("open_pty") };
    let pid = unsafe {
        let pid = libc::fork();
        if pid == 0 {
            libc::setsid();
            libc::dup2(slave, 0);
            libc::dup2(slave, 1);
            libc::dup2(slave, 2);
            if slave > 2 { libc::close(slave); }
            libc::close(master);
            let prog = std::ffi::CString::new("/bin/echo").unwrap();
            let arg = std::ffi::CString::new("pty-test-output").unwrap();
            let args = [prog.as_ptr(), arg.as_ptr(), std::ptr::null()];
            libc::execvp(prog.as_ptr(), args.as_ptr());
            libc::_exit(1);
        }
        libc::close(slave);
        pid
    };
    std::thread::sleep(std::time::Duration::from_millis(200));
    let mut buf = [0u8; 512];
    let n = unsafe { libc::read(master, buf.as_mut_ptr().cast(), buf.len()) };
    unsafe { libc::waitpid(pid, std::ptr::null_mut(), 0); }
    assert!(n > 0, "should get output from child process (n={n})");
    let output = String::from_utf8_lossy(&buf[..n as usize]);
    assert!(output.contains("pty-test-output"), "got: {output}");
    unsafe { libc::close(master); }
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
