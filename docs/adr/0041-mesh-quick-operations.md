# ADR 0041: Mesh Quick Operations Scripts

Status: Accepted | Date: 09 Mar 2026 | Plan: 384

## Context

During Plan 384 (nightly jobs redesign), executing tasks across mesh nodes (m3max, omarchy, m1mario) exposed 5 operational gaps: no quick sync command, gh auth not persisting across SSH sessions, no remote task execution script, DB migrations not applied on sync, no post-sync health check. Legacy sync scripts existed in `scripts/archive/legacy-sync/` but were archived and disconnected from active workflow.

## Decision

Created 4 lightweight scripts using existing `lib/peers.sh` infrastructure:
- `mesh-sync.sh` — git sync + migrations + cleanup (≤100 lines)
- `mesh-exec.sh` — run copilot/claude on remote peer (≤60 lines)
- `mesh-health.sh` — compact health table for all nodes (≤70 lines)
- `apply-migrations.sh` — standalone DB migration from state.rs (≤25 lines)

Added `gh_account` field to peers.conf for auth persistence across SSH sessions.

## Consequences

- Positive: sync all nodes in one command, auth handled automatically, health visible at a glance
- Positive: works with both Claude Code and Copilot CLI (tool-agnostic)
- Negative: mesh-sync.sh uses direct git push as fallback (bypasses GitHub remote if peer can't fetch)
- Negative: apply-migrations.sh parses state.rs with grep (fragile if Rust format changes)

## Enforcement

- Rule: `rules/migration-checklist.md` requires `mesh-sync.sh` + `mesh-health.sh` post-migration
- Check: `bash scripts/mesh-health.sh` — all nodes show ✓ on COMMIT column
- Ref: ADR-0030 (mesh dashboard), ADR-0037 (Rust migration)
