use crate::mesh::auth;
use crate::mesh::sync::{self, MeshSyncFrame};
use serde_json::json;
use std::sync::Arc;
use std::time::Duration;
use tokio::io::AsyncReadExt;
use tokio::net::TcpStream;
use tokio::sync::{mpsc, RwLock};

use super::{
    handle_ws_client, is_ws_brain_request, now_ts, publish_event, relay_agent_activity_changes, DaemonConfig, DaemonState,
};

/// Handle a peer connection. `is_outbound` = true spawns the delta loop (only outbound sends changes).
/// Inbound connections only receive frames and send heartbeats/acks.
/// T1-09: Challenge-response auth required before any data exchange.
pub(super) async fn handle_socket(
    mut stream: TcpStream,
    conn_id: String,
    state: DaemonState,
    config: DaemonConfig,
    is_outbound: bool,
) -> Result<(), String> {
    if let Some(head) = maybe_ws_request_head(&mut stream).await {
        return handle_ws_client(stream, &head, state).await;
    }
    let (mut read_half, mut write_half) = stream.into_split();

    // T1-09: Peer authentication — shared secret from [mesh] section of peers.conf
    let secret = auth::load_shared_secret(&config.peers_conf_path);
    if let Some(ref key) = secret {
        if is_outbound {
            // Outbound: wait for challenge, respond with HMAC
            match sync::read_frame(&mut read_half).await? {
                Some(MeshSyncFrame::AuthChallenge { nonce, .. }) => {
                    let hmac = auth::compute_hmac(key, &nonce);
                    sync::write_frame(&mut write_half, &MeshSyncFrame::AuthResponse {
                        hmac, node: state.node_id.clone(),
                    }).await?;
                    match sync::read_frame(&mut read_half).await? {
                        Some(MeshSyncFrame::AuthResult { ok: true, .. }) => {}
                        Some(MeshSyncFrame::AuthResult { ok: false, reason, .. }) => {
                            return Err(format!("auth rejected: {reason}"));
                        }
                        _ => return Err("unexpected frame during auth".into()),
                    }
                }
                _ => return Err("expected AuthChallenge".into()),
            }
        } else {
            // Inbound: send challenge, verify response
            let nonce = auth::generate_nonce();
            sync::write_frame(&mut write_half, &MeshSyncFrame::AuthChallenge {
                nonce: nonce.clone(), node: state.node_id.clone(),
            }).await?;
            match sync::read_frame(&mut read_half).await? {
                Some(MeshSyncFrame::AuthResponse { hmac, node }) => {
                    if auth::verify_hmac(key, &nonce, &hmac) {
                        sync::write_frame(&mut write_half, &MeshSyncFrame::AuthResult {
                            ok: true, reason: String::new(),
                        }).await?;
                        publish_event(&state, "auth_ok", &node, json!({}));
                    } else {
                        sync::write_frame(&mut write_half, &MeshSyncFrame::AuthResult {
                            ok: false, reason: "HMAC mismatch".into(),
                        }).await?;
                        return Err(format!("auth failed for {node}: HMAC mismatch"));
                    }
                }
                _ => return Err("expected AuthResponse".into()),
            }
        }
    }
    // Auth passed (or no secret configured — backward compatible)

    let (out_tx, mut out_rx) = mpsc::channel::<MeshSyncFrame>(64);
    let writer = tokio::spawn(async move {
        while let Some(frame) = out_rx.recv().await {
            if sync::write_frame(&mut write_half, &frame).await.is_err() {
                break;
            }
        }
    });
    let _ = out_tx
        .send(MeshSyncFrame::Heartbeat {
            node: state.node_id.clone(),
            ts: now_ts(),
        })
        .await;
    let sync_peer = Arc::new(RwLock::new(conn_id.clone()));
    spawn_heartbeat_loop(out_tx.clone(), state.node_id.clone());
    // Only outbound connections send deltas — prevents duplicate delta loops
    if is_outbound {
        spawn_delta_loop(out_tx.clone(), sync_peer.clone(), state.node_id.clone(), config.clone());
    }
    loop {
        let frame = match sync::read_frame(&mut read_half).await? {
            Some(frame) => frame,
            None => break,
        };
        if let Err(err) = process_frame(&frame, &state, &config, &out_tx, &sync_peer).await {
            let peer = sync_peer.read().await.clone();
            let _ = sync::record_sync_error(&config.db_path, config.crsqlite_path.as_deref(), &peer, &err);
            publish_event(&state, "sync_error", &peer, json!({ "error": err }));
        }
    }
    drop(out_tx);
    let _ = writer.await;
    Ok(())
}

async fn process_frame(
    frame: &MeshSyncFrame,
    state: &DaemonState,
    config: &DaemonConfig,
    out_tx: &mpsc::Sender<MeshSyncFrame>,
    sync_peer: &Arc<RwLock<String>>,
) -> Result<(), String> {
    match frame {
        MeshSyncFrame::Heartbeat { node, ts } => {
            *sync_peer.write().await = node.clone();
            state.heartbeats.write().await.insert(node.clone(), *ts);
            // T1-06: Persist heartbeat to DB with crsqlite loaded (CRR triggers need it)
            if let Ok(conn) = sync::open_persistent_sync_conn(&config.db_path, config.crsqlite_path.as_deref()) {
                let peer_name = resolve_peer_name(&config.peers_conf_path, node);
                let _ = conn.execute(
                    "INSERT OR REPLACE INTO peer_heartbeats (peer_name, last_seen) \
                     VALUES (?1, ?2) \
                     ON CONFLICT(peer_name) DO UPDATE SET last_seen = excluded.last_seen",
                    rusqlite::params![peer_name, ts],
                );
            }
            publish_event(state, "heartbeat", node, json!({ "ts": ts }));
        }
        MeshSyncFrame::Delta {
            node,
            sent_at_ms,
            changes,
            ..
        } => {
            *sync_peer.write().await = node.clone();
            let summary = sync::apply_delta_frame(
                &config.db_path,
                config.crsqlite_path.as_deref(),
                node,
                *sent_at_ms,
                changes,
            )?;
            let _ = out_tx
                .send(MeshSyncFrame::Ack {
                    node: state.node_id.clone(),
                    applied: summary.applied,
                    latency_ms: summary.latency_ms,
                    last_db_version: summary.last_db_version,
                })
                .await;
            relay_agent_activity_changes(state, node, changes);
            publish_event(
                state,
                "sync_delta",
                node,
                json!({"received": changes.len(), "applied": summary.applied, "latency_ms": summary.latency_ms}),
            );
        }
        MeshSyncFrame::Ack {
            node,
            applied,
            latency_ms,
            last_db_version,
        } => {
            *sync_peer.write().await = node.clone();
            publish_event(
                state,
                "sync_ack",
                node,
                json!({"applied": applied, "latency_ms": latency_ms, "last_db_version": last_db_version}),
            );
        }
        // Auth frames are handled in handshake, not in main loop
        MeshSyncFrame::AuthChallenge { .. }
        | MeshSyncFrame::AuthResponse { .. }
        | MeshSyncFrame::AuthResult { .. } => {}
    }
    Ok(())
}

fn spawn_heartbeat_loop(out_tx: mpsc::Sender<MeshSyncFrame>, node_id: String) {
    tokio::spawn(async move {
        let mut ticker = tokio::time::interval(Duration::from_secs(5));
        loop {
            ticker.tick().await;
            if out_tx
                .send(MeshSyncFrame::Heartbeat {
                    node: node_id.clone(),
                    ts: now_ts(),
                })
                .await
                .is_err()
            {
                break;
            }
        }
    });
}

use std::sync::mpsc as std_mpsc;

// Type alias to simplify complex channel types used below
type SyncReply = std_mpsc::Sender<Result<(Vec<sync::DeltaChange>, i64, i64), String>>;

/// Messages for the dedicated DB sync thread
enum SyncDbCmd {
    CollectChanges { cursor: i64, reply: SyncReply },
    RecordSent { peer: String, count: usize, version: i64 },
    /// T1-01: Anti-entropy — get peer's last known db_version for catch-up
    GetPeerCursor { peer: String, reply: std_mpsc::Sender<i64> },
}

/// Spawn a single DB thread that owns one persistent connection
fn spawn_sync_db_thread(config: &DaemonConfig) -> std_mpsc::Sender<SyncDbCmd> {
    let (tx, rx) = std_mpsc::channel::<SyncDbCmd>();
    let db_path = config.db_path.clone();
    let crsql_path = config.crsqlite_path.clone();
    std::thread::Builder::new().name("mesh-sync-db".into()).spawn(move || {
        let conn = match sync::open_persistent_sync_conn(&db_path, crsql_path.as_deref()) {
            Ok(c) => c,
            Err(e) => { eprintln!("mesh-sync-db: failed to open DB: {e}"); return; }
        };
        let _ = sync::ensure_sync_schema_pub(&conn);
        while let Ok(cmd) = rx.recv() {
            match cmd {
                SyncDbCmd::CollectChanges { cursor, reply } => {
                    let init_cursor = if cursor < 0 {
                        sync::current_db_version_with_conn(&conn).unwrap_or(0)
                    } else {
                        cursor
                    };
                    let result = sync::collect_changes_with_conn(&conn, init_cursor)
                        .map(|(changes, checkpoint)| (changes, checkpoint, init_cursor));
                    let _ = reply.send(result);
                }
                SyncDbCmd::RecordSent { peer, count, version } => {
                    let _ = sync::record_sent_stats_with_conn(&conn, &peer, count, version);
                }
                SyncDbCmd::GetPeerCursor { peer, reply } => {
                    // T1-01: Anti-entropy — resume from peer's last known version
                    let cursor = conn.query_row(
                        "SELECT COALESCE(last_db_version, 0) FROM mesh_sync_stats WHERE peer_name = ?1",
                        rusqlite::params![peer],
                        |r| r.get::<_, i64>(0),
                    ).unwrap_or(0);
                    let _ = reply.send(cursor);
                }
            }
        }
    }).expect("spawn mesh-sync-db thread");
    tx
}

fn spawn_delta_loop(
    out_tx: mpsc::Sender<MeshSyncFrame>,
    sync_peer: Arc<RwLock<String>>,
    node_id: String,
    config: DaemonConfig,
) {
    let db_tx = spawn_sync_db_thread(&config);
    tokio::spawn(async move {
        let mut ticker = tokio::time::interval(Duration::from_secs(2));
        let mut db_cursor: i64 = -1; // -1 = needs initialization from anti-entropy
        let mut batch_window = sync::SyncBatchWindow::new(50);
        let mut staged_changes = Vec::new();
        let mut idle_ticks: u32 = 0;
        let mut anti_entropy_done = false;
        loop {
            ticker.tick().await;
            if idle_ticks > 0 {
                let extra_wait = Duration::from_secs((2u64.pow(idle_ticks.min(4))).min(30));
                tokio::time::sleep(extra_wait).await;
            }
            let peer_name = sync_peer.read().await.clone();

            // T1-01: Anti-entropy — on first tick, get peer's last known cursor
            if !anti_entropy_done && db_cursor < 0 {
                let (reply_tx, reply_rx) = std_mpsc::channel();
                if db_tx.send(SyncDbCmd::GetPeerCursor { peer: peer_name.clone(), reply: reply_tx }).is_ok() {
                    if let Ok(Ok(cursor)) = tokio::task::spawn_blocking(move || reply_rx.recv()).await {
                        if cursor > 0 {
                            db_cursor = cursor;
                        }
                    }
                }
                anti_entropy_done = true;
            }
            // Send collect command to DB thread
            let (reply_tx, reply_rx) = std_mpsc::channel();
            if db_tx.send(SyncDbCmd::CollectChanges { cursor: db_cursor, reply: reply_tx }).is_err() {
                break; // DB thread died
            }
            // Wait for reply (blocking but the DB work is fast)
            let db_result = tokio::task::spawn_blocking(move || reply_rx.recv())
                .await
                .ok()
                .and_then(|r| r.ok())
                .unwrap_or(Err("DB thread unavailable".into()));
            match db_result {
                Ok((changes, checkpoint, effective_cursor)) => {
                    if db_cursor < 0 {
                        db_cursor = effective_cursor;
                    }
                    if !changes.is_empty() {
                        db_cursor = checkpoint;
                        batch_window.observe_change(checkpoint);
                        staged_changes.extend(changes);
                        idle_ticks = 0;
                    } else {
                        idle_ticks = idle_ticks.saturating_add(1);
                    }
                    if !staged_changes.is_empty() && batch_window.should_flush(sync::current_time_ms()) {
                        let send_count = staged_changes.len(); // T1-03: capture count BEFORE take
                        let frame = MeshSyncFrame::Delta {
                            node: node_id.clone(),
                            sent_at_ms: sync::current_time_ms(),
                            last_db_version: batch_window.take_checkpoint(),
                            changes: std::mem::take(&mut staged_changes),
                        };
                        if out_tx.send(frame).await.is_ok() {
                            let _ = db_tx.send(SyncDbCmd::RecordSent {
                                peer: peer_name, count: send_count, version: batch_window.take_checkpoint()
                            });
                            batch_window.clear();
                        }
                    }
                }
                Err(_) => {
                    idle_ticks = idle_ticks.saturating_add(1);
                }
            }
        }
    });
}

fn resolve_peer_name(peers_conf_path: &std::path::Path, node: &str) -> String {
    let ip = node.split(':').next().unwrap_or(node);
    if let Ok(content) = std::fs::read_to_string(peers_conf_path) {
        let mut section_name: Option<String> = None;
        for line in content.lines().map(str::trim) {
            if line.starts_with('[') && line.ends_with(']') {
                section_name = Some(line[1..line.len() - 1].to_string());
            } else if let Some((key, value)) = line.split_once('=') {
                if key.trim() == "tailscale_ip" && value.trim() == ip {
                    if let Some(name) = &section_name {
                        return name.clone();
                    }
                }
            }
        }
    }
    node.to_string()
}

async fn maybe_ws_request_head(stream: &mut TcpStream) -> Option<String> {
    let mut probe = [0_u8; 2048];
    let peeked = tokio::time::timeout(Duration::from_millis(150), stream.peek(&mut probe))
        .await
        .ok()?
        .ok()?;
    if peeked == 0 {
        return None;
    }
    let head = String::from_utf8_lossy(&probe[..peeked]).to_string();
    if !is_ws_brain_request(&head) {
        return None;
    }
    let read = stream.read(&mut probe).await.ok()?;
    Some(String::from_utf8_lossy(&probe[..read]).to_string())
}
