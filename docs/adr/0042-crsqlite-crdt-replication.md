# ADR 0042: crsqlite CRDT Replication for Mesh DB Sync

Status: Accepted | Date: 10 Mar 2026 | Plan: none

## Context

Mesh nodes (m3max, omarchy, m1mario) needed real-time DB sync. Manual SSH-based copy was brittle and lost concurrent writes. Needed conflict-free multi-master replication on SQLite.

## Decision

Adopted cr-sqlite (crsqlite) v0.16.3 as SQLite extension for Conflict-free Replicated Relations. Tables marked with `crsql_as_crr()`. Each node gets unique `site_id`. Daemon syncs deltas via TCP on port 9420 over Tailscale. Only local-origin changes are sent (site_id filter prevents re-broadcast loops).

## Consequences

- Positive: True multi-master replication, sub-second convergence, no central coordinator needed
- Negative: Tables cannot use AUTOINCREMENT, all NOT NULL cols need DEFAULT, ~204K change vectors on initial migration

## Enforcement

- Rule: `grep -r "AUTOINCREMENT" rust/claude-core/src/db/` must return 0
- Check: `sqlite3 data/dashboard.db "SELECT COUNT(*) FROM crsql_changes;" | grep -v '^0$'`
- Ref: ADR 0037 (Rust migration)
