# Plan & DB Scripts

> **Why these exist**: `plan-db.sh` wraps SQLite operations with correct FK handling
> (e.g., `wave_id_fk` numeric FK, not `wave_id` string). Direct SQL risks schema violations.

## Database Conventions

- Tasks use `wave_id_fk` (numeric FK), NOT `wave_id` string
- Use `plan-db.sh` for all DB operations (handles FK correctly)
- **NEVER invent column names**. Schema: see `PLANNER-ARCHITECTURE.md`

## Plan Management

```bash
plan-db.sh create {project} "Name" --source-file {prompt.md} --auto-worktree
plan-db.sh import {plan_id} spec.json
plan-db.sh update-task {id} done "Summary"
plan-db-safe.sh update-task {id} done "S" # Pre-checks before marking done
plan-db.sh conflict-check {id}            # Cross-plan file overlap detection
plan-db.sh conflict-check-spec {proj} spec.json # Pre-import conflict check
plan-db.sh wave-overlap check-spec spec.json    # Intra-wave overlap detection
plan-db.sh validate {id}                  # Thor validation gate
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
plan-db.sh lock acquire|release|check|list  # File-level locking
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

- **CLI**: `dashboard-mini.sh` | **DB**: `~/.claude/data/dashboard.db`
- **Sync**: `sync-dashboard-db.sh status|pull|push|incremental` (multi-machine)
