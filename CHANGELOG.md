# Changelog

## [8.0.0] - 2026-02-22

### Added

- Wave-per-Worktree model: each wave gets dedicated worktree + PR, merge = proof of work
- `wave-worktree.sh`: lifecycle script (create/merge/cleanup/status)
- `wave-worktree-core.sh`: shared library (branch naming, DB ops, stash management)
- `migrate-v8-wave-worktree.sh`: DB migration (4 columns, `merging` status, trigger)
- `execute-plan-engine.sh`: extracted plan execution engine with wave worktree integration
- Dashboard modules: 10 modular rendering scripts (overview, active/completed/pipeline plans, waves, PRs)
- `project-audit.sh` + `lib/project-audit-checks.sh`: project health auditing
- `thor-audit-log.sh`: Thor validation audit trail
- `pr-ops-api.sh`: PR operations REST API library
- `lib/common.sh`: shared utilities library

### Changed

- `plan-db-safe.sh`: auto-triggers wave merge after Thor validation
- `plan-db-crud.sh`: wave worktree CRUD, `cmd_complete` blocks on `merging` waves
- `plan-db-validate.sh`: accepts `merging` status, wave-level worktree checks
- `plan-db.sh`: new dispatch entries (get/set-wave-worktree)
- `dashboard-mini.sh`: `waves` subcommand with worktree/branch/PR visibility
- `worktree-cleanup.sh`: `--wave` flag for wave-level cleanup
- `worktree-discipline.md`: v2 Wave-per-Worktree model documentation
- `execution-optimization.md`: PR-based merge replaces manual commits
- `task-executor.md`: Phase 0 wave DB resolution
- `sync-to-myconvergio.sh`: expanded blocklist (personal scripts)

---

## [7.1.0] - 2026-02-22

### Added

- Token-Aware Writing policy: text exists only if it changes agent behavior
- `comment_density` check (#9) in code-pattern-check.sh (P3 when >20%)
- Token-Aware Writing sections in both READMEs + coding-standards + copilot-instructions
- "Token Efficiency" row in Market Differentiation table
- `/optimize-project` skill adds token-aware project audits, savings reports, and automated cleanup suggestions

### Changed

- `coding-standards.md`: Token-Aware Writing (code comments, commits, PRs, docs, ADRs, changelogs)
- `copilot-instructions.md`: Token-Aware Writing + digest mappings
- CHANGELOG compacted per token-aware rules (803→~150 lines)

---

## [7.0.0] - 2026-02-22

### Added

- Global config sync: v8.0.0 ecosystem optimization (anti-hallucination, token reduction, Copilot parity)
- `copilot-config/copilot-instructions.md` synced from global

### Changed

- README: v7.1.0, Token-Aware Writing section, 3-Layer Quality Stack docs
- All agents, scripts, hooks aligned with upstream v8.0.0

---

## [6.3.0] - 2026-02-22

### Added

- 3-Layer Pre-PR Quality Stack: `code-pattern-check.sh` (9 checks), `copilot-review-digest.sh`, `/review-pr` skill, `copilot-patterns.md`
- Thor Gate 4b: automated pattern checks (P1=REJECT, P2=WARN)

### Changed

- `service-digest.sh`: `copilot` subcommand + parallel in `all`
- `thor-validation-gates.md` v3.0.0, `thor-quality-assurance-guardian.md` v5.1.0: Gate 4b
- `prefer-ci-summary.sh` v1.2.0, `digest-scripts.md`, `tool-preferences.md`: new mappings

---

## [6.2.0] - 2026-02-21

### Added

- Thor Gate 3: credential scanning (AWS keys, API keys, GH tokens, passwords, private keys)
- Failed Approaches Tracking: `plan-db.sh log-failure`/`get-failures`
- `plan-spec-schema.json`: JSON Schema for spec.json validation
- Engineering Foundations section in README (ISE + HVE alignment)

### Changed

- Thor v5.0.0→v5.1.0, Planner v2.0.0→v2.1.0, Executor v2.1.0→v2.2.0

---

## [6.1.0] - 2026-02-21

### Added

- Planner Rule 11 — TF-tests: mandatory test consolidation in final wave
- All slash commands tracked (prompt, planner, execute, research, release, prepare + modules)

---

## [6.0.0] - 2026-02-21

### Added

- Convergio Orchestrator v1: delegate.sh, copilot/opencode/gemini workers, model-registry.sh, env-vault.sh
- Orchestrator libs: delegate-utils.sh, agent-protocol.sh, gh-ops-routing.sh, quality-gate-templates.sh
- orchestrator.yaml: 4 providers, routing rules, budget caps
- 25 test files (0 failures), pr-comment-resolver agent, hardening skill
- Session file locking: file-lock-session.sh, migrate-v6/v7 scripts

### Changed

- task-executor v2.2.0→v2.3.0: per-task engine routing
- copilot-worker.sh v1.0.0→v2.0.0: model selection, --add-dir
- coding-standards.md: Bicep IaC, async/await, SQL bind parameters

### Security

- Sanitized orchestrator.yaml (no real project names/keyvault refs)
- Fixed hardcoded paths in model-registry.sh
- hardening-check.sh: automated personal data/API key scanning

---

## [5.1.1] - 2026-02-15

### Fixed

- dashboard-mini.sh: human_summary support, multiline parsing, truncate_desc()
- plan-db-crud.sh: defensive status validation
- sync-to-myconvergio.sh: .DS_Store subdirectory filtering

---

## [5.1.0] - 2026-02-15

### Added

- pr-ops.sh v1.0.0: PR write operations (reply, resolve, merge, status)
- script-versions.sh v1.1.0: script index with versions, categories, staleness
- plan-db-safe.sh v3.0.0: auto-validate cascade (fixes 0% dashboard progress)
- session-recovery.sh, research-report-generator agent, ecosystem-sync agent
- compaction-preservation.md, 11 reference docs, Thor git hooks

### Changed

- task-executor v2.1.0→v2.2.0: always use plan-db-safe.sh for done
- prefer-ci-summary.sh v1.1.0→v1.2.0: block gh pr merge/view
- All plan-scripts/planner refs updated to plan-db-safe.sh

---

## [5.0.0] - 2026-02-15

### Added

- GitHub Copilot CLI: 9 agents (prompt, planner, execute, validate, tdd-executor, code-reviewer, compliance-checker, strategic-planner, ecosystem-sync)
- sync-to-myconvergio.sh with category filtering and blocklist

### Removed

- Web dashboard (replaced by CLI dashboard-mini.sh, zero-dependency bash+sqlite3)
- 13 internal development docs

---

## [4.8.0] - 2026-02-15

### Added

- 5 agents (60→65): sentinel-ecosystem-guardian, research-report-generator, task-executor-tdd, thor-validation-gates, app-release-manager-execution
- 6 lib scripts, 4 reference docs

### Changed

- Global config sync (105 issues fixed), 11 agents updated
- strategic-planner v3.0.0: wave-based decomposition + parallel execution
- 78 scripts + 11 libs synced, 12 hooks with SQL injection fixes

### Security

- All hooks use sql_escape() for SQLite inputs
- All 89 scripts: set -euo pipefail, trap, quoted vars

---

## [4.7.1] - 2026-02-14

### Fixed

- selective-install.sh: removed `local` outside functions (closes #1)

---

## [4.7.0] - 2026-02-14

### Added

- Agent Teams: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS env var
- TeammateIdle/TaskCompleted hooks, Setup hook (version-check.sh)
- memory + maxTurns fields on all 60 agents

### Changed

- TodoWrite→Tasks API migration (strategic-planner, ali, anna)

---

## [4.6.0] - 2026-02-07

### Added

- adversarial-debugger agent v1.0.0: 3 parallel Explore subagents
- plan-db-safe.sh wrapper with pre-checks

### Changed

- Settings: removed MAX_THINKING_TOKENS (Opus 4.6 adaptive), doubled output tokens

---

## [4.5.0] - 2026-02-07

### Added

- Hooks system: 10 enforcement hooks + lib (~21k tokens/session saved)
- Digest scripts: 14 token-optimized CLI wrappers
- Reference docs: 7 on-demand in .claude/reference/operational/
- Settings templates: high/mid/low-spec.json
- coding-standards.md rule

### Changed

- CLAUDE.md 653→82 lines (-87%)
- All 16 oversized agents trimmed to max 250 lines (-3308 lines)
- 6 oversized skills trimmed (-804 lines)

---

## [4.4.0] - 2026-01-27

### Added

- Context isolation on task-executor, thor, strategic-planner (50-70% token reduction)
- Skills YAML frontmatter: context fork, allowed-tools, user-invocable

### Fixed

- plugin.json version aligned, invalid LS tool in 5 agents, malformed frontmatter

---

## [4.3.0] - 2026-01-18

### Added

- Strategic planner modules: templates, thor integration, git worktree workflow
- worktree-create.sh, worktree-check.sh

---

## [4.2.0] - 2026-01-10

### Changed

- Dashboard sync: server.js route handling, token aggregation, wave dates, notification API
- Portability: removed project-specific references

---

## [4.1.0] - 2026-01-07

### Added

- Dashboard overhaul: Gantt, kanban, markdown/conversation viewers, bug tracking
- task-executor agent, workflow guide

---

## [3.8.0] - 2026-01-03

### Added

- EXECUTION_DISCIPLINE.md: 10 articles, second priority after CONSTITUTION

### Changed

- Self-contained repo: removed external deps, hardcoded paths
- CLAUDE.md 257→119 lines (-54%)

---

## [3.7.0] - 2026-01-02

### Added

- 3-tier install profiles: minimal (8 agents/50KB), standard (20/200KB), full (57/600KB)
- Settings templates: low/mid/high-spec.json
- Lean agent variants (~50% context reduction)
- CONTEXT_OPTIMIZATION.md guide

---

## [3.6.0] - 2025-12-31

### Added

- Universal orchestration: orchestrate.sh, detect-terminal.sh, tmux support
- Works from any terminal (Kitty/Zed/Warp/iTerm/VS Code)

---

## [3.5.0] - 2025-12-30

### Added

- Thor QA System v2.0.0: 7 validation gates, queue-based service, specialist delegation
- Thor protocol v1.0.1, worker instructions v1.0.0
- thor-queue-setup.sh, thor-worker-submit.sh, thor-monitor.sh

---

## [3.4.0] - 2025-12-30

### Added

- strategic-planner: mandatory GIT WORKFLOW section (worktrees, PRs, branch naming)

---

## [3.3.0] - 2025-12-30

### Added

- strategic-planner v1.4.0: bidirectional messaging, broadcasts, gate unlock notifications

---

## [3.2.0] - 2025-12-29

### Added

- Mandatory WAVE FINAL (6 doc tasks), ISE Engineering Fundamentals requirement

### Fixed

- Kitty send-text: added `\r` for auto-execution

---

## [3.1.0] - 2025-12-29

### Added

- strategic-planner v1.3.0: phase gates, polling protocol, execution tracker, time stats

---

## [2.2.0] - 2025-12-28

### Added

- Multi-Claude parallel orchestration via Kitty (up to 4 workers)
- scripts/orchestration/ tooling

---

## [2.1.2] - 2025-12-28

### Fixed

- npm OIDC URL case sensitivity, postinstall backup/output

---

## [2.1.0] - 2025-12-28

### Added

- npm distribution: `npm install -g myconvergio`
- ADR-011: Modular Execution Plans + Security Framework

---

## [2.0.1] - 2025-12-15

### Fixed

- YAML frontmatter validation excludes documentation files

---

## [2.0.0] - 2025-12-15

### Added

- 57 agents across 8 categories, versioning system, rules, skills, activity logging

---

## [1.0.0] - 2025-12-14

### Added

- Initial release: agent framework, CONSTITUTION.md, Makefile deployment, test suite
