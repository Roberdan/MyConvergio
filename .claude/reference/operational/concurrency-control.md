<!-- v3.1.0 | 27 Feb 2026 | Added WorktreeCreate/WorktreeRemove hooks section -->

# Concurrency Control

> **Why**: Multi-agent file edits cause silent overwrites. File locking prevents data loss. Stale checks detect external changes before commit. Merge queue prevents race conditions.

## Plan-Based Parallel Work

1. **Planner**: `wave-overlap.sh check-spec spec.json` before import (blocks critical overlap)
2. **Executor start**: `file-lock.sh acquire <file> <task_id>` for each target file
3. **Executor start**: `stale-check.sh snapshot <task_id> <files...>` to record baseline
4. **Before commit**: `stale-check.sh check <task_id>` (BLOCKS if files changed externally)
5. **On task done**: `plan-db-safe.sh` auto-releases locks + checks staleness
6. **Merge**: `merge-queue.sh enqueue <branch>` then `merge-queue.sh process --validate`

## Session-Based File Locking (Non-Plan Workflow)

When agents work outside the formal plan workflow (teams, parallel sessions, ad-hoc multi-agent), file locking is handled **automatically via hooks** on both Claude Code and Copilot CLI.

### How It Works

1. **PreToolUse** hook on `Edit|Write|MultiEdit` calls `file-lock.sh acquire-session`
2. Lock keyed on `session_id` (from hook JSON input), not `task_id`
3. **Re-entrant**: same session editing same file succeeds (heartbeat refreshed)
4. **Blocking**: different session editing locked file → hook blocks the edit (exit 2 / `permissionDecision: deny`)
5. **Auto-release**: Stop/sessionEnd hook calls `file-lock.sh release-session` on session end
6. **Stale detection**: PID dead + heartbeat > 5 min = auto-break (same as plan locks)

### Commands

```bash
file-lock.sh acquire-session <file> <session_id> [agent] [timeout_sec]
file-lock.sh release-session <session_id>
file-lock.sh list --session-id <session_id>
```

### Coexistence with Plan Locks

Both use `file_locks` table. Plan locks use `task_id`, session locks use `session_id`. A file locked by either mechanism blocks all other agents. Single source of truth, single UNIQUE constraint on `file_path`.

### Opt-Out

Set `CLAUDE_FILE_LOCK=0` in env to disable session locking entirely.

### Files

| File                                          | Platform    | Purpose                         |
| --------------------------------------------- | ----------- | ------------------------------- |
| `hooks/session-file-lock.sh`                  | Claude Code | PreToolUse: acquire lock        |
| `hooks/session-file-unlock.sh`                | Claude Code | Stop: release locks             |
| `copilot-config/hooks/session-file-lock.sh`   | Copilot CLI | preToolUse: acquire lock        |
| `copilot-config/hooks/session-file-unlock.sh` | Copilot CLI | sessionEnd: release locks       |
| `hooks/lib/file-lock-common.sh`               | Shared      | Common lock utilities           |
| `scripts/file-lock-session.sh`                | Shared      | acquire-session/release-session |

## WorktreeCreate/WorktreeRemove Hooks (v2.1.50+)

Hooks run automatically on worktree lifecycle events (native git or `wave-worktree.sh`). Eliminates ~500 tokens/worktree of manual setup commands.

### WorktreeCreate Hook

Runs after any worktree creation:

1. Auto-symlinks all `.env*` files from main repo into the new worktree
2. Runs `npm install` if `package.json` is present
3. Configured in `settings.json` as a `PostWorktreeAdd` hook

### WorktreeRemove Hook

Runs before worktree removal:

1. Releases file locks for the worktree session (`file-lock.sh release-session`)
2. Cleans up temp files created during the worktree's lifetime

### Files

| File                       | Purpose                                      |
| -------------------------- | -------------------------------------------- |
| `hooks/worktree-create.sh` | PostWorktreeAdd: .env symlinks + npm install |
| `hooks/worktree-remove.sh` | PreWorktreeRemove: release locks + cleanup   |

Both hooks are configured in `settings.json` under the `hooks` key.

## Violations

- **Direct merge without queue = VIOLATION.** Only `merge-queue.sh process` merges to main.
- Skipping file-lock on shared files = risk of silent overwrite.
- Committing without stale-check = risk of overwriting other agent's work.
