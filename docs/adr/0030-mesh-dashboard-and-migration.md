# ADR 0030: Mesh Dashboard Visualization + Live Plan Migration

Status: Accepted | Date: 02 Mar 2026 | Plans: 300, 301

## Context

Mesh network (ADR-0029) had no visibility into node status or workload. Plans executed on remote peers required manual sync. Need: terminal UI for mesh monitoring + single-command plan migration between machines.

## Decision

**Plan 300 — Mesh Dashboard Viz**: htop-style terminal visualization in mini dashboard. Mini-preview in overview + full detail via `M` key. Health colors (green/yellow/red/gray), CPU bars, capability badges, dispatch animation.

**Plan 301 — Live Plan Migration**: `mesh-migrate.sh <plan_id> <peer>` — rsync full-folder (not git-only) + DB atomic migration + auto-launch on target via tmux. Plan 301 itself was executed remotely on m1mario as proof-of-concept.

## Consequences

- Positive: `piani` shows mesh status at a glance; plan handoff in one command
- Negative: DB sync still pull-based (no auto-push from workers); rsync requires SSH keys pre-configured
- Risk: DB corruption on cross-machine copy — mitigated by WAL checkpoint + integrity check

## Enforcement

- Check: `bash tests/test-mesh-dashboard.sh && bash tests/test-mesh-migrate.sh`
- Ref: ADR-0029 (mesh networking), ADR-0004 (distributed execution)
