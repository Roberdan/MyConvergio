<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Plan & DB Scripts

> **Why**: `plan-db.sh` wraps SQLite with correct FK handling (`wave_id_fk` numeric FK, not `wave_id` string). Direct SQL risks schema violations.

## Database Conventions

- Tasks use `wave_id_fk` (numeric FK), NOT `wave_id` string
- Use `plan-db.sh` for all DB operations (handles FK correctly)
- **NEVER invent column names**. Schema: see `PLANNER-ARCHITECTURE.md`
- **NEVER invent subcommands**. Use ONLY the commands listed below. Run `plan-db.sh` with no args to see help.

## Valid Statuses (NEVER invent values)

| Entity | Valid statuses                                                 |
| ------ | -------------------------------------------------------------- |
| Task   | `pending` \| `in_progress` \| `done` \| `blocked` \| `skipped` |
| Plan   | `todo` \| `doing` \| `done` \| `archived`                      |
| Wave   | `pending` \| `in_progress` \| `done` \| `blocked`              |

## Plan Management

```bash
plan-db.sh create {project} "Name" --source-file {prompt.md} --auto-worktree --human-summary "2-3 righe leggibili che spiegano il piano"
plan-db.sh update-summary {plan_id} "Aggiorna il summary leggibile"
plan-db.sh import {plan_id} spec.json
plan-db-safe.sh update-task {id} done "Summary" # ALWAYS use safe wrapper for done
# plan-db-safe.sh auto: validate-task + validate-wave + complete plan
plan-db.sh conflict-check {id}            # Cross-plan file overlap detection
plan-db.sh conflict-check-spec {proj} spec.json # Pre-import conflict check
plan-db.sh wave-overlap check-spec spec.json    # Intra-wave overlap detection
plan-db.sh validate-task {task_id} {plan}  # Per-task Thor validation
plan-db.sh validate-wave {wave_db_id}     # Per-wave Thor validation
plan-db.sh validate {id}                  # Bulk Thor validation (all done tasks)
```

## Troubleshooting: `complete` Fails (N/M tasks done)

```bash
# DB path: ~/.claude/data/dashboard.db
# Step 1: Find incomplete tasks (ALWAYS use plan_id column, NOT wave joins)
sqlite3 ~/.claude/data/dashboard.db "SELECT id, task_id, title, status FROM tasks WHERE plan_id = {PLAN_ID} AND status NOT IN ('done', 'validated', 'skipped');"
# Step 2: Update each task
plan-db-safe.sh update-task {TASK_DB_ID} done "Reason"
# Step 3: Complete
plan-db.sh complete {PLAN_ID}
```

**DO NOT**: Try `plan-db.sh json` (no tasks), guess DB paths, guess column names. **READ THIS FIRST.**

## Cluster & Sync

```bash
plan-db.sh cluster-status          # Unified local+remote plan view
plan-db.sh remote-status           # SSH status from remote host
plan-db.sh token-report            # Per-project token/cost by host
plan-db.sh autosync start|stop|status # Background DB sync daemon
```

## File Locking & Staleness

```bash
# File-level locking (via file-lock.sh)
file-lock.sh acquire <file> <task_id> [--agent NAME] [--plan-id N] [--timeout N]
file-lock.sh release <file> [task_id]
file-lock.sh release-task <task_id>   # Release all locks for a task
file-lock.sh check <file>              # Who holds the lock?
file-lock.sh list [--plan-id N] [--task-id ID]
file-lock.sh cleanup [--max-age MIN] [--dry-run]

# Stale context detection
plan-db.sh stale-check snapshot|check|diff  # Stale context detection
plan-db.sh merge-queue enqueue|process|status # Sequential merge queue
```

## Bootstrap

```bash
planner-init.sh                    # Single-call project context bootstrap
service-digest.sh ci|pr|deploy|all # Token-efficient external service status
worktree-cleanup.sh --all-merged   # Auto-remove merged worktrees
copilot-sync.sh status|sync        # Copilot CLI alignment check/fix
```

## Dashboard

- **URL**: http://localhost:31415 | **DB**: ~/.claude/data/dashboard.db
- **Reboot**: `cd ~/.claude/dashboard && node reboot.js`
- **Sync**: `dbsync status|pull|push|incremental` (multi-machine)
