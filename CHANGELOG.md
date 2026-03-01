# Changelog

## [2026-03-01] — Opus Enforcement for Planner (Process Fix)

### Changed

- `CLAUDE.md`: Mandatory Routing table — added Opus enforcement note; planning by non-Opus = VIOLATION
- `commands/planner.md` v2.6.1: frontmatter `model: claude-opus-4.6` — skill now requires Opus
- `AGENTS.md`: Workflow Enforcement section — explicit Opus requirement for `/planner` and `@planner`
- `copilot-config/copilot-instructions.md`: Mandatory Routing — enforcement note for `@planner` on `claude-opus-4.6-1m`
- `copilot-agents/planner.agent.md`: already set to `claude-opus-4.6-1m` (no change needed)
- `projects/-Users-roberdan--claude/memory/user-preferences.md`: added lesson from Plan 289

### Fixed

- `v_plan_roi` view: `p.plan_name` → `p.name AS plan_name` (pre-existing column name bug)
- `v_plan_intervention_stats` view: added JOIN to `plans` table (pre-existing — `plan_versions` lacks `project_id`/`plan_name`)

### Notes

Plan 289 cancelled: planned by Sonnet (coordinator) instead of Opus. Full rollback executed (plan cancelled, worktree removed, ALTER TABLE columns dropped). Plan 291 re-created by Opus.

---

## [2026-03-01] — c Dispatcher (Token Optimization)

### Added

- `scripts/c`: unified CLI dispatcher, 8 subcommand groups (d/p/db/w/lock/reap/ci/git), wraps 121 scripts
- `scripts/lib/c-compact.sh`: compact JSON output engine — strips null/0/false/[] via python3 inline
- `db-digest.sh` v1.1.0: token-stats and monthly subcommands (eliminates raw SQL for DB analytics)
- ADR-0027: c dispatcher architecture decision

### Changed

- `digest-scripts.md` v2.2.0: `c alias` column in mapping table
- `tool-preferences.md` v2.1.0: `c` shortcuts in tool mapping + CI/Build Commands

---

## [2026-03-01] — Anti-Self-Validation + Post-Plan Hardening

### Added

- ADR-0025: Tiered Model Strategy (Sonnet/Opus/Haiku) — supersedes ADR-0003 model section
- ADR-0026: Anti-Self-Validation Protocol — 3-layer protection (plan-db-safe + @validate + SQLite trigger)

### Changed

- execution-optimization.md v2.5.0: added Copilot CLI Thor Validation section (anti-self-validation, 3-layer protection table); post-merge CI + deployment gates now BLOCKING (not warning)
- copilot-instructions.md: Thor model row `claude-opus-4.6` → `claude-sonnet-4.6`; mandatory routing table: `@validate` handoff instead of self-validate
- `.github/skills/execute.md`: removed "self-validation" language; step 5 now references `@validate` handoff explicitly

---

## [2026-03-01] — Model Tier Optimization

### Changed

- 6 agents downgraded opus→sonnet: plan-post-mortem, sentinel-ecosystem-guardian, plan-business-advisor, plan-reviewer, research-report-generator, deep-repo-auditor
- 2 agents downgraded sonnet→haiku: marcus-context-memory-keeper, diana-performance-dashboard
- execution-optimization.md v2.4.0: Thor validator row corrected opus→sonnet (stale docs fix)
- agent-routing.md v2.2.0: Haiku Candidates section added with selection criteria
- model-strategy.md v2.2.0: Two Execution Modes section (copilot vs claude routing), haiku tier in decision tree
- CLAUDE.md: Identity line updated to reflect tiered model strategy (Sonnet/Opus/Haiku)

---

## [v9.18.0] - 28 Feb 2026

### Changed

- `CLAUDE.md`: fix auto-memory path (`~/.claude/auto-memory/` → `~/.claude/projects/{slug}/memory/`), document v2.1.63 cross-worktree sharing
- `worktree-discipline.md` v3.3.0: add Cross-Worktree Auto-Memory section — verified on plan 270 (VirtualBPM), no script changes needed

### Verified

- Claude Code v2.1.63 cross-worktree memory sharing: wave worktree sessions resolve to main repo project dir via `git-common-dir`. Pre-2.1.63 worktree dirs (MirrorBuddy ×4) are orphaned — safe to clean up.

---

## [v9.17.0] - 27 Feb 2026

### Added

- `wave-worktree.sh merge-async` — non-blocking PR creation (push + PR + return immediately)
- `wave-worktree.sh pr-sync` — verify previous wave PR merged, rebase current wave, extract review feedback
- PR feedback injection in `copilot-task-prompt.sh` — previous wave review comments injected into next wave prompts
- `wave_pr_created` precondition type in planner — allows overlapping wave execution
- `merge_mode` column in waves DB table (sync|async|none)
- Wiring Inference in `prompt.agent.md` — auto-generates "Wire X" F-xx for every "Create X"
- Step 3.1b Consumer Enforcement in `planner.agent.md` — BLOCKS if feature/refactor has empty consumers
- Step 3.5 Consumer Audit in `execute.agent.md` — verifies consumers import new code
- Gate 10 Integration Reachability in `validate.agent.md` — orphan exports = REJECT
- `validate-css-vars.sh` — cross-project CSS variable orphan detector
- `check_silent_degradation` in code-pattern-checks — detects `return null` on empty data
- `check_orphan_exports` in code-pattern-checks — detects exports with zero imports
- E2E smoke test template (`~/.claude/templates/e2e-smoke-test.spec.ts.template`)
- ADR 0024: Overlapping Wave Execution Protocol
- ADR: Workflow Hardening — Integration Completeness Quality Gates

### Changed

- `wave-worktree.sh` v3.0.0: 2 new subcommands, updated help/usage
- `copilot-task-prompt.sh` v2.1.0: Previous Wave PR Feedback section
- `execute.agent.md` v3.0.0: Phase 4.5 Overlapping Wave Protocol, Rule 7, Step 3.5
- `planner.agent.md` v2.2.0: Step 3.1b, `wave_pr_created` precondition
- `validate.agent.md` v3.1.0: 9 → 10 validation gates
- `plan-spec-schema.json`: downgrade to draft-07 (Zed validator compatibility)
- `code-pattern-check.sh`: 9 → 11 checks
- `code-pattern-checks.sh` v1.2.0: 2 new check functions
- `orchestration/SKILL.md`: updated commands with merge-async/pr-sync
- `plan-spec-schema.json`: consumers description updated (enforcement in planner, not schema)

---

## [v9.16.0] - 27 Feb 2026

### Added

- `--compact` flag for all 14 digest scripts (~30-40% fewer tokens)
- `ci-digest.sh checks <pr>` subcommand replacing `gh pr checks`
- ADR 0021: Serialization Format Policy (JSON vs YAML)
- ADR Index (docs/adr/INDEX.md)
- Active wave tasks display in dashboard mini
- `gh auth switch` hint for GitHub auth failures

### Changed

- `prefer-ci-summary.sh` v1.3.0: compact single-line error messages, blocks `gh pr checks`
- `digest-scripts.md` and `tool-preferences.md` updated with new commands
- ADR 0001 updated with `--compact` reference

### Removed

- `scripts/ci-check.sh` (replaced by `ci-digest.sh`)
- `scripts/executor-tracking.sh` (broken dependency)

---

## [v9.0.0] - 27 Feb 2026

### Added

- ADR 0020: Ecosystem Modernization for Claude Code v2.1.x
- Agent Teams Mode in parallelization (replaces Kitty terminal orchestration)
- Native worktree isolation (`isolation: "worktree"` in Task tool)
- WorktreeCreate/WorktreeRemove hooks (auto .env symlink + npm install)
- Advisory prompt hook for LSP/codegraph suggestions (PostToolUse Grep|Glob)
- Auto-memory coexistence protocol (auto vs manual memory)
- Copilot CLI GA alignment: plugin.json manifest, .github/skills/ directory
- Copilot CLI GA features: background delegation (&), /chronicle, cross-session memory
- GPT-5.3-Codex as default model for task execution
- Wildcard permissions: mcp**codegraph**_, Bash(npm _), Bash(git \*)
- New commands: /teleport, /debug, /copy, /memory, `claude agents`

### Changed

- ALL 21 agents updated for v2.1.x capabilities (LSP, Agent Teams, worktree isolation)
- `orchestration` skill v2.0.0: Kitty → Agent Teams (TeamCreate/SendMessage)
- `inject-agent-context.sh` v1.2.0: platform capabilities injection
- `parallelization-modes.md`: Agent Teams primary, Kitty legacy
- `copilot-instructions.md`: GPT-5.3-Codex, background delegation, /chronicle
- `copilot-config/hooks.json` v2 GA format + prefer-ci-summary parity
- `copilot-alignment.md`: GA status, feature parity matrix, plugin system
- All `reference/operational/*.md` updated for v2.1.x features
- `wave-worktree.sh`: native isolation flag documentation
- `worktree-create.sh`: WorktreeCreate hook awareness

### Gains

- Token reduction: ~8K-14K tokens/plan (context isolation + wildcard permissions)
- Time saved: ~3-5 min/plan (automated hooks + LSP navigation)
- Quality: Agent Teams enables parallel independent validation

---

## [v8.5.0] - 25 Feb 2026

### Changed

- `planner.agent.md` v2.1.0: DB GATE rule (Rule 6) — mandatory plan-db verification before user approval
- `planner.agent.md`: added Schema Validation step 3.1 and F-xx Exclusion Gate step 3.2

---

## [v8.4.0] - 24 Feb 2026

### Added — Plan Intelligence System (F-07)

- **3 agents**: `plan-reviewer` (5 quality gates), `plan-business-advisor` (5 structured assessments), `plan-post-mortem` (8 checks, 9 categories)
- **5 DB tables**: `plan_reviews`, `plan_business_assessments`, `plan_actuals`, `plan_learnings`, `plan_token_estimates`
- **3 DB views**: `v_plan_health`, `v_token_accuracy`, `v_plan_roi`
- **9 API endpoints**: review, business-assessment, learnings, token-estimates, actuals, learnings/search, roi-trend, token-accuracy, notify-actionable
- `plan-db-intelligence.sh`: 9 `cmd_` functions sourced by `plan-db.sh` (dispatch + help section)
- `token-estimator.sh`: estimate (effort→token mapping via historical data) + reconcile (flags >100% variance as learnings)
- `planner.md` v2.2.0: steps 3.1 (plan-reviewer gate), 3.2 (business-advisor assessment), 5.5 (post-mortem + token reconciliation)
- Plan spec `summary` field support in schema + import with backward compat

---

## [v8.3.0] - 23 Feb 2026

### Changed

- `CLAUDE.md`: replace inline CodeGraph block with `@reference/operational/codegraph.md` (fixes init contradiction), slim Thor Gate section, add Build/Test/Lint section (95→66 lines)
- `tool-preferences.md`: remove duplicate Priority Order section (84→76 lines)
- `agent-routing.md`: remove duplicate Extended Agents/Maturity/Codex sections (52→34 lines)
- `compact-format-guide.md`: remove Model-Agnostic/Smoke Test sections (125→99 lines)
- `copilot-alignment.md`: translate Italian to English, merge Rigour Gap + Known Limitations (110→69 lines)
- `memory-protocol.md`: compress Cleanup/Resume/Helper sections (89→70 lines)
- `dashboard/js/utils.js`: strip trivial JSDoc, keep security docs (233→184 lines)
- `dashboard/js/error-boundary.js`: strip trivial JSDoc, keep module comments (289→256 lines)
- `dashboard/js/wave-pagination.js`: strip trivial JSDoc, keep performance rationale (266→225 lines)
- `.gitignore`: add `*.pem`, `*.key` patterns

---

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
- `/optimize-project` skill for project audits, token-efficient recommendations, and automated optimization actions

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
