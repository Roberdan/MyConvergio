# Changelog

## [v8.2.0] - 22 Feb 2026

### Added

- Wave-per-Worktree model: every wave gets dedicated worktree + PR + merge gate
- `wave-worktree.sh`: lifecycle management (create/merge/cleanup/status)
- `wave-worktree-core.sh`: shared library (wave_branch_name, wave_set_db, wave_get_db, wave_is_active)
- `migrate-v8-wave-worktree.sh`: DB schema migration (worktree_path, branch_name, pr_number, pr_url on waves + 'merging' status)
- `dashboard-mini.sh waves <plan_id>`: wave worktree visibility
- `test-wave-worktree.sh`: 18 integration tests
- Wave status: `pending` → `in_progress` → `merging` → `done` (done = merged to main)

### Changed

- `plan-db-safe.sh`: auto-triggers wave merge after Thor validation
- `execute-plan-engine.sh`: resolves worktree from wave DB first (fallback plan DB), creates wave worktree before tasks
- `plan-db-crud.sh`: cmd_complete blocks on merging waves, --auto-worktree deprecated, --wave-worktrees flag
- `plan-db-validate.sh`: check_readiness accepts wave-level worktrees, sync preserves merging status
- `plan-db.sh`: dispatch get-wave-worktree/set-wave-worktree
- `worktree-cleanup.sh`: --wave flag, --plan iterates wave worktrees
- `planner.md`: Rule 5 wave-level default, section 8c Wave Merge
- `execution-optimization.md`: step 5 wave-worktree.sh merge replaces manual commit
- `worktree-discipline.md`: v2 Wave-per-Worktree model, v1 as Legacy
- `task-executor.md`: Phase 0 wave DB worktree resolution note

---

## [v8.1.0] - 22 Feb 2026

### Added

- 3-Layer Pre-PR Quality Stack: `code-pattern-check.sh` (9 checks), `copilot-review-digest.sh`, `/review-pr` skill, `copilot-patterns.md`
- Thor Gate 4b: automated pattern checks during per-task validation (P1=REJECT, P2=WARN)
- Token-Aware Writing policy: <5% comments, compact commits/PRs, tables>prose for docs/ADRs/changelogs
- `comment_density` check (#9) in code-pattern-check.sh (P3 when >20%)

### Changed

- `service-digest.sh`: `copilot` subcommand + parallel in `all`
- `coding-standards.md`: Token-Aware Writing section (code, commits, PRs, docs, ADRs, changelogs)
- `copilot-instructions.md`: Token-Aware Writing + digest mappings
- `thor-validation-gates.md` v3.0.0: Gate 4b section
- `thor-quality-assurance-guardian.md` v5.1.0: Gate 4b in table + per-task step
- `prefer-ci-summary.sh` v1.2.0: allow `code-pattern-check.sh`
- `digest-scripts.md`, `tool-preferences.md`: new script mappings
- Both READMEs: Token-Aware Writing documentation
- CHANGELOG compacted per token-aware rules

---

## [v8.0.0] - 22 Feb 2026

### Added

- AGENTS.md cross-tool standard, plan-db-schema.md
- `secret-scanner.sh` pre-commit hook, `verify-before-claim.sh` PostToolUse hook
- Anti-hallucination rules to CLAUDE.md and AGENTS.md
- Circuit breaker to `plan-db-safe.sh`
- Test suites: hooks, agents, schema, workers
- ADRs 0011-0018: Anti-Bypass, Token Accounting, Worktree Isolation, ZSH Safety, AGENTS.md, Session Locking, CodeGraph, Memory Protocol
- `sync-root-agents.sh`, `generate-copilot-agents.sh`
- CodeGraph MCP server

### Changed

- `copilot-instructions.md` 183→91 lines (-50%)
- CLAUDE.md 100→64 lines (-36%)
- `dashboard-mini.sh` split 1377→141 lines + 10 modules
- 4 oversized scripts split (250-line compliance)
- ADRs 0003, 0005, 0009 updated
- All rules v2.0.0 compact format

### Removed

- Duplicate reference files, debug/, file-history/ (archived)

---

## [v7.0.0] - 21 Feb 2026

### Added

- Convergio Orchestrator v1: delegate.sh, copilot/opencode/gemini workers, agent-protocol.sh, delegate-utils.sh
- orchestrator.yaml, models-registry.json
- DB: output_data, executor_agent, precondition columns + SQL triggers
- Hooks: thor-commit-guard.sh, worktree pre-check, delegation logging
- ADR-0010: Convergio Orchestrator Architecture

---

## [v6.0.0] - 15 Feb 2026

### Added

- Per-task Thor validation (Gate 1-4, 8, 9): `validate-task`
- Per-wave Thor validation (all 9 gates + build): `validate-wave`
- Gate 9: Constitution & ADR Compliance with ADR-Smart Mode
- `effort_level` column, weighted progress, tree view, dual progress display
- Planner Rules 8-10: minimize human intervention, effort levels, PR+CI closure
- ADR 0007-0009: CLAUDE.md Restructuring, Per-Task Thor, Compact Markdown
- `@reference/` import pattern for progressive disclosure

### Changed

- Thor v3.4.0→v4.0.0: dual validation modes, Gate 9
- CLAUDE.md 153→57 lines (-62.7%) with @imports
- All 11 reference/operational files v2.0.0
- planner.md 268→147 lines (-45%), execute.md -13%
- 8 copilot-agents rewritten compact v2.0.0

---

## [v5.1] - 12 Feb 2026

### Changed

- CLAUDE.md 197→115 lines (-42%) via section extraction
- Extracted: concurrency-control.md, plan-scripts.md, digest-scripts.md
- Added inline `_Why:_` rationale to NON-NEGOTIABLE rules
- ADR 0007: CLAUDE.md Restructuring

---

## [v5.0] - 07 Feb 2026

### Added

- Distributed plan execution: atomic claim, host tracking, worktree merge enforcement
- `plan-db-cluster.sh`, `plan-db-remote.sh`, `plan-db-autosync.sh`
- Cluster: remote-status, cluster-status, cluster-tasks, token-report
- Auto-sync daemon: debounced sync (5s), heartbeat (60s), config coordination
- `adversarial-debugger` agent, `plan-db-safe.sh` wrapper

### Changed

- Opus 4.6: 128K output, adaptive thinking, MCP codegraph wildcards
- CLI display: host, description, liveness, worktree/branch
- Token tracking: execution_host column, hostname normalization

---

## [v4.0] - Inter-Wave Communication

### Added

- `output_data`, `executor_agent`, `precondition` columns + `evaluate-wave` (READY|SKIP|BLOCKED)
- Cycle detection for wave dependencies

### Changed

- task-executor: writes output_data on completion
- strategic-planner: generates executor_agent + precondition per task/wave
- Thor: validates executor_agent presence + output_data JSON
