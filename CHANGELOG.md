# Changelog

## [Unreleased]

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
