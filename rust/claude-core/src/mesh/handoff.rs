use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PeerConfig {
    pub peer_name: String,
    pub ssh_alias: Option<String>,
    pub dns_name: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SyncSourceInfo {
    pub source: String,
    pub ssh_source: Option<String>,
    pub ssh_target: String,
    pub worktree: String,
    pub needs_stop: bool,
    pub needs_stash: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StaleHostStatus {
    pub stale: bool,
    pub reason: String,
    pub can_recover: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct DelegationLock {
    peer: String,
    ts: u64,
    pid: u32,
}

pub fn parse_peers_conf(content: &str) -> HashMap<String, PeerConfig> {
    let mut peers = HashMap::new();
    let mut current = String::new();
    for raw in content.lines() {
        let line = raw.split('#').next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        if line.starts_with('[') && line.ends_with(']') {
            current = line.trim_start_matches('[').trim_end_matches(']').to_string();
            peers.insert(
                current.clone(),
                PeerConfig { peer_name: current.clone(), ssh_alias: None, dns_name: None },
            );
            continue;
        }
        if let Some((k, v)) = line.split_once('=') {
            if let Some(peer) = peers.get_mut(&current) {
                match k.trim() {
                    "ssh_alias" => peer.ssh_alias = Some(v.trim().to_string()),
                    "dns_name" => peer.dns_name = Some(v.trim().to_string()),
                    _ => {}
                }
            }
        }
    }
    peers
}

pub fn detect_sync_source(
    target: &str,
    ssh_target: &str,
    local_hostname: &str,
    execution_host: &str,
    worktree: &str,
    plan_status: &str,
    in_progress_count: i64,
    peers: &HashMap<String, PeerConfig>,
) -> SyncSourceInfo {
    let host = execution_host.trim();
    if host.is_empty() || host.eq_ignore_ascii_case(local_hostname) || host.to_lowercase().starts_with(&local_hostname.to_lowercase()) {
        return SyncSourceInfo {
            source: "coordinator".to_string(),
            ssh_source: None,
            ssh_target: ssh_target.to_string(),
            worktree: worktree.to_string(),
            needs_stop: false,
            needs_stash: false,
        };
    }
    let target_peer = peers.get(target);
    let target_names = [Some(target.to_string()), target_peer.and_then(|p| p.ssh_alias.clone()), target_peer.and_then(|p| p.dns_name.clone())];
    if target_names.into_iter().flatten().any(|v| v.to_lowercase().contains(&host.to_lowercase())) {
        return SyncSourceInfo {
            source: "same_node".to_string(),
            ssh_source: Some(ssh_target.to_string()),
            ssh_target: ssh_target.to_string(),
            worktree: worktree.to_string(),
            needs_stop: false,
            needs_stash: false,
        };
    }
    let ssh_source = peers
        .iter()
        .find(|(_, p)| {
            [Some(p.peer_name.clone()), p.ssh_alias.clone(), p.dns_name.clone()]
                .into_iter()
                .flatten()
                .any(|name| name.to_lowercase().contains(&host.to_lowercase()))
        })
        .map(|(name, p)| p.ssh_alias.clone().unwrap_or_else(|| name.clone()));
    SyncSourceInfo {
        source: format!("worker:{host}"),
        ssh_source,
        ssh_target: ssh_target.to_string(),
        worktree: worktree.to_string(),
        needs_stop: plan_status == "doing" && in_progress_count > 0,
        needs_stash: true,
    }
}

pub fn resolve_cli_command(cli: &str, detections: &HashMap<String, String>) -> Option<String> {
    let map = HashMap::from([
        ("copilot", "copilot --yolo"),
        ("claude", "claude --dangerously-skip-permissions --model sonnet"),
        ("opencode", "opencode"),
    ]);
    let picked = detections.get(cli).cloned().unwrap_or_else(|| "MISSING".to_string());
    if picked != "MISSING" {
        return Some(if picked == "gh-copilot" { "gh copilot -p".to_string() } else { map.get(cli).unwrap_or(&cli).to_string() });
    }
    for fb in ["copilot", "claude", "opencode"] {
        let v = detections.get(fb).cloned().unwrap_or_else(|| "MISSING".to_string());
        if v != "MISSING" {
            return Some(if v == "gh-copilot" { "gh copilot -p".to_string() } else { map.get(fb).unwrap_or(&fb).to_string() });
        }
    }
    None
}

pub fn check_stale_host(now_ts: u64, last_seen: Option<u64>, stale_threshold: u64, ssh_reachable: bool) -> StaleHostStatus {
    if let Some(ts) = last_seen {
        let age = now_ts.saturating_sub(ts);
        if age < stale_threshold {
            return StaleHostStatus { stale: false, reason: format!("heartbeat {age}s ago"), can_recover: false };
        }
    }
    if ssh_reachable {
        StaleHostStatus { stale: true, reason: "heartbeat stale but SSH ok".to_string(), can_recover: true }
    } else {
        StaleHostStatus { stale: true, reason: "heartbeat stale and SSH unreachable".to_string(), can_recover: false }
    }
}

pub fn acquire_lock(lock_dir: &Path, plan_id: i64, peer: &str, ttl_secs: u64) -> Result<(), String> {
    fs::create_dir_all(lock_dir).map_err(|e| e.to_string())?;
    let lock_path = lock_dir.join(format!("delegate-{plan_id}.lock"));
    let now = SystemTime::now().duration_since(UNIX_EPOCH).map_err(|e| e.to_string())?.as_secs();
    if let Ok(raw) = fs::read_to_string(&lock_path) {
        if let Ok(existing) = serde_json::from_str::<DelegationLock>(&raw) {
            if now.saturating_sub(existing.ts) < ttl_secs {
                return Err(format!("locked by {} {}s ago", existing.peer, now.saturating_sub(existing.ts)));
            }
        }
    }
    let payload = DelegationLock { peer: peer.to_string(), ts: now, pid: std::process::id() };
    fs::write(lock_path, serde_json::to_string(&payload).map_err(|e| e.to_string())?).map_err(|e| e.to_string())
}

pub fn release_lock(lock_dir: &Path, plan_id: i64) -> Result<(), String> {
    let lock_path = lock_dir.join(format!("delegate-{plan_id}.lock"));
    if lock_path.exists() {
        fs::remove_file(lock_path).map_err(|e| e.to_string())?;
    }
    Ok(())
}

pub fn merge_plan_status(plan_id: i64, local_db: &Path, remote_db: &Path) -> Result<usize, String> {
    let remote = Connection::open(remote_db).map_err(|e| e.to_string())?;
    let local = Connection::open(local_db).map_err(|e| e.to_string())?;
    local.execute_batch("PRAGMA journal_mode=WAL;").map_err(|e| e.to_string())?;
    let rank = HashMap::from([("pending", 0), ("in_progress", 1), ("blocked", 1), ("submitted", 2), ("done", 3), ("skipped", 3)]);
    let mut updates = 0usize;
    let mut stmt = remote.prepare("SELECT id,status,completed_at,validated_at,validated_by FROM tasks WHERE plan_id=?1").map_err(|e| e.to_string())?;
    let rows = stmt.query_map([plan_id], |r| Ok((r.get::<_, i64>(0)?, r.get::<_, String>(1)?, r.get::<_, Option<String>>(2)?, r.get::<_, Option<String>>(3)?, r.get::<_, Option<String>>(4)?))).map_err(|e| e.to_string())?;
    for row in rows {
        let (task_id, r_status, completed_at, validated_at, validated_by) = row.map_err(|e| e.to_string())?;
        let local_status: Option<String> = local.query_row("SELECT status FROM tasks WHERE id=?1", [task_id], |rr| rr.get(0)).ok();
        let Some(l_status) = local_status else { continue };
        if rank.get(r_status.as_str()).unwrap_or(&0) <= rank.get(l_status.as_str()).unwrap_or(&0) {
            continue;
        }
        local.execute(
            "UPDATE tasks SET status=?1, completed_at=COALESCE(?2,completed_at), validated_at=COALESCE(?3,validated_at), validated_by=COALESCE(?4,validated_by) WHERE id=?5",
            params![r_status, completed_at, validated_at, if r_status == "done" { validated_by.or(Some("forced-admin".to_string())) } else { None }, task_id],
        ).map_err(|e| e.to_string())?;
        updates += 1;
    }
    local.execute("UPDATE waves SET tasks_done=(SELECT COUNT(*) FROM tasks WHERE wave_id_fk=waves.id AND status='done') WHERE plan_id=?1", [plan_id]).map_err(|e| e.to_string())?;
    local.execute("UPDATE plans SET tasks_done=(SELECT COUNT(*) FROM tasks WHERE plan_id=?1 AND status='done') WHERE id=?1", [plan_id]).map_err(|e| e.to_string())?;
    Ok(updates)
}

#[path = "handoff_ssh.rs"]
mod handoff_ssh;
pub use handoff_ssh::{pull_db_from_peer, SshClient};

#[cfg(test)]
#[path = "handoff_tests.rs"]
mod handoff_tests;
