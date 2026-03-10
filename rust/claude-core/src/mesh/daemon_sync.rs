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

pub(super) async fn handle_socket(
    mut stream: TcpStream,
    conn_id: String,
    state: DaemonState,
    config: DaemonConfig,
) -> Result<(), String> {
    if let Some(head) = maybe_ws_request_head(&mut stream).await {
        return handle_ws_client(stream, &head, state).await;
    }
    let (mut read_half, mut write_half) = stream.into_split();
    let (out_tx, mut out_rx) = mpsc::channel::<MeshSyncFrame>(256);
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
    spawn_delta_loop(out_tx.clone(), sync_peer.clone(), state.node_id.clone(), config.clone());
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
            // Persist peer heartbeat to DB — resolve IP:port to peer name from peers.conf
            if let Ok(conn) = rusqlite::Connection::open(&config.db_path) {
                let peer_name = resolve_peer_name(&config.peers_conf_path, node);
                let _ = conn.execute(
                    "INSERT OR REPLACE INTO peer_heartbeats (peer_name, last_seen) VALUES (?1, ?2)",
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

fn spawn_delta_loop(
    out_tx: mpsc::Sender<MeshSyncFrame>,
    sync_peer: Arc<RwLock<String>>,
    node_id: String,
    config: DaemonConfig,
) {
    tokio::spawn(async move {
        let mut ticker = tokio::time::interval(Duration::from_secs(2));
        let mut db_cursor = 0_i64;
        let mut batch_window = sync::SyncBatchWindow::new(50);
        let mut staged_changes = Vec::new();
        loop {
            ticker.tick().await;
            let peer_name = sync_peer.read().await.clone();
            match sync::collect_changes_since(
                &config.db_path,
                config.crsqlite_path.as_deref(),
                db_cursor,
            ) {
                Ok((changes, checkpoint)) => {
                    if !changes.is_empty() {
                        db_cursor = checkpoint;
                        batch_window.observe_change(checkpoint);
                        staged_changes.extend(changes);
                    }
                    if !staged_changes.is_empty() && batch_window.should_flush(sync::current_time_ms()) {
                        let frame = MeshSyncFrame::Delta {
                            node: node_id.clone(),
                            sent_at_ms: sync::current_time_ms(),
                            last_db_version: batch_window.take_checkpoint(),
                            changes: std::mem::take(&mut staged_changes),
                        };
                        if sync::record_sent_stats(
                            &config.db_path,
                            config.crsqlite_path.as_deref(),
                            &peer_name,
                            match &frame { MeshSyncFrame::Delta { changes, .. } => changes.len(), _ => 0 },
                            batch_window.take_checkpoint(),
                        )
                        .is_ok()
                            && out_tx.send(frame).await.is_ok()
                        {
                            batch_window.clear();
                        }
                    }
                }
                Err(err) => {
                    let _ = sync::record_sync_error(
                        &config.db_path,
                        config.crsqlite_path.as_deref(),
                        &peer_name,
                        &err,
                    );
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
