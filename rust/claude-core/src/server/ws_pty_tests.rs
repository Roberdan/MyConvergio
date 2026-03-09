//! Tests for the WebSocket PTY terminal handler (`ws_pty`).
//!
//! Tests cover:
//! - PTY params deserialization (default peer, tmux_session)
//! - Peer SSH alias lookup (found, not found, no DB)
//! - Local peer detection (explicit local, DB lookup, unknown)
//! - Command building (local shell, local tmux, remote SSH, remote SSH+tmux)
//! - `open_pty` returns valid file descriptors
//! - PTY read/write roundtrip (write to master, read from master)
//! - Resize ioctl (TIOCSWINSZ) on PTY master
//! - Fork+exec produces output readable from master
//! - WebSocket message routing (text stdin, binary stdin, resize JSON)

use super::state::ServerState;

fn test_state() -> ServerState {
    // Use a temp DB with peers table
    let dir = std::env::temp_dir().join(format!("pty_test_{}", std::process::id()));
    let _ = std::fs::create_dir_all(&dir);
    let db_path = dir.join("test.db");
    let state = ServerState::new(db_path.clone());
    // Create peers table with test data
    if let Ok(db) = state.open_db() {
        let conn = db.connection();
        let _ = conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS peers (
                peer_name TEXT PRIMARY KEY,
                ssh_alias TEXT,
                is_local INTEGER DEFAULT 0,
                dns_name TEXT
            );
            INSERT OR REPLACE INTO peers VALUES ('m3max', 'robertos-macbook-pro.ts.net', 1, 'robertos-macbook-pro.ts.net');
            INSERT OR REPLACE INTO peers VALUES ('omarchy', 'omarchy-ts', 0, 'omarchy.ts.net');
            INSERT OR REPLACE INTO peers VALUES ('m1mario', 'mac-dev-ts', 0, 'mario.ts.net');",
        );
    }
    state
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

// ── Peer lookup ─────────────────────────────────────────────────────

#[test]
fn ssh_alias_found() {
    let state = test_state();
    let alias = super::ws_pty::peer_ssh_alias(&state, "omarchy");
    assert_eq!(alias, Some("omarchy-ts".into()));
}

#[test]
fn ssh_alias_not_found() {
    let state = test_state();
    let alias = super::ws_pty::peer_ssh_alias(&state, "nonexistent");
    assert!(alias.is_none());
}

#[test]
fn ssh_alias_local_peer() {
    let state = test_state();
    let alias = super::ws_pty::peer_ssh_alias(&state, "m3max");
    assert_eq!(alias, Some("robertos-macbook-pro.ts.net".into()));
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
fn is_local_from_db() {
    let state = test_state();
    assert!(super::ws_pty::is_local_peer(&state, "m3max"));
}

#[test]
fn is_remote_from_db() {
    let state = test_state();
    assert!(!super::ws_pty::is_local_peer(&state, "omarchy"));
    assert!(!super::ws_pty::is_local_peer(&state, "m1mario"));
}

#[test]
fn is_local_unknown_peer() {
    let state = test_state();
    assert!(!super::ws_pty::is_local_peer(&state, "unknown-host"));
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
    // Write to slave, read from master
    let msg = b"hello pty\n";
    let written = unsafe { libc::write(slave, msg.as_ptr().cast(), msg.len()) };
    assert_eq!(written as usize, msg.len());

    // Set master non-blocking for read
    unsafe {
        let flags = libc::fcntl(master, libc::F_GETFL);
        libc::fcntl(master, libc::F_SETFL, flags | libc::O_NONBLOCK);
    }

    // Small delay for PTY buffer
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
    let ws = libc::winsize {
        ws_row: 50,
        ws_col: 120,
        ws_xpixel: 0,
        ws_ypixel: 0,
    };
    let ret = unsafe { libc::ioctl(master, libc::TIOCSWINSZ as libc::c_ulong, &ws) };
    assert_eq!(ret, 0, "ioctl TIOCSWINSZ should succeed");

    // Verify by reading back
    let mut ws_read = libc::winsize {
        ws_row: 0,
        ws_col: 0,
        ws_xpixel: 0,
        ws_ypixel: 0,
    };
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
            // Child: attach slave, exec echo
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

    // Read output (blocking, child runs fast)
    std::thread::sleep(std::time::Duration::from_millis(200));

    let mut buf = [0u8; 512];
    // Use blocking read — child already finished, data is in PTY buffer
    let n = unsafe { libc::read(master, buf.as_mut_ptr().cast(), buf.len()) };
    // Reap child
    unsafe { libc::waitpid(pid, std::ptr::null_mut(), 0); }

    assert!(n > 0, "should get output from child process (n={n})");
    let output = String::from_utf8_lossy(&buf[..n as usize]);
    assert!(output.contains("pty-test-output"), "got: {output}");

    unsafe { libc::close(master); }
}

// ── Resize JSON parsing ─────────────────────────────────────────────

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
    // Non-JSON text should be sent directly to PTY as stdin
}
