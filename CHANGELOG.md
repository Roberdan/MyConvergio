# Changelog

## [v9.19.0] - 05 Mar 2026

### Mesh Orchestration — Event-Driven (Plan 330)

- Added: `mesh_events` table — async event queue for worker→coordinator communication
- Added: `mesh-coordinator.sh` — daemon on m3max: processes events, auto-finish, offline detection
- Added: `mesh-notify.sh` — multi-channel notifications (macOS native, ntfy.sh, dashboard, Telegram)
- Added: `config/notifications.conf` — opt-in notification channel config
- Added: `scripts/lib/notify-config.sh` — INI config loader for notification channels
- Added: Heartbeat enhanced — emits plan_completed, wave_completed, human_needed events with dedup
- Added: Auto-finish — plan completes on worker → pull DB, sync all nodes, notify
- Added: Offline detection — heartbeat > 15min → stale, > 30min → auto-reassign to best peer
- Added: Dashboard event feed widget with real-time SSE updates
- Added: Dashboard toast notifications with auto-dismiss
- Added: Deep link hash router (#plan/{id} → scroll + highlight)
- Added: Coordinator status/toggle API endpoints
- Added: `/api/events`, `/api/notifications`, `/api/coordinator/status` endpoints

### Mesh Sync — Bidirectional

- Changed: `mesh-sync-all.sh` v2.0 — compares commit timestamps, pulls from ahead peer, pushes to all
- Added: Dashboard "Full Sync" button (bidirectional) alongside "Push" button
- Added: `/api/mesh/fullsync` SSE endpoint with live output

### Dashboard — Plan Start

- Added: ▶ START button on mission cards for plans with status=todo
- Added: CLI selector dialog (Copilot/Claude/Delegate to mesh)
- Added: `/api/plan/start` SSE endpoint with live execution output

### Fixes

- Fixed: CSP blocking Chart.js/xterm CDN (cdn.jsdelivr.net now allowed)
- Fixed: Plan handoff same_node skipping launch when plan not running
- Fixed: Duplicate JS functions (showToast, renderEventFeed) across modules

## [Unreleased]

### Knowledge Base System (Plan 332)

- Added: `knowledge_base` table in dashboard.db (SQLite, vector-ready schema with embedding BLOB)
- Added: `earned_skills` VIEW on knowledge_base (promoted=1 entries)
- Added: `scripts/lib/plan-db-knowledge.sh` — KB CLI module (kb-write/search/hit, skill-earn/list/promote/bump)
- Added: `copilot-agents/knowledge-base.agent.md` — 3 modes (PRE-PLAN, POST-TASK, CONSOLIDATE)
- Added: Planner KB integration (step 1.5 queries KB_RESULTS, KB_PATTERNS, EARNED_SKILLS)
- Added: Executor integration (STEP 4.5 Knowledge Capture, STEP 5.5 Skill Generation)
- Added: `hooks/pii-advisory.sh` — advisory-only PII detection (email, keys, phone), RFC1918 whitelist
- Added: `hooks/reviewer-lockout.sh` — blocks edit after 2+ Thor rejections on same file
- Added: KB commands documented in AGENTS.md and CLAUDE.md

## [2026-03-03] — Mesh Delegation & Auto-Sync

### Added

- **Dashboard Delegation**: Delegate plans to mesh nodes from active mission cards (rocket icon)
- **SSE Preflight**: 6 streaming checks (plan status, SSH, heartbeat, config sync, Claude CLI, disk space) with auto-fix
- **Auto-fix Preflight**: Stale heartbeat → restarts daemon; config out of sync → auto `mesh-sync-all`; Claude CLI → extended PATH search
- **SSE Streaming**: All mesh actions (sync, heartbeat, auth, status) now stream output live instead of blocking
- **Wake-on-LAN**: Pure Python WoL magic packet for offline nodes (button on mesh node cards)
- **SSH Reboot**: OS-aware reboot command for online nodes with post-reboot SSH polling
- **Auto-Sync on Plan Complete**: `mesh-sync-all.sh` push to all online peers when plan finishes
- **Auto-Sync on Heartbeat Start**: `sync-claude-config.sh pull` on daemon startup + periodic pull every ~5min
- **Terminal tmux Integration**: Dashboard terminals auto-attach to `plan-{ID}` tmux session on remote nodes
- **Project Badge**: Active plan cards show project name in purple badge
- **ANSI → HTML**: Streaming modals render terminal color codes correctly
- **Cross-platform**: Disk check via Python `shutil`, Claude CLI via extended PATH, Windows subprocess fallback for terminal

### Fixed

- **SSH alias resolution**: All SSH calls resolve `ssh_alias` from `peers.conf` instead of using peer name directly
- **Disk space check**: Replaced macOS-only `df -g` with cross-platform `python3 shutil.disk_usage`
- **Modal scroll**: All modals scrollable with sticky title bar (flex layout)
- **Sync conflicts**: `sync-claude-config.sh` auto-stash remote before merge, force-reset on diverged history

## [2026-03-03] — Security Hardening (Audit Remediation)

### Fixed

- **SEC-005**: CORS restricted from `*` to localhost origins only (`server.py`)
- **SEC-002**: Mesh peer parameter sanitized with regex + `shlex.quote()` (`server.py`)
- **SEC-001**: Terminal SSH peer validated + command quoted (`server.py`)
- **CF-001**: `env-vault-guard.sh` hook path fixed (`scripts/` → `hooks/`)
- **CF-002**: `model-registry-refresh.sh` hook path fixed (`scripts/` → `hooks/`)
- Codegraph CLI hooks removed from `settings.json` (no binary installed)

### Added

- Security headers: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`
- `settings-templates/`: low/mid/high-spec hardware profiles for MyConvergio install
- `protocols/thor-protocol.md`: Thor validation protocol reference

## [2026-03-02] — Control Center v3.0 Rewrite (Plan 302)

### Added

- **Bash Grid Layout Engine**: `dashboard-layout.sh` — 12 rendering primitives (header, cards, boxes, progress bars, rows, separators) with responsive 3-mode support (compact/standard/expanded)
- **Token Analytics View**: `dashboard-render-tokens.sh` — per-model breakdown, cost estimates, 14-day sparkline. Access via `A` key
- **Python Textual TUI**: `scripts/dashboard_textual/` — full-featured alternative UI with real Sparkline charts, DataTable views, animated mesh topology, 4 themes (MUTHUR, NEXUS-6, HAL 9000, Neon Flux). Launch: `piani --tui`
- **Design System**: unified `dashboard-themes.sh` with semantic colors (TH_SUCCESS/WARNING/ERROR/INFO), inner+outer border chars, 3 retro sci-fi themes
- Consolidated test suite: `tests/test-dashboard-v3.sh` (62 tests)

### Changed

- All 16 dashboard rendering modules rewritten with grid layout engine
- `dashboard-mini.sh`: new `--tui` flag, module source chain, analytics view
- `dashboard-navigation.sh`: `A` key for analytics from all non-mesh views
- `dashboard-db.sh`: theme-aware `render_bar()`, new `format_cost()`, `db_token_analytics()`
- `dashboard-layout.sh`: responsive compact mode (2x2 cards for <80 cols)

### How to use

```bash
piani                    # Bash retro grid dashboard (default)
piani --tui              # Python Textual TUI (futuristic)
piani -t nexus6          # Switch theme (muthur/nexus6/hal9000)
# Inside dashboard: A=analytics, M=mesh, C=completed, T=theme, Q=quit
```

## [2026-03-02] — Mesh Dashboard Visualization + Live Plan Migration

### Added

- **Plan 300**: `dashboard-render-mesh.sh` + `dashboard-render-mesh-detail.sh` — htop-style mesh network visualization in mini dashboard (32/32 tests)
- **Plan 301**: `mesh-migrate.sh` — single-command live plan migration between mesh peers (26/26 tests). Executed remotely on m1mario via Claude Code over SSH/Tailscale as proof-of-concept
- `config/mesh-rsync-exclude.txt`: rsync exclusion patterns for full-folder sync
- `scripts/lib/mesh-migrate-sync.sh`: preflight checks + rsync functions
- `scripts/lib/mesh-migrate-db.sh`: DB WAL checkpoint, copy, path remap, plan claim transfer, rollback
- `tests/test-mesh-dashboard.sh`, `tests/test-mesh-migrate.sh`: 58 tests total
- ADR-0030: Mesh Dashboard + Migration architecture decision
- Permanent no-sleep on m1mario: `pmset` + LaunchDaemon `com.mesh.nosleep`
- Claude OAuth token on m1mario for headless execution

### Changed

- `dashboard-render-overview.sh`: mesh mini-preview moved above active plans (always visible)
- `dashboard-navigation.sh`: `M` key for mesh detail view, 10s refresh in mesh mode

### How to use

```bash
piani                              # Dashboard with mesh preview
# Press M for full mesh topology, B to go back

mesh-migrate.sh 300 omarchy        # Migrate plan 300 to omarchy
mesh-migrate.sh 300 m1mario --dry-run  # Preview without executing
```

---

## [2026-03-02] — Fix planner model ID + centralized model config

### Added

- `config/models.yaml` v1.0.0: single source of truth for all model IDs (Claude Code aliases + Copilot full IDs)
- `scripts/model-update.sh` v1.0.0: batch-updates all Copilot agent model IDs from `models.yaml` (`--dry-run` supported)

### Fixed

- `commands/planner.md`: `model: claude-opus-4.6` (invalid API ID) → `model: opus` (alias — auto-resolves to latest Opus)
- `CLAUDE.md`, `AGENTS.md`, `execution-optimization.md`: hardcoded model IDs → alias references

### Notes

Claude Code uses short aliases (`opus`, `sonnet`, `haiku`) that auto-resolve — no update needed on model releases. Copilot agents need full IDs — run `model-update.sh` after editing `models.yaml`.

---

## [2026-03-01] — Environment + Documentation (Plan 297 W4)

### Added

- `scripts/mesh-env-setup.sh` v1.0.0: full environment replication in 3 commands (tools, AI engines, hooks, aliases)
- `scripts/lib/mesh-env-tools.sh`: cross-platform tool install functions (macOS brew, Linux apt)
- `docs/adr/0029-mesh-networking.md`: ADR for P2P mesh architecture (evolution from ADR-0004)
- `reference/operational/mesh-networking.md`: operational guide (205 lines, table-first format)
- MyConvergio: `docs/mesh-networking.md` user-facing guide + README.md mesh section

### Changed

- `agents/release_management/ecosystem-sync.md`: mesh scripts added to sync scope
- `CLAUDE.md`: added `@reference/operational/mesh-networking.md` import
- `AGENTS.md`: mesh networking reference in Infrastructure section
- `docs/adr/INDEX.md`: added row 0029

---

## [2026-03-01] — Dynamic Dispatch — AI Agent Load Balancer (Plan 297 W3)

### Added

- `scripts/mesh-load-query.sh`: per-peer load query with cost_tier mapping and privacy_safe detection
- `scripts/remote-dispatch.sh`: SSH task execution on remote peers with cost attribution
- `scripts/mesh-dispatcher.sh`: floating coordinator with cost/privacy-aware peer scoring
- `scripts/lib/mesh-scoring.sh`: peer scoring library (capability +3, cost +2/+1/0, privacy +3, load 0-2, capacity +1)
- `scripts/mesh-heartbeat.sh`: peer liveness daemon with launchd/systemd templates
- `config/mesh-heartbeat.plist.template`: macOS launchd template (envsubst-ready)
- `config/mesh-heartbeat.service.template`: Linux systemd user service template

### Changed

- `scripts/delegate.sh`: added --host flag for remote dispatch via mesh network
- `config/orchestrator.yaml`: added mesh: section with routing defaults (max_tasks_per_peer, dispatch_timeout, cost_priority)

---

## [2026-03-01] — Mesh Networking Sync Evolution (Plan 297 W2)

### Added

- `scripts/sync-claude-config.sh` v2.0.0: multi-peer push-all/pull-all/status-all via peers.sh
- `scripts/lib/sync-dashboard-db-multi.sh` v1.0.0: multi-peer DB sync with latest-wins merge (updated_at), insert-or-ignore for token_usage
- `scripts/peer-sync.sh`: one-command config+DB sync (push/pull/status) with parallel execution
- `psync` alias in shell-aliases.sh

### Changed

- `scripts/sync-dashboard-db.sh` v2.1.0: sources sync-dashboard-db-multi.sh, adds push-all/pull-all/status-all
- `scripts/lib/plan-db-cluster.sh`: N-peer iteration via peers_online() instead of single REMOTE_HOST
- `scripts/lib/plan-db-remote.sh`: N-peer status, token_usage aggregation across all peers
- `scripts/tlx-presync.sh`: replaced hardcoded hostname with peers_check

---

## [2026-03-01] — Mesh Networking Foundation (Plan 297 W1)

### Added

- `config/peers.conf`: peer registry flat file — generic hostnames (my-mac, my-linux, my-cloud)
- `scripts/lib/peers.sh` v1.0.0: peer discovery library (load, list, get, check, online, self, others)
- `scripts/bootstrap-peer.sh`: remote peer initialization with bidirectional SSH key distribution
- `scripts/mesh-auth-sync.sh`: credential sync (Claude, Copilot, OpenCode, Ollama) via SSH
- `peer_heartbeats` DB table: peer liveness tracking (last_seen, load_json, capabilities)
- `tasks.privacy_required` column: privacy-aware task routing (F-16/F-17)

---

## [2026-03-01] — API Cost Optimization v2 (Plan 291)

### Added

- `scripts/batch-dispatcher.sh` v1.0.0: Anthropic Batch API submit/poll/parse — eligibility check (effort=1, chore/doc/test), exponential backoff, token_usage logging with `agent='batch-api'`
- `scripts/model-router.sh` v1.0.0: decision tree for copilot/claude model routing by task-type+effort, JSON output with `batch_eligible` flag
- `scripts/lib/cost-calculator.sh`: per-model pricing functions (haiku/sonnet/opus/batch), `calc_cost_from_token_usage()`
- `reference/operational/prompt-caching-guide.md` v1.0.0: caching mechanics, `DISABLE_PROMPT_CACHING`, cost math (write=1.25x, read=0.1x → 90% discount)
- `docs/adr/0028-api-cost-optimization.md`: 5-strategy cost reduction decision, Accepted

### Changed

- `commands/execute.md` v2.2.0: P1.5 model-router integration + batch routing; P1.9 `CLAUDE_MAX_EXHAUSTED` fallback check
- `scripts/db-digest.sh`: added `cost-report` subcommand (per-model cost breakdown)
- `scripts/c`: added `model` group (`c model`) and `cost-report` to `db` group
- `reference/operational/continuous-optimization.md` v2.1.0: Prompt Caching Health + Batch API Usage monthly checklist
- `reference/operational/digest-scripts.md` v2.3.0: cost-report row
- `plan_actuals`: added `model_cost_breakdown` column (idempotent ALTER)

---

## [2026-03-01] — Token Attribution via DB Time Window

### Changed

- `scripts/lib/plan-db/validate-gate-8.sh` v1.1.0: `cmd_validate_task` now auto-populates `tasks.tokens` at Thor validation time by summing `token_usage` entries whose `created_at` falls within `[task.started_at, task.completed_at]` for the task's project. DB-only, no file reads.

### Details

- Works for **Claude Code task-executor subagents**: each subagent is its own session; Stop hook writes `token_usage` before parent calls `validate-task`
- Works for **Copilot CLI** (copilot-worker.sh): `session-tokens.sh` (sessionEnd hook) writes real API counts before validate-task runs; overwrites `_ap_tokens` estimate with accurate data
- Works for **any executor** that writes to `token_usage` (delegate.sh, direct API calls)
- Limitation: in-session execution (no subagent) → `tokens = 0` at validate-task time; Stop hook fires only at full session end
- Priority: real API counts from `token_usage` preferred over `--tokens N` estimates; if no time-window data, existing value preserved (no regression)

---

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
