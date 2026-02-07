# ADR 0004: Distributed Plan Execution

**Status**: Accepted
**Date**: 07 February 2026
**Decision makers**: roberdan

## Context

Plan execution happens on two machines: Mac (master, plan creation) and Linux
(omarchy-ts, execution via Tailscale SSH). Before this change, plans had no
concept of "which machine is executing" — causing conflicts when both machines
worked on the same plan, and no visibility into cross-machine state.

Token usage tracking also lacked host attribution, making it impossible to
understand cost distribution across machines.

## Decision

### Plan-Level Distribution with Atomic Claim Protocol

- Plans are the unit of distribution (not waves or tasks)
- `plans.execution_host` tracks which machine owns execution
- Atomic claim via `UPDATE ... WHERE execution_host IS NULL` prevents conflicts
- `--force` flag allows override when needed
- `cmd_complete` enforces worktree merge before plan closure

### SSH-Based Sync Architecture

- No shared filesystem or central server required
- `sync-dashboard-db.sh` handles push/pull/incremental/copy-plan
- `plan-db-autosync.sh` daemon: watches DB mtime, debounces 5s, syncs changed rows
- Heartbeat every 60s to `host_heartbeats` table for liveness detection
- Config sync (`~/.claude` git repo) runs after each DB sync

### CLI Visibility Commands

- `where` — Shows execution host per plan with liveness (LOCAL/ALIVE/STALE/UNREACHABLE)
- `cluster-status` — Merged local+remote plan view
- `cluster-tasks` — In-progress tasks across machines
- `remote-status` — SSH proxy to remote plan-db.sh status
- `token-report` — Per-project cost aggregation by host

### Hostname Normalization

- All hostname resolution uses `hostname -s` and strips `.local` suffix
- Prevents macOS `.local` mismatch with stored DB values
- Applied consistently in: plan-db-core.sh, migration scripts, token hooks

## Consequences

### Positive

- Clear ownership prevents execution conflicts
- Cross-machine visibility without leaving CLI
- Token costs attributable per machine
- Autosync keeps DBs in near-real-time agreement
- Config sync ensures both machines have identical tooling

### Negative

- SSH dependency: remote commands fail when network is down (graceful fallback)
- Hostname changes require DB update (mitigated by normalization)
- Incremental sync uses row-level INSERT OR REPLACE (no conflict resolution)

### Risks

- `.dump` for token_usage sync sends full table (scales poorly at >100K rows)
- Heartbeat-based liveness has 5-minute staleness window

## File Impact

| File                          | Change                                                  |
| ----------------------------- | ------------------------------------------------------- |
| `plan-db-core.sh`             | Hostname normalization, db_query(), SSH helpers         |
| `plan-db-cluster.sh`          | claim/release/heartbeat/is_alive                        |
| `plan-db-remote.sh`           | remote-status/cluster-status/cluster-tasks/token-report |
| `plan-db-autosync.sh`         | Background sync daemon                                  |
| `sync-dashboard-db.sh`        | Incremental sync, token sync                            |
| `plan-db-crud.sh`             | --description flag, cmd_where liveness                  |
| `plan-db-display.sh`          | Host/desc/branch in status+kanban                       |
| `migrate-v5-cluster.sh`       | Schema migration for cluster columns                    |
| `hooks/track-tokens.sh`       | execution_host in token writes                          |
| `hooks/session-end-tokens.sh` | execution_host in token writes                          |
