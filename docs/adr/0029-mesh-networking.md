# ADR 0029: Mesh Networking Architecture

**Status**: Accepted
**Date**: 2026-03-01
**Refs**: ADR-0004 (distributed execution), ADR-0010 (multi-provider orchestration), ADR-0025 (tiered model strategy)

## Context

ADR-0004 introduced 2-machine hub-spoke execution (Mac coordinator + Linux executor via `REMOTE_HOST`). As the peer count grows beyond 2, hub-spoke creates single points of failure and cannot leverage zero-cost Ollama peers or privacy-safe routing. A flat P2P mesh enables any machine to join without reconfiguring the hub.

## Decision

**Topology**: N-machine P2P mesh, any peer can be coordinator.

| Component               | Purpose                                                                                                        |
| ----------------------- | -------------------------------------------------------------------------------------------------------------- |
| `peers.conf`            | Flat peer registry: hostname, transport (SSH/Tailscale), cost_tier, privacy_safe                               |
| `peer_heartbeats` table | Liveness detection per peer (60s interval, 5-min stale window)                                                 |
| `orchestrator.yaml`     | Per-task routing rules: cost_tier filter, privacy_safe filter, capability match                                |
| `opencode-worker.sh`    | OpenCode/Ollama engine on GPU peers — zero-cost, fully local                                                   |
| Floating coordinator    | Any ALIVE peer with lowest task queue depth claims coordinator role via `UPDATE ... WHERE coordinator IS NULL` |
| Claim-based failover    | Coordinator STALE → any peer re-claims within one heartbeat cycle                                              |

**Transport**: SSH (LAN) or Tailscale (WAN). Peer discovery via `peers.conf`; no central server.

**Routing**: `delegate.sh` reads `orchestrator.yaml` cost_tier/privacy_safe to route tasks. Ollama peers (`cost_tier: free`, `privacy_safe: true`) absorb chore/doc/test tasks (effort ≤ 2). Claude/GPT peers handle architecture and planning (effort ≥ 3).

**Backward compat**: `REMOTE_HOST` env var continues to work as single-peer shorthand.

## Consequences

- Any machine joins with 3 commands: install peers.conf entry, run heartbeat daemon, configure opencode-worker.sh
- Ollama peers enable zero-cost + zero-privacy-risk execution for routine tasks
- Coordinator failover is automatic; no manual intervention on peer loss
- `peers.conf` is the single source of truth; replaces hardcoded `REMOTE_HOST` for multi-peer setups
- Mesh sync still uses `sync-dashboard-db.sh` incremental protocol from ADR-0004 (no change)
- SQLite `peer_heartbeats` table scales to ~50 peers without schema changes
