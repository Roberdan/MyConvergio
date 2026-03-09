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

pub(crate) fn peer_ssh_alias(state: &ServerState, peer: &str) -> Option<String> {
    let db = state.open_db().ok()?;
    let conn = db.connection();
    let mut stmt = conn
        .prepare("SELECT ssh_alias FROM peers WHERE peer_name = ?1 AND ssh_alias IS NOT NULL")
        .ok()?;
    stmt.query_row([peer], |row| row.get::<_, String>(0)).ok()
}

pub(crate) fn is_local_peer(state: &ServerState, peer: &str) -> bool {
    if peer == "local" || peer == "localhost" { return true; }
    let Some(db) = state.open_db().ok() else { return false; };
    let conn = db.connection();
    let mut stmt = match conn.prepare("SELECT is_local FROM peers WHERE peer_name = ?1") {
        Ok(s) => s,
        Err(_) => return false,
    };
    stmt.query_row([peer], |row| row.get::<_, bool>(0)).unwrap_or(false)
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
            ("ssh".into(), vec!["-t".into(), host])
        } else {
            ("ssh".into(), vec!["-t".into(), host, format!("tmux new-session -A -s {}", params.tmux_session)])
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
