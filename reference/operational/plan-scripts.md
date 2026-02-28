<!-- v3.0.0 | 28 Feb 2026 | submitted status, Thor-only done, SQLite trigger -->

# Plan & DB Scripts

> **Why**: `plan-db.sh` wraps SQLite with correct FK handling (`wave_id_fk` numeric FK, not `wave_id` string). Direct SQL risks schema violations.

## Database Conventions

- Tasks use `wave_id_fk` (numeric FK), NOT `wave_id` string
- Use `plan-db.sh` for all DB operations (handles FK correctly)
- **NEVER invent column names**. Schema: see `PLANNER-ARCHITECTURE.md`
- **NEVER invent subcommands**. Use ONLY the commands listed below. Run `plan-db.sh` with no args to see help.

## Task Status Flow (NON-NEGOTIABLE — v5.0.0)

```
pending → in_progress → submitted (plan-db-safe.sh) → done (ONLY Thor validate-task)
                              ↓ Thor rejects
                         in_progress (fix and resubmit)
```

**SQLite trigger `enforce_thor_done`** blocks ANY attempt to set `status='done'` without:

1. Previous status = `submitted`
2. `validated_by` IN (`thor`, `thor-quality-assurance-guardian`, `thor-per-wave`, `forced-admin`)

Even raw `sqlite3` commands are blocked. This is platform-agnostic enforcement.

## Mandatory Plan Creation (NON-NEGOTIABLE)

NEVER create plans without `/planner` skill (Claude: `Skill(skill="planner")`, Copilot: `@planner`). EnterPlanMode = no DB registration = VIOLATION. _Why: Plan 225._

## Valid Statuses (NEVER invent values)

| Entity | Valid statuses                                                                               |
| ------ | -------------------------------------------------------------------------------------------- |
| Task   | `pending` \| `in_progress` \| `submitted` \| `done` \| `blocked` \| `skipped` \| `cancelled` |
| Plan   | `todo` \| `doing` \| `done` \| `archived` \| `cancelled`                                     |
| Wave   | `pending` \| `in_progress` \| `done` \| `blocked` \| `merging` \| `cancelled`                |

## Plan Management

```bash
plan-db.sh create {project} "Name" --source-file {prompt.md} --auto-worktree --human-summary "2-3 righe leggibili"
plan-db.sh update-summary {plan_id} "Aggiorna il summary leggibile"
plan-db.sh import {plan_id} spec.yaml  # also accepts spec.json
plan-db-safe.sh update-task {id} done "Summary" # Sets 'submitted' (NOT done). Thor required.
# plan-db-safe.sh auto: pending→in_progress (if needed) + proof-of-work + submitted
plan-db.sh validate-task {task_id} {plan} thor  # Thor ONLY: submitted → done
plan-db.sh validate-wave {wave_db_id}           # Per-wave Thor validation
plan-db.sh validate {id}                        # Bulk Thor validation
plan-db.sh complete {plan_id}                   # Blocks if wave PRs not MERGED
plan-db.sh cancel {plan_id} "reason"            # Cancel plan (cascade → waves → tasks)
plan-db.sh cancel-wave {wave_db_id} "reason"    # Cancel wave (cascade → tasks)
plan-db.sh cancel-task {task_db_id} "reason"    # Cancel single task
plan-db.sh execution-tree {plan_id}             # Colored tree view with reasons
plan-db.sh conflict-check {id}                  # Cross-plan file overlap detection
plan-db.sh conflict-check-spec {proj} spec.yaml # Pre-import conflict check
plan-db.sh wave-overlap check-spec spec.yaml    # Intra-wave overlap detection
ci-watch.sh [branch] [--repo R] [--sha S]       # Poll CI with backoff (JSON output)
```

## Troubleshooting: `complete` Fails (N/M tasks done)

```bash
# Step 1: Find incomplete tasks
sqlite3 ~/.claude/data/dashboard.db "SELECT id, task_id, title, status FROM tasks WHERE plan_id = {PLAN_ID} AND status NOT IN ('done', 'skipped', 'cancelled');"
# Step 2: For 'submitted' tasks — run Thor validation
plan-db.sh validate-task {TASK_DB_ID} {PLAN_ID} thor
# Step 3: For other statuses — submit via safe wrapper then validate
plan-db-safe.sh update-task {TASK_DB_ID} done "Reason"  # sets submitted
plan-db.sh validate-task {TASK_DB_ID} {PLAN_ID} thor     # sets done
# Step 4: Complete
plan-db.sh complete {PLAN_ID}
```

## Cluster & Sync

```bash
plan-db.sh cluster-status          # Unified local+remote plan view
plan-db.sh remote-status           # SSH status from remote host
plan-db.sh token-report            # Per-project token/cost by host
plan-db.sh autosync start|stop|status # Background DB sync daemon
```

## File Locking & Staleness

```bash
file-lock.sh acquire <file> <task_id> [--agent NAME] [--plan-id N] [--timeout N]
file-lock.sh release <file> [task_id]
file-lock.sh release-task <task_id>   # Release all locks for a task
file-lock.sh check <file>              # Who holds the lock?
file-lock.sh list [--plan-id N] [--task-id ID]
file-lock.sh cleanup [--max-age MIN] [--dry-run]
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

- **CLI**: `piani` (interactive) | `piani -n` (single-shot) | **DB**: ~/.claude/data/dashboard.db
- **Sync**: `dbsync status|pull|push|incremental` (multi-machine)
