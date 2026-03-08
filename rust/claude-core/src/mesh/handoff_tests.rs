use super::{PeerConfig, SyncSourceInfo};
use std::collections::HashMap;

#[test]
fn detect_sync_source_marks_same_node_when_execution_host_matches_target_alias() {
    let mut peers = HashMap::new();
    peers.insert(
        "node-b".to_string(),
        PeerConfig {
            peer_name: "node-b".to_string(),
            ssh_alias: Some("ubuntu@100.88.1.2".to_string()),
            dns_name: Some("node-b.local".to_string()),
        },
    );
    let info = super::detect_sync_source(
        "node-b",
        "ubuntu@100.88.1.2",
        "node-a",
        "node-b.local",
        "/tmp/worktree",
        "doing",
        1,
        &peers,
    );
    assert_eq!(
        info,
        SyncSourceInfo {
            source: "same_node".to_string(),
            ssh_source: Some("ubuntu@100.88.1.2".to_string()),
            ssh_target: "ubuntu@100.88.1.2".to_string(),
            worktree: "/tmp/worktree".to_string(),
            needs_stop: false,
            needs_stash: false,
        }
    );
}

#[test]
fn resolve_cli_prefers_primary_then_fallbacks() {
    let preferred = super::resolve_cli_command(
        "copilot",
        &HashMap::from([
            ("copilot".to_string(), "MISSING".to_string()),
            ("claude".to_string(), "claude".to_string()),
        ]),
    );
    assert_eq!(
        preferred,
        Some("claude --dangerously-skip-permissions --model sonnet".to_string())
    );
}

#[test]
fn stale_host_requires_heartbeat_age_or_ssh_reachability() {
    let stale = super::check_stale_host(1_000, Some(120), 10, true);
    assert!(stale.stale);
    assert!(stale.can_recover);
    assert_eq!(stale.reason, "heartbeat stale but SSH ok");
}
