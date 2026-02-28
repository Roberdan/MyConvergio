# Changelog

## [10.0.0] — 2026-02-28

### Added
- Registered ci-watch.sh plus refreshed plan-db and dashboard helper scripts to keep plan automation aligned with sanitized execution libs.
- Synced Copilot CLI commands (check, optimize-instructions, planner, prepare, prompt, release, execute, planner modules) for the new release flow.
- Documented ADR INDEX plus entries 0001-digest-scripts-token-optimization and 0024-overlapping-wave-execution for plan lifecycle guidance.
- Added sanitized hooks (enforce-standards.sh, session-reaper.sh, worktree-guard.sh) to reinforce guardrails.

### Changed
- Bumped scripts (plan-db safe/import/validate libs, dashboard renderers, audit scripts, ci-watch) for the v10 automation sweep.
- Rewrote README for v10, ensuring the new narrative and Mermaid sanity checks reflect the latest release structure.
- Updated agents (CONSTITUTION, thor-validation-gates, app-release-manager) to align with safety, routing, and release metadata.

### Fixed
- CLAUDE.md personal path references now sanitized to remove /Users/roberdan dependencies.

## [9.19.0] — 2026-02-28

### Added
- 3 new agents: deep-repo-auditor, strategic-planner (core_utility), mirrorbuddy-hardening-checks
- 10 new scripts: audit-launch, audit-remote-launch, branch-protect, cleanup-bloat, copilot-plan-runner, migrate-plan-to-linux, remote-repo-sync, token-audit, validate-css-vars, audit-remote-launch-copilot
- token-budget.md rule
- Config: agent-schema.json, cross-repo-learnings.yaml, sync-db.conf

### Changed
- CLAUDE.md: Shell Pipe Exceptions, Auto Memory, Slash Commands, expanded Mandatory Routing
- Updated agents: CONSTITUTION, thor-validation-gates, app-release-manager
- Updated guardian.md rule
- 79 scripts synced with latest ~/.claude improvements
- Aligned plan-spec-schema.json, code-pattern-checks.sh

### Fixed
- wave-worktree.sh and env-vault.sh improvements
- sync-dashboard-db.sh cleanup


## [9.18.0] - 2026-02-28

### Security
- Pin all GitHub Actions to SHA hashes (actions/checkout, github-script, gh-release)
- Upgrade softprops/action-gh-release v1 → v2
- Add `.github/CODEOWNERS` for critical paths (CONSTITUTION, hooks, install)
- Add `jq` prerequisite check in install.sh
- Replace `eval` with `bash -c` in test/verify scripts
- Fix auto-version.yml to use PAT with GITHUB_TOKEN fallback
- Add `MYCONVERGIO_DRY_RUN=1` dry-run mode for hooks

### Added
- BATS test framework with 21 tests (secret-scanner, worktree-guard, enforce-line-limit, install)
- `checksums.txt` for install.sh integrity verification
- ShellCheck CI workflow
- `.editorconfig` for consistent formatting
- `myconvergio-doctor.sh` health check script
- `make install` idempotency: backup existing files before overwrite

### Fixed
- Duplicate TEST 6 → TEST 8 in test-deployment.sh
- `install-selector.sh` agent count filter excluding all .md files
- `hooks.json` paths from `~/.copilot/hooks/` → `~/.claude/hooks/`
- AGENTS.md: removed phantom `agents/` dir reference
- Consolidated `skills/` as symlink to `.claude/skills/`

### Changed
- Compress 1.5MB PNG logo to 31KB WebP
- Promote `git clone` as primary install method (Option A)
- Add `set -euo pipefail` to 11 scripts missing it

## [9.17.0] - 2026-02-27

### Changed

- **task-executor-tdd v1.2.0**: minimized test output — no verbose flags, no pipe to tail (hook-safe)
- **task-executor v2.3.0**: mandatory Bash timeout on all commands, explicit process cleanup on exit
- **wave-worktree.sh v2.1.0**: rebase-before-merge to prevent forward-merge commits on main
- **plan-db-safe.sh v3.3.0**: auto pending→in_progress→done transition (single call handles full lifecycle)
- **execution-optimization.md v2.3.0**: rebase step documented in wave merge flow; plan closure checklist added
- **worktree-discipline.md v3.2.0**: Git Graph Hygiene rule — no forward-merge commits, rebase enforced
- **guardian.md v2.2.0**: git graph hygiene cross-reference added to PR merge section
- **Dashboard query optimization**: 4 modules updated (active-plans, completed-plans, overview, prs) — navigation module extracted

### Added

- **session-reaper.sh**: cleanup stale Claude sessions and release orphaned file locks
- **spotlight-exclude.sh**: drop .metadata_never_index in build/cache/dep dirs to prevent macOS Spotlight indexing waste
- **dashboard-navigation.sh**: extracted navigation module from dashboard-mini.sh for reuse

---

## [9.14.0] - 2026-02-27

### Added

- **session-check.sh v1.0.0**: fast JSON session status script (git, plans, PRs, warnings, next steps) — completes in <5s
- **/check command**: Claude Code (`commands/check.md`) and Copilot CLI (`copilot-agents/check.agent.md`) for session recap in Italian
- **resolve_github_remote()**: auto-detect git remote in wave-worktree-core.sh (no more hardcoded `origin`)
- **Pre-flight empty diff check**: wave-worktree merge skips when branch has zero diff from main

### Fixed

- **wave-worktree.sh v2.0.0**: 5 structural reliability fixes — remote detection, pre-flight check, `--timeout` flag removal, rollback merging→in_progress on failure
- **plan-db-safe.sh v3.2.0**: removed `exit 0` after merge failure — cascade continues to check other waves and plan completion
- **test-wave-worktree.sh**: 24/24 tests (6 new covering remote detection, rollback, pre-flight)

---

## [9.13.0] - 2026-02-27

### Added

- **yaml_to_json_temp()**: shared helper in plan-db-core.sh for YAML-to-JSON spec conversion
- **YAML spec support**: plan-db-conflicts.sh, wave-overlap.sh, token-estimator.sh now accept `.yaml` specs
- **test-yaml-spec.sh**: 9-assertion test suite for YAML spec pipeline

### Changed

- **planner.md v2.5.0**: YAML is now the default spec format ("Default format: YAML"); JSON still supported
- **plan-db-import.sh v1.3.0**: uses shared helper, preserves original extension on saved copy, render supports both `.yaml` and `.json` lookup
- **plan-scripts.md**: updated examples to show `spec.yaml` as default

---

## [9.12.1] - 2026-02-26

### Fixed

- **wave-worktree.sh**: removed redundant `gh pr checks` call — unified CI + readiness into single `pr-ops.sh ready` gate with fallback

---

## [9.12.0] - 2026-02-26

### Added

- **PR Post-Push Protocol**: NON-NEGOTIABLE 5-step workflow in guardian.md — CI green, review comments, resolve threads, readiness check, merge
- **wave-worktree.sh v1.1.0**: step 8 upgraded from best-effort to BLOCKING gate via `pr-ops.sh ready`; exits with actionable error on unresolved PR comments
- **Coordinator protocol**: step 6 invokes `pr-comment-resolver` agent when merge blocked by unresolved threads (max 3 rounds)
- **strategic-planner-git v2.1.0**: Pre-Merge section with mandatory CI + review comments check before merge

---

## [9.11.0] - 2026-02-26

### Fixed

- **Worktree cleanup**: added `git worktree prune` + `git fetch --prune` after wave merge to remove stale metadata
- **Plan completion safety net**: prune runs at plan completion regardless of wave cleanup success (handles CI failure exit path)
- **Planner v2.3.0**: Steps 2.5/3.1 now MANDATORY (Rules 13-14), Rule 15 test-adapts-to-code

---

## [9.10.0] - 2026-02-26

### Added

- **Auto-Version GitHub Action**: `auto-version.yml` bumps semver on every push to main using conventional commits (feat=minor, fix=patch, !=major), updates VERSION + CHANGELOG, creates tag → triggers release workflow

---

## [9.9.0] - 2026-02-26

### Added

- **Planner Rules 13-15**: Copilot-First Delegation MANDATORY (Rule 13), Plan Intelligence Review MANDATORY for 3+ tasks (Rule 14), Test-Adapts-to-Code (Rule 15)
- **auto-version.sh**: Conventional commit semver bumper (feat=minor, fix=patch, !=major)
- **verify-workflow-health.sh**: 46-check E2E verification for Claude Code + Copilot CLI
- **test-enforcement-hooks.sh**: 49 tests covering all enforcement hooks on both platforms
- 8 Copilot CLI enforcement hooks: guard-plan-mode, enforce-plan-db-safe, enforce-plan-edit, warn-bash-antipatterns, warn-infra-plan-drift, auto-format, guard-settings, verify-before-claim
- DB schema: conversation A/B testing columns in init-db.sql

### Changed

- `planner.md` v2.2.0 → v2.3.0: Steps 2.5 and 3.1 now MANDATORY (not DEFAULT/optional)
- `guardian.md`: added "Test Adapts to Code" NON-NEGOTIABLE section
- `plan-db-safe.sh`: removed `--force` flag, added rollback on validation failure, `plan-db-safe-auto` validator
- `plan-db-validate.sh`: `plan-db-safe-auto` as trusted auto-validator
- `plan-db-import.sh`: `_build_plan_file_cache()` for enforce-plan-edit hook
- `plan-db-crud.sh`: `active-plan-id.txt` tracking, `_cleanup_plan_file_cache()` on complete/cancel
- `copilot-alignment.md`: updated hook parity documentation
- `enforcement-hooks.md`: comprehensive hook reference table
- `compaction-preservation.md`: expanded preservation categories
- `plan-scripts.md`: added cancellation troubleshooting
- Agent metadata cleanup: removed redundant frontmatter from 25 agent files
- `strategic-planner.agent.md`: compacted from 346 to ~200 lines
- `ecosystem-sync.agent.md`: compacted from 126 to ~50 lines
- Test suite: consolidated 7 test files with portable SCRIPT_DIR pattern

---

## [9.8.0] - 2026-02-26

### Added

- **Enforcement hooks** for Claude Code: guard-plan-mode.sh, enforce-plan-db-safe.sh, enforce-plan-edit.sh
- `enforcement-hooks.md`: hook parity reference (15 portable, 6 platform-specific)
- Updated hooks/README.md with enforcement hook documentation

---

## [9.7.0] - 2026-02-26

### Added

- **Cancellation Support** — `cancelled` status for plans, tasks, waves with cascade logic
- Migration v9: `cancelled_at`, `cancelled_reason` columns + CHECK constraint rebuild
- Cancel commands: `cancel`, `cancel-wave`, `cancel-task` with reason tracking
- Execution tree: `execution-tree` CLI command with colored status icons and cancel/skip reasons
- Completion logic: counts resolved = done + cancelled + skipped (not just done)

### Changed

- `plan-db.sh` v3.3.0 → v3.4.0: cancel/execution-tree dispatch, updated help + status docs
- `plan-db-safe.sh`: wave completion skips cancelled/skipped tasks
- `plan-db-crud.sh`: cancel functions, cancelled status in update-task/update-wave
- `plan-db-validate.sh`: wave validation + sync skip cancelled/skipped tasks
- `plan-db-display.sh`: execution tree rendering function
- `plan-scripts.md`: updated valid statuses table, added cancellation section

---

## [9.5.0] - 2026-02-25

### Added

- **Plan Intelligence System v3** — ecosystem sync from dotclaude
- 3 agents: `plan-reviewer`, `plan-business-advisor`, `plan-post-mortem` (core_utility)
- `plan-db-intelligence.sh` module: 9 subcommands (add-learning, get-learnings, add-review, add-assessment, add-actuals, estimate-tokens, update-token-actuals, calibrate-estimates, get-actionable-learnings)
- `token-estimator.sh`: estimate/reconcile token usage with historical calibration
- 5 DB tables: plan_reviews, plan_business_assessments, plan_learnings, plan_token_estimates, plan_actuals
- 3+ DB views: v_plan_roi, v_learning_patterns, v_token_accuracy
- Summary field support in plan-spec-schema.json and plan-db-import.sh

### Changed

- `init-db.sql`: intelligence tables/views/indexes, tasks type CHECK expanded to 9 values
- `plan-db.sh`: sourced intelligence module, dispatch entries, help text
- `plan-db-safe.sh`: updated validation logic
- `plan-db-import.sh`: summary→title, do→description when summary present
- `copilot-task-prompt.sh`: updated prompt generation
- `thor-quality-assurance-guardian.md` v5.2.0: refinements
- `thor-validation-gates.md` v3.1.0: refinements
- `compaction-preservation.md`, `guardian.md`: rule updates
- `execute.agent.md`, `validate.agent.md`: Copilot CLI agent updates

---

## [9.6.0] - 2026-02-25

### Added

- **JSON Schema Validation** — plan-spec-schema.json v2.0.0 with field constraints, required properties, type definitions (ADR-012)
- **Maturity Lifecycle** — 5-phase status progression: draft → review → approved → active → archived (ADR-012)
- **Constraint Enforcement** — plan-db.sh validates schema before commit (required fields, type checking, enum validation)
- **Handoff Protocol** — structured wave-to-wave metadata, error handling, rollback on validation failure (ADR-012)
- **Enhanced Memory Agent** — `memory-supervisor.sh` v1.0.0: cross-session learning, pattern detection, knowledge aggregation
- **Structured Tracking** — plan_metadata table: maturity, constraints, handoffs, validation logs, schema version audit trail

### Changed

- `Makefile` lint targets refactored: `lint` now validates JSON schemas before linting code
- `generate-copilot-agents` propagates schema version to all agent configs (agents inherit plan_spec_version)
- `plan-db.sh` v3.2.0 → v3.3.0: schema validation on import/create, maturity state machine enforcement
- `plan-db-import.sh`: schema validation with detailed error messages per ADR-012
- `init-db.sql`: plan_metadata table with maturity, constraints_json, handoff_log columns
- `thor-validation-gates.md` v3.1.0 → v3.2.0: Gate 8 (schema compliance) expanded
- `copilot-agents/execute.agent.md`: maturity → active transition pre-wave
- `docs/concepts.md`: maturity lifecycle diagram + constraint examples

---

## [9.3.0] - 2026-02-24

### Added

- docs/getting-started.md — end-to-end tutorial from install to completed plan
- docs/concepts.md — glossary with Thor gates, enforcement policies, token optimization
- docs/use-cases.md — 5 solopreneur workflow scenarios with mermaid diagrams
- docs/infrastructure.md — scripts ecosystem, hooks, SQLite DB, concurrency control
- docs/agents/agent-showcase.md — deep dive into 5 hero agents with examples
- CI Batch Fix policy (NON-NEGOTIABLE) in execute.agent, task-executor, guardian, pr-comment-resolver
- Zero Technical Debt policy (NON-NEGOTIABLE) across all agent configs
- Copilot --yolo mode replacing --allow-all for full autonomous delegation

### Changed

- README.md — full rewrite with narrative structure and mermaid diagrams
- docs/workflow.md — complete rewrite from 5-line stub to full pipeline guide
- docs/agents/comparison.md — deep analysis vs Squad, AutoGen, CrewAI, LangGraph, OpenAI Agents SDK
- AGENTS.md — cross-links to showcase and comparison docs
- copilot-worker.sh, orchestrate.sh, worker-launch.sh — --yolo flag

---

## [9.2.0] - 2026-02-23

### Added

- 6 design skills: `/design-systems`, `/brand-identity`, `/ui-design`, `/design-quality`, `/creative-strategy`, `/presentation-builder`
- Design System Architect (Apple HIG) + Figma auto-layout specifications
- Brand Identity System (Pentagram-level) + executive presentation design
- UI/UX screen design (Apple HIG) + design-to-code translation
- Design critique (Nielsen heuristics) + accessibility audit (WCAG 2.2 AA)
- Marketing asset factory (47+ assets) + design trend research
- Animated presentation builder (React/Tailwind, HLS video, liquid glass)

### Changed

- `jony-creative-director.md` v2.0.0: modular skill architecture, tools enabled, routing table

---

## [9.1.0] - 2026-02-23

### Changed

- `agent-routing.md`: remove duplicate Extended Agents/Maturity/Codex sections (52→34 lines)
- `compact-format-guide.md`: remove Model-Agnostic/Smoke Test sections (125→99 lines)
- `copilot-alignment.md`: translate Italian to English, merge Rigour Gap + Known Limitations (110→69 lines)
- `memory-protocol.md`: compress Cleanup/Resume/Helper sections (89→70 lines)
- `tool-preferences.md`: remove duplicate Priority Order section (84→76 lines)

---

## [9.0.0] - 2026-02-22

### BREAKING CHANGES

- **npm distribution removed**: `npm install -g myconvergio` no longer works
- **Node.js no longer required**: all tooling is now pure bash + make
- **Root `agents/` directory removed**: single source of truth is `.claude/agents/`
- **`MYCONVERGIO_PROFILE` env var removed**: use `myconvergio install --minimal|--standard|--full|--lean` instead

### Migration from npm (v8.x or earlier)

```bash
# 1. Uninstall npm package
npm uninstall -g myconvergio

# 2. Install via curl (clones to ~/.myconvergio, installs CLI)
curl -sSL https://raw.githubusercontent.com/roberdan/MyConvergio/main/install.sh | bash

# 3. Add CLI to PATH (if not already)
export PATH="$HOME/.local/bin:$PATH"  # add to ~/.zshrc or ~/.bashrc

# 4. Verify
myconvergio version
myconvergio agents
```

Your `~/.claude/` content is preserved. The new installer creates a backup automatically if it detects existing content.

**Command mapping (npm → bash CLI)**:

| Before (npm)                                    | After (bash)                         |
| ----------------------------------------------- | ------------------------------------ |
| `npm install -g myconvergio`                    | `curl ... \| bash` or `make install` |
| `MYCONVERGIO_PROFILE=minimal npm install -g ..` | `myconvergio install --minimal`      |
| `myconvergio install --full`                    | `myconvergio install --full`         |
| `myconvergio agents`                            | `myconvergio agents`                 |
| `myconvergio backup`                            | `myconvergio backup`                 |
| `myconvergio restore <dir>`                     | `myconvergio restore <dir>`          |
| `myconvergio settings`                          | `myconvergio settings`               |
| `myconvergio upgrade`                           | `myconvergio upgrade`                |

### Added

- `install.sh`: universal curl installer (`curl -sSL .../install.sh | bash`)
- `scripts/myconvergio.sh`: pure bash CLI with all commands (install, upgrade, backup, restore, agents, settings, version)

### Removed

- `package.json`, `package-lock.json`, `.npmignore`
- `bin/myconvergio.js` (955-line Node.js CLI)
- `scripts/postinstall.js` (441-line npm postinstall hook)
- `scripts/backup-manager.js`, `conflict-resolver.js`, `generate-lean-agents.js`, `git-manager.js`, `postinstall-interactive.js`
- `scripts/sync-root-agents.sh` and Makefile `sync-agents` target
- Root `agents/` directory (65 duplicated agent files)

### Changed

- README: installation via curl one-liner, git clone + make, or plugin-dir
- All documentation: npm references replaced with `myconvergio` CLI or `make` commands
- `.gitignore`: removed `node_modules/`, `.npm`, npm log patterns

---

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
