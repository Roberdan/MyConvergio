# ADR 0040: Post-Migration Stabilization Protocol

**Status**: Accepted | **Date**: 08 Mar 2026

## Context
Plan 100025 (Python→Rust) left gaps: API response shapes didn't match JS render expectations, tables missing from init-db.sql, no structured logging. Result: full day of debugging.

## Decision
1. `init-db.sql` is the **sole schema source of truth** — every table must be defined there
2. Rust `ServerState::new()` runs per-statement migration as **fallback** with verification
3. All migrations require **real-server E2E tests** (not mocked) — `real-server.spec.ts`
4. `claude-core` uses `tracing` crate → `~/.claude/logs/claude-core.log`
5. `/api/health` endpoint validates DB state on every deploy

## Consequences
- Future migrations follow `rules/migration-checklist.md`
- Schema changes go to `init-db.sql` first, Rust migration second
- Playwright tests include both mocked (unit) and real-server (integration) suites
