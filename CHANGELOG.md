# Changelog

## [Unreleased]

**W1-Foundation: Distributed Execution** — Cross-machine plan execution with atomic
claim protocol, host tracking, and worktree merge enforcement.

- Added: `host_heartbeats` table and `plans.description` column (migrate-v5-cluster.sh)
- Added: `plan-db-cluster.sh` module with claim/release/heartbeat/is_alive commands
- Added: SSH/config helpers in plan-db-core.sh (load_sync_config, ssh_check, config_sync_check)
- Changed: `cmd_start` now uses atomic claim protocol (blocks if plan claimed by other host, --force to override)
- Changed: `cmd_complete` requires worktree merged before plan closure (--force to skip)
- Added: Cluster command dispatch entries in plan-db.sh
- Fixed: `exit 1` in cmd_complete changed to `return 1` (sourced function)
- Fixed: db_query() wrapper with `.timeout 5000` for SQLITE_BUSY retry
- Fixed: SSH calls in sync-dashboard-db.sh now use `-o ConnectTimeout=10`

**W2-CLIDisplay: Enhanced CLI Output** — Host, description, liveness, and
worktree/branch info in all CLI display commands.

- Added: `--description` flag to `create` command (auto-extracts from source file)
- Changed: `status` shows execution_host (color-coded), description, worktree/branch
- Changed: `kanban` DOING section shows host and description
- Added: `where` shows liveness status (LOCAL/ALIVE/STALE/UNREACHABLE) per host
- Added: `_get_branch()` helper resolves git branch from worktree path
- Fixed: Hostname normalization — strip `.local` suffix for consistent matching
- Added: `token_usage.execution_host` column via migration (backfill existing rows)
- Changed: Token tracking hooks write normalized hostname per record

**W3-RemoteCluster: Cross-Machine Visibility** — Remote status, cluster views,
and token reporting across all execution hosts.

- Added: `plan-db-remote.sh` module with remote/cluster/token commands
- Added: `remote-status [project_id]` — SSH to remote host, runs plan-db.sh status
- Added: `cluster-status` — Unified local+remote plan view with connectivity indicator
- Added: `cluster-tasks` — In-progress tasks from both machines with host info
- Added: `token-report` — Per-project token/cost totals aggregated by host
- Changed: Dispatch entries and help text updated for all cluster commands

**W4-AutoSync: Automated Database Synchronization** — Background daemon for
continuous DB sync, heartbeat, and config coordination.

- Added: `plan-db-autosync.sh` daemon with start/stop/status subcommands
- Added: Debounced sync (5s after last DB write), heartbeat every 60s
- Added: Cross-platform file mtime detection (Darwin stat -f / Linux stat -c)
- Added: `incremental` mode in sync-dashboard-db.sh (changed rows since last sync)
- Added: Token usage table sync via incremental_sync
- Added: Heartbeat row sync to remote in incremental_sync
- Added: Config sync integration (auto-push ~/.claude changes after DB sync)
- Changed: Dispatch in plan-db.sh calls standalone autosync script

---

**Opus 4.6 Configuration Upgrade** — Settings, hooks, and tooling updated
for Claude Opus 4.6 adaptive thinking and 128K output tokens.

- Changed: `CLAUDE_CODE_MAX_OUTPUT_TOKENS` from 64K to 128K
- Removed: `MAX_THINKING_TOKENS` (deprecated, adaptive thinking is default)
- Changed: MCP codegraph permissions to wildcard `mcp__codegraph__*`
- Changed: `SessionStart` hook replaced with native `Setup` event
- Added: Session cost estimate in status line (ctx% \* model pricing)
- Added: `adversarial-debugger` agent (3 parallel Explore subagents with competing hypotheses)
- Added: `plan-db-safe.sh` wrapper with pre-checks before task done transitions
- Changed: CLAUDE.md updated with Opus 4.6 identity and new agent routing

---

**Inter-Wave Communication & Agent Tracking** — Enables conditional wave execution,
structured task output for cross-wave data passing, and multi-agent routing with
executor tracking. Schema v4.0.

### W1: Schema Migration

- Added: `output_data` TEXT column to tasks table for structured task output
- Added: `executor_agent` TEXT column to tasks table for agent routing
- Added: `precondition` TEXT column to waves table for conditional execution
- Added: `migrate-v4.sh` migration script (idempotent)
- Added: `init-db-v4.sql` schema definition v4.0

### W2: Script Support

- Added: `--output-data` flag to `update-task` with JSON validation
- Added: `--executor-agent` flag to `add-task` (free TEXT, no CHECK)
- Added: `--precondition` flag to `add-wave` (JSON string)
- Changed: `get-context` includes `output_data`, `executor_agent`, and `completed_tasks_output`
- Changed: `import` reads `executor_agent` from spec.json with `codex` backward compat
- Changed: `import` reads `precondition` from spec.json wave objects

### W3: Evaluate Wave

- Added: `evaluate-wave` command returns READY|SKIP|BLOCKED based on preconditions
- Added: `detect_precondition_cycles` DFS-based cycle detection for wave dependencies
- Added: Thor check [6/7] warns on done tasks missing `executor_agent`
- Added: Thor check [7/7] validates `output_data` is valid JSON
- Changed: `check-readiness` includes cycle detection as check [0/N]

### W4: Agent Documentation

- Changed: task-executor writes `output_data` via `--output-data` flag on completion
- Changed: strategic-planner generates `executor_agent` per task and `precondition` per wave
- Changed: Thor validates `executor_agent` presence and `output_data` JSON validity
- Changed: Copilot agents (execute, planner, validate) updated with new fields
- Changed: model-strategy replaces `codex` boolean with `executor_agent` routing
