# ADR 0016: Session-Based File Locking

Status: Accepted | Date: 19 Feb 2026 | Extends: ADR-0005 Layer 5

## Context

ADR-0005 Layer 5 introduced session-based file locking for non-plan workflows (teams, parallel sessions, ad-hoc tasks). When multiple agents work concurrently outside formal plans, they need protection against concurrent edits. Plan-based locking (Layer 2) only covers formal task execution; session-based locking covers all file modifications.

Without session locks, two agents can simultaneously edit the same file through different IDE sessions, causing lost edits, merge conflicts, or corrupted state. This affects both Claude Code (MCP hooks) and Copilot CLI (agent hooks).

## Decision

### Automatic Hook-Based File Locking

All file modifications (`Edit`, `Write`, `MultiEdit` tools) automatically acquire session-level locks before proceeding. Implementation uses PreToolUse hooks that intercept file operations and invoke `file-lock.sh acquire-session`.

**Lock Lifecycle:**
- **Acquire**: PreToolUse hook detects file write → `file-lock.sh acquire-session <file> <session_id>` → blocks if locked by different session
- **Release**: Stop/sessionEnd hook → `file-lock.sh release-session <session_id>` → frees all locks for that session
- **Re-entrant**: Same session can edit same file repeatedly without blocking

**Platform Support:**
- **Claude Code**: MCP server hooks (`hooks/session-file-lock.sh`, `hooks/session-file-unlock.sh`)
- **Copilot CLI**: Agent hooks (`copilot-config/hooks/session-file-lock.sh`, `copilot-config/hooks/session-file-unlock.sh`)

**Database Schema (file_locks table):**

| Column       | Type    | Purpose                                    |
|--------------|---------|--------------------------------------------|
| file_path    | TEXT    | Absolute path (UNIQUE key)                 |
| session_id   | TEXT    | Session identifier (NULL for plan locks)   |
| task_id      | TEXT    | Task ID (NULL for session locks)           |
| pid          | INTEGER | Process ID for liveness checks             |
| host         | TEXT    | Hostname for distributed systems           |
| heartbeat_at | INTEGER | Last heartbeat timestamp (Unix epoch)      |
| created_at   | INTEGER | Lock creation timestamp                    |

**Lock Types:**
- **Plan lock**: task_id NOT NULL, session_id NULL (Layer 2, ADR-0005)
- **Session lock**: session_id NOT NULL, task_id NULL (Layer 5, this ADR)

### Conflict Resolution

**Same File, Different Sessions:**
- Agent A edits `file.txt` → lock acquired (session=A)
- Agent B attempts edit `file.txt` → **BLOCKED** (lock held by session A)
- Agent B waits or aborts; lock released when Agent A stops/ends session

**Same File, Same Session:**
- Agent A edits `file.txt` (session=A) → lock acquired
- Agent A edits `file.txt` again (session=A) → **ALLOWED** (re-entrant)

**Stale Lock Recovery:**
- PID liveness check: if PID no longer exists → auto-release lock
- Heartbeat expiry: if no heartbeat for 30 minutes → lock considered stale
- Manual cleanup: `file-lock.sh cleanup-stale` removes expired locks

### Opt-Out Mechanism

Set environment variable `CLAUDE_FILE_LOCK=0` to disable session-based locking. Useful for:
- Single-agent environments (no concurrency risk)
- Debugging hook issues
- Emergency override during incidents

Default: enabled (`CLAUDE_FILE_LOCK=1`).

## Consequences

- **Positive**: Prevents concurrent edit conflicts in non-plan workflows. Zero configuration required (automatic). Works across Claude Code and Copilot CLI. Re-entrant locks allow natural editing flow. Stale lock recovery prevents deadlocks.
- **Negative**: ~100-300ms overhead per file edit (SQLite lock check). Requires session_id column in file_locks table (migrate-v6-session-locks.sh). Cross-host PID checks are unreliable (cannot verify remote PIDs).

## Enforcement

- Rule: All file write operations must go through lock-aware hooks (no direct edit bypass)
- Check: `file-lock.sh list-session <session_id>` shows all locks held by session
- Check: `file-lock.sh check <file>` returns lock holder info (session or task)
- Migration: `migrate-v6-session-locks.sh` adds session_id column to file_locks table

## File Impact

| File                                            | Change                                           |
|-------------------------------------------------|--------------------------------------------------|
| `scripts/file-lock.sh`                          | Added acquire-session, release-session commands  |
| `scripts/file-lock-session.sh`                  | New — session-specific lock/unlock logic         |
| `scripts/file-lock-utils.sh`                    | New — list/cleanup utilities                     |
| `scripts/migrate-v6-session-locks.sh`           | New — DB migration for session_id column         |
| `hooks/session-file-lock.sh`                    | New — Claude Code PreToolUse lock hook           |
| `hooks/session-file-unlock.sh`                  | New — Claude Code Stop unlock hook               |
| `hooks/lib/file-lock-common.sh`                 | New — shared utilities for both platforms        |
| `copilot-config/hooks/session-file-lock.sh`     | New — Copilot CLI preToolUse lock hook           |
| `copilot-config/hooks/session-file-unlock.sh`   | New — Copilot CLI sessionEnd unlock hook         |
| `dashboard.db`                                  | Modified — file_locks table schema upgrade       |

## Related ADRs

- ADR-0005: Multi-Agent Concurrency Control (Layer 1-4, plan-based locking)
- ADR-0004: Distributed Plan Execution (worktree isolation)
- ADR-0006: System Stability Crash Prevention (PID-based liveness)
