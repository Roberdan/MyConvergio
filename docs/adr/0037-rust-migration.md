# ADR 0037: P4 Rust Migration

Status: Accepted | Date: 07 Mar 2026 | Plan: 100025

## Context
Python shell orchestration reached limits for concurrency, deterministic performance, and safe long-running services for mesh, API, and sync workflows.

## Decision
Migrate core runtime responsibilities to `rust/claude-core` (DB, hooks, lock, digest, mesh, server, and TUI) while preserving a controlled shell fallback during transition.

## Consequences
- Positive: Better performance, stronger typing, and more reliable concurrent behavior.
- Negative: Build complexity and dual-path maintenance increase during migration period.

## Enforcement
- Rule: `New core runtime features target claude-core first with explicit fallback policy`
- Check: `bash tests/test-T11-02-build-claude-core.sh && bash tests/test-T13-03-claude-core-integration.sh`
- Ref: ADR-0029, ADR-0030
