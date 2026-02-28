# ADR-0005: Multi-Agent Concurrency Control

Status: Accepted | Date: 09 Febbraio 2026

## Context

When multiple executor agents work in parallel on the same codebase (different worktrees, same plan), they frequently overwrite each other's changes. Conflicts were discovered at merge time — after work was done — causing repeated rework. Three failure modes: (1) two tasks in the same wave touch the same file, (2) merge order causes conflicts that didn't exist before, (3) an agent reads a file that another agent modifies before commit.

## Decision

### Four-Layer Prevention System

**Layer 1 — Planning: Wave Overlap Detection** (`wave-overlap.sh`)
Before importing a spec.json, analyzes `files[]` declarations per task within each wave. Tasks sharing files in the same parallel wave are flagged: `warning` (1-2 shared files), `critical` (3+). Planner must reorganize tasks into sequential waves before import proceeds.

**Layer 2 — Execution: File-Level Locking** (`file-lock.sh`)
SQLite-based advisory locks with atomic INSERT (UNIQUE constraint on file_path). Each executor acquires locks on target files before modification. Blocked if another agent holds the lock. Stale lock detection via PID liveness check + heartbeat expiry (5 min heartbeat, 30 min max age). Auto-release on task completion via `plan-db-safe.sh`.

**Layer 3 — Execution: Stale Context Detection** (`stale-check.sh`)
At task start, records SHA-256 hashes of all files the agent reads. Before commit, compares current hashes against recorded baseline. If any file changed externally (another agent merged, rebase occurred), blocks the commit and requires the agent to re-read and re-verify.

**Layer 4 — Merge: Sequential Queue** (`merge-queue.sh`)
FIFO queue with priority support. Branches are enqueued after task completion. `flock` ensures only one merge process runs at a time. Optional `--validate` runs post-merge typecheck; on failure, automatically reverts the merge and marks the branch as failed. Dry-run mode available for conflict prediction.

### Database Schema

Three new tables in `dashboard.db` (migration: `migrate-v5-concurrency.sh`):

| Table            | Purpose             | Key columns                                                      |
| ---------------- | ------------------- | ---------------------------------------------------------------- |
| `file_locks`     | Active file locks   | file_path (UNIQUE), task_id, session_id, pid, host, heartbeat_at |
| `file_snapshots` | File hash baselines | task_id+file_path (UNIQUE), file_hash, branch                    |
| `merge_queue`    | Merge queue state   | branch (UNIQUE), status, priority, result/error                  |

### Integration Points

- `plan-db.sh` exposes all four as sub-commands: `lock`, `stale-check`, `wave-overlap`, `merge-queue`
- `plan-db-safe.sh` auto-checks staleness and releases locks when marking task done
- `task-executor.md` has new mandatory phases: Phase 0.5 (lock+snapshot) and Phase 4.7 (stale check)

### Layer 5 — Session-Based File Locking (Non-Plan Workflow)

Added 19 Feb 2026. When agents work outside formal plans (teams, parallel sessions, ad-hoc), automatic hook-based file locking prevents concurrent edits. PreToolUse hooks on `Edit|Write|MultiEdit` acquire session locks via `file-lock.sh acquire-session`. Stop/sessionEnd hooks auto-release. Re-entrant (same session can edit same file repeatedly). Cross-platform: Claude Code + Copilot CLI. Opt-out: `CLAUDE_FILE_LOCK=0`. Migration: `migrate-v6-session-locks.sh` adds `session_id` column to `file_locks`.

**See ADR-0016** for detailed session-based locking architecture, performance benchmarks, and cross-platform hook integration patterns.

## Consequences

- Positive: Conflicts detected before work starts (planning) or before commit (execution), not at merge. Eliminates repeated rework from overwrites. File locks are atomic (SQLite UNIQUE constraint). Stale detection catches external changes. Merge queue prevents merge-order conflicts.
- Negative: ~1-2s overhead per task lifecycle (negligible on 2-10 min tasks). Agents must declare target files upfront in spec.json `files[]`. Stale lock recovery depends on PID liveness (cross-host PIDs cannot be validated).

## Enforcement

- Rule: `plan-db-safe.sh` blocks task completion if staleness detected
- Check: `wave-overlap.sh check-spec spec.json` (exit 2 = critical overlap)
- Check: `file-lock.sh check <file>` (returns lock holder info)
- Ref: ADR-0004 (distributed execution), ADR-0002 (inter-wave communication)

## File Impact

| File                                            | Change                                         |
| ----------------------------------------------- | ---------------------------------------------- |
| `scripts/file-lock.sh`                          | New — file-level locking with SQLite backend   |
| `scripts/stale-check.sh`                        | New — SHA-256 snapshot and comparison          |
| `scripts/wave-overlap.sh`                       | New — intra-wave file overlap detection        |
| `scripts/merge-queue.sh`                        | New — FIFO merge queue with flock + validation |
| `scripts/migrate-v5-concurrency.sh`             | New — DB migration for 3 tables                |
| `scripts/plan-db.sh`                            | Added 4 sub-command delegations                |
| `scripts/plan-db-safe.sh`                       | Added stale check + auto lock release          |
| `agents/technical_development/task-executor.md` | Added Phase 0.5 and 4.7                        |
| `CLAUDE.md`                                     | Added Concurrency Control section              |
| `scripts/file-lock-session.sh`                  | New — session-based acquire/release commands   |
| `scripts/file-lock-utils.sh`                    | New — list/cleanup (split from file-lock.sh)   |
| `scripts/migrate-v6-session-locks.sh`           | New — adds session_id column to file_locks     |
| `hooks/session-file-lock.sh`                    | New — Claude Code PreToolUse lock hook         |
| `hooks/session-file-unlock.sh`                  | New — Claude Code Stop unlock hook             |
| `hooks/lib/file-lock-common.sh`                 | New — shared lock utilities for both platforms |
| `copilot-config/hooks/session-file-lock.sh`     | New — Copilot CLI preToolUse lock hook         |
| `copilot-config/hooks/session-file-unlock.sh`   | New — Copilot CLI sessionEnd unlock hook       |
