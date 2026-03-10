# ADR 0043: Delta Sync Backoff Strategy

Status: Accepted | Date: 10 Mar 2026 | Plan: none

## Context

CRDT daemon polled `crsql_changes` every 10ms causing 300%+ CPU and 11GB RAM on m3max. Each poll opened new connection + loaded crsqlite extension. With 204K change vectors, this was a hot spin loop. Even 2s fixed interval was wasteful when idle.

## Decision

Three-layer fix: (1) Initialize `db_cursor` at current max `db_version` on startup — skip historical changes already synced via DB copy. (2) Filter by local `site_id` — only send own writes, not re-broadcast received changes. (3) Exponential backoff when idle: 2s base, doubles each idle tick, capped at 30s. Resets to 2s on new changes. LIMIT 1000 per batch.

## Consequences

- Positive: CPU dropped from 123% to 0.0% (m3max), 37% to 0.3% (omarchy). Memory stable.
- Negative: Max 30s latency for idle-to-active transition (acceptable for non-real-time sync)

## Enforcement

- Rule: `grep "from_millis" rust/claude-core/src/mesh/daemon_sync.rs` must return 0
- Check: `ps aux | grep 'claude-core daemon' | awk '{if ($3 > 10) exit 1}'`
- Ref: ADR 0042 (crsqlite)
