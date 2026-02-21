# Changelog

## [v6.0.0] - 15 Feb 2026 — Token Optimization & Quality Assurance Evolution

Major release combining LLM instruction optimization (40-60% token reduction target) with enhanced Thor validation (per-task + per-wave modes, Gate 9 constitution enforcement) and effort-weighted progress tracking.

### Token Optimization (Plan 149)

**Compact Markdown Format (ADR 0009)**

- Added: ADR 0009 — Compact Markdown Format specification (12 rules: keyword-dense bullets, tables for mappings, @imports, max 250 lines/file, max 150 instructions total)
- Added: Baseline token measurement — 39,047 tokens across 52 files (cl100k_base)
- Added: `reference/operational/compact-format-guide.md` — reusable optimization guide
- Added: `/optimize-instructions` command for interactive optimization
- Fixed: `planner-init.sh` pipefail bug (PROMPT_FILES double output)

**Global Files Optimization**

- Changed: CLAUDE.md rewritten using @imports pattern. 153→57 lines (-62.7%). Created 3 new detail files: `workflow-details.md`, `thor-gate-details.md`, `agent-routing.md`. 6 @imports active. Progressive disclosure index pattern.
- Changed: guardian.md compact format. 32→23 lines (-28%). Keyword-dense bullets, version tag v2.0.0.
- Changed: coding-standards.md compact format. 18→13 lines (-27%). Keyword-dense, version tag v2.0.0.
- Changed: All 11 `reference/operational/*.md` files versioned v2.0.0. Average token reduction -8.5%. Notable: copilot-alignment -26%, tool-preferences -13%, worktree-discipline -10%.
- Removed: Redundant examples and verbose explanations across all files. Replaced with dense reference tables and keyword indices.
- Added: Table of contents and quick lookup sections in key operational files.

**Command & Agent Files**

- Changed: planner.md 268→147 lines (-45%) — tables for rules, @imports for modules
- Changed: execute.md 159→138 lines (-13%) — compact format applied
- Changed: prompt.md, prepare.md, research.md, release.md — v2.0.0 compact format
- Changed: strategic-planner.md — compact format ~30% reduction
- Changed: 8 copilot-agents/\*.agent.md files — full rewrite compact format, v2.0.0

**MirrorBuddy Project Files**

- Changed: `.github/copilot-instructions.md` rewritten in compact format
- Changed: All 9 `.github/instructions/*.instructions.md` files rewritten in compact format
- Changed: All 9 `.github/agents/*.agent.md` files rewritten in compact format
- Changed: All 6 `.github/prompts/*.prompt.md` files rewritten in compact format
- Changed: `/Users/roberdan/GitHub/MirrorBuddy/CLAUDE.md` rewritten in compact format
- Applied: ADR 0009 compact markdown format across all MirrorBuddy instruction files

**MirrorBuddy Quality Gates**

- Changed: `.husky/pre-commit` — moved `i18n:check` outside conditional (runs on EVERY commit)
- Added: `scripts/smart-test.sh` — runs `vitest related` for staged .ts/.tsx files in src/ (<15s)
- Added: `scripts/env-var-audit.sh` — verifies all `process.env.X` exist in .env.example + validate-pre-deploy.ts + GH workflows
- Changed: `.husky/pre-commit` — added smart-test.sh call after i18n:check
- Changed: `.husky/pre-push` — added env-var-audit.sh, i18n:check, duplicate commit check (last 5 commits)
- Added: `src/lib/sentry/env.ts` — shared Sentry environment detection module (getEnvironment, isEnabled, getDsn, getRelease)
- Changed: `sentry.client.config.ts`, `sentry.server.config.ts`, `sentry.edge.config.ts` — refactored to use shared env module
- Added: `src/lib/sentry/env.test.ts` — 23 unit tests proving all 3 configs agree on env/enabled/DSN/release
- Result: Eliminated duplication, consistent Sentry behavior across all runtimes

**Results & Validation**

- Result: 15.5% token reduction (26,116→22,074 tokens), 47.5% line reduction (4,645→2,437 lines) across 26 global files
- Status: Below 40-60% target due to 5 unchanged files (32% of baseline tokens) and 10 increased files
- Best performers: CLAUDE.md (64.3%), execute.md (42.4%)
- Added: Token recount using tiktoken cl100k_base for all optimized files
- Added: `.copilot-tracking/optimized-tokens.json` (26 global files, 22,074 tokens)
- Added: `.copilot-tracking/token-comparison-report.md` (detailed file-by-file analysis)
- Added: Smoke test script validates markdown syntax, @import references, JSON validity
- Verified: All @import references resolve, all JSON files valid, no syntax errors

### Thor v4.0 — Per-Task + Per-Wave Validation (ADR 0008)

**Dual Validation Modes**

- Added: Per-task Thor validation mode (Gate 1-4, 8, 9 scoped to single task)
- Added: Per-wave Thor validation mode (all 9 gates + build at wave scope)
- Added: `plan-db.sh validate-task <task_id> [plan_id]` command
- Added: `plan-db.sh validate-wave <wave_db_id>` command
- Changed: Thor agent v3.4.0 -> v4.0.0 (two validation modes, Gate 9, ADR-Smart)
- Changed: Thor validation gates v1.0.0 -> v2.0.0 (Gate 9, Gate 4 clarified)

**Gate 9: Constitution & ADR Compliance**

- Added: Gate 9 — Constitution & ADR Compliance (CLAUDE.md rules, coding-standards, ADR checks)
- Added: ADR-Smart Mode — skips circular ADR enforcement when task IS updating an ADR
- Changed: Gate 4 narrowed to codebase patterns; constitution checks moved to Gate 9

**Workflow Integrity**

- Added: `--force` flag to `cmd_validate_task()` in plan-db-validate.sh (prevents validation bypass)
- Fixed: Without `--force`, validated_by must be 'thor' or 'thor-quality-assurance-guardian'
- Added: Per-task `validated_at` check to `cmd_validate_wave()` (blocks wave if done tasks have NULL validated_at)
- Added: Pre-commit hook `scripts/hooks/thor-commit-guard.sh` (49 lines, blocks commits with unvalidated tasks)
- Fixed: `plan-scripts.md` documentation — added complete file-lock.sh command reference (release-task not release-all)

### Dashboard — Effort-Weighted Progress & Tree View

**Effort Tracking**

- Added: `effort_level` column to tasks table (1=trivial, 2=standard, 3=complex)
- Added: `calc_weighted_progress()` using effort_level + Thor validation gate
- Added: `--effort` flag to `plan-db.sh add-task`
- Changed: `plan-db-import.sh` reads effort from spec.json

**Display Enhancements**

- Added: Tree view in plan detail (`-p`) — tasks nested under waves with connectors
- Added: Dual progress display (Executor done vs Thor validated)
- Added: Thor badge per task (T-check/T!) and effort badges (E1/E2/E3)
- Added: Human task detection (user-dependent icon) with Action Required section
- Changed: Wave completion count derived from actual task counts, not stale status field
- Changed: dashboard-mini.sh v1.1.0 -> v1.2.0
- Fixed: Wave status not auto-updating when all tasks done (added SQL triggers)

### Planner v1.1.0

- Added: Rule 8 — Minimize Human Intervention (explore automated alternatives first)
- Added: Rule 9 — Effort Level Mandatory (1/2/3 per task)
- Added: Rule 10 — PR + CI Closure Task (TF-pr in final wave)
- Added: `effort` field in spec.json format
- Added: TF-pr task specification and workflow
- Changed: Thor section rewritten for per-task (8a) and per-wave (8b) validation
- Changed: Rule 4 updated for per-task Thor enforcement + Gate 9

### Execute v1.0.0

- Changed: Phase 4 split into 4a (per-task Thor) and 4b (per-wave Thor)
- Added: `Task type` parameter in Thor prompt for ADR-Smart Mode detection

### Model Strategy & Cross-Tool Execution

- Added: Model weight tiers table (Low x1, Mid x2, High x3)
- Added: Thor Validation Gate section (progress counts only validated tasks)
- Added: Cross-Tool Execution section (T0-00 review task for Claude->Copilot handoff)
- Changed: Agent Routing table includes Copilot models (gpt-4o, o3, o4-mini, codex)
- Removed: CHECK constraint on tasks.model column (supports any model string)

### Infrastructure

- Added: SQL triggers (task_done_counter, task_undone_counter, wave_auto_complete)
- Added: `plan-db-safe.sh` wrapper script

---

## [v7.0.0] - 21 Feb 2026 — Convergio Orchestrator v1 (ADR-0010)

Major release: Convergio Orchestrator v1

- Added: All new scripts (delegate.sh, copilot-worker.sh, opencode-worker.sh, gemini-worker.sh, agent-protocol.sh, delegate-utils.sh, gh-ops-routing.sh, worktree-safety.sh)
- Added: New configs (orchestrator.yaml, models-registry.json)
- Added: DB changes (output_data, executor_agent, precondition columns, SQL triggers, plan-db-safe.sh)
- Added: Hooks (thor-commit-guard.sh, worktree pre-check, delegation logging)
- Reference: ADR-0010 — Convergio Orchestrator Architecture

---

## [v5.1] - 12 Feb 2026 — CLAUDE.md Restructuring (ADR 0007)

- Changed: CLAUDE.md slimmed from 197 to 115 lines (42% reduction)
- Changed: Extracted concurrency control section to `reference/operational/concurrency-control.md`
- Changed: Extracted plan-db scripts section to `reference/operational/plan-scripts.md`
- Changed: Extracted digest scripts mapping to `reference/operational/digest-scripts.md`
- Changed: Added inline `_Why:_` rationale to all NON-NEGOTIABLE rules (Core Rules, Pre-Closure, Thor Gate, Worktree Discipline, Digest Scripts)
- Added: Reference table in CLAUDE.md linking all 11 operational reference files
- Added: ADR 0007 — CLAUDE.md Restructuring
- Learning: Smaller system prompts + on-demand references > monolithic instructions (ref: OpenAI "Harness Engineering")

---

## [v5.0] - 07 Feb 2026 — Distributed Plan Execution

**W1-Foundation: Distributed Execution** — Cross-machine plan execution with atomic claim protocol, host tracking, and worktree merge enforcement.

- Added: `host_heartbeats` table and `plans.description` column (migrate-v5-cluster.sh)
- Added: `plan-db-cluster.sh` module with claim/release/heartbeat/is_alive commands
- Added: SSH/config helpers in plan-db-core.sh (load_sync_config, ssh_check, config_sync_check)
- Changed: `cmd_start` now uses atomic claim protocol (blocks if plan claimed by other host, --force to override)
- Changed: `cmd_complete` requires worktree merged before plan closure (--force to skip)
- Added: Cluster command dispatch entries in plan-db.sh
- Fixed: `exit 1` in cmd_complete changed to `return 1` (sourced function)
- Fixed: db_query() wrapper with `.timeout 5000` for SQLITE_BUSY retry
- Fixed: SSH calls in sync-dashboard-db.sh now use `-o ConnectTimeout=10`

**W2-CLIDisplay: Enhanced CLI Output** — Host, description, liveness, and worktree/branch info in all CLI display commands.

- Added: `--description` flag to `create` command (auto-extracts from source file)
- Changed: `status` shows execution_host (color-coded), description, worktree/branch
- Changed: `kanban` DOING section shows host and description
- Added: `where` shows liveness status (LOCAL/ALIVE/STALE/UNREACHABLE) per host
- Added: `_get_branch()` helper resolves git branch from worktree path
- Fixed: Hostname normalization — strip `.local` suffix for consistent matching
- Added: `token_usage.execution_host` column via migration (backfill existing rows)
- Changed: Token tracking hooks write normalized hostname per record

**W3-RemoteCluster: Cross-Machine Visibility** — Remote status, cluster views, and token reporting across all execution hosts.

- Added: `plan-db-remote.sh` module with remote/cluster/token commands
- Added: `remote-status [project_id]` — SSH to remote host, runs plan-db.sh status
- Added: `cluster-status` — Unified local+remote plan view with connectivity indicator
- Added: `cluster-tasks` — In-progress tasks from both machines with host info
- Added: `token-report` — Per-project token/cost totals aggregated by host
- Changed: Dispatch entries and help text updated for all cluster commands

**W4-AutoSync: Automated Database Synchronization** — Background daemon for continuous DB sync, heartbeat, and config coordination.

- Added: `plan-db-autosync.sh` daemon with start/stop/status subcommands
- Added: Debounced sync (5s after last DB write), heartbeat every 60s
- Added: Cross-platform file mtime detection (Darwin stat -f / Linux stat -c)
- Added: `incremental` mode in sync-dashboard-db.sh (changed rows since last sync)
- Added: Token usage table sync via incremental_sync
- Added: Heartbeat row sync to remote in incremental_sync
- Added: Config sync integration (auto-push ~/.claude changes after DB sync)
- Changed: Dispatch in plan-db.sh calls standalone autosync script

**Opus 4.6 Configuration Upgrade** — Settings, hooks, and tooling updated for Claude Opus 4.6 adaptive thinking and 128K output tokens.

- Changed: `CLAUDE_CODE_MAX_OUTPUT_TOKENS` from 64K to 128K
- Removed: `MAX_THINKING_TOKENS` (deprecated, adaptive thinking is default)
- Changed: MCP codegraph permissions to wildcard `mcp__codegraph__*`
- Changed: `SessionStart` hook replaced with native `Setup` event
- Added: Session cost estimate in status line (ctx% \* model pricing)
- Added: `adversarial-debugger` agent (3 parallel Explore subagents with competing hypotheses)
- Added: `plan-db-safe.sh` wrapper with pre-checks before task done transitions
- Changed: CLAUDE.md updated with Opus 4.6 identity and new agent routing

---

## [v4.0] - Inter-Wave Communication & Agent Tracking

**Inter-Wave Communication & Agent Tracking** — Enables conditional wave execution, structured task output for cross-wave data passing, and multi-agent routing with executor tracking. Schema v4.0.

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
