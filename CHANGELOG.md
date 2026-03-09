# Changelog

## [v11.18.0] - 09 Mar 2026

### Added
- node provisioning — verify SSH, tmux, Convergio session on all peers


## [v11.17.0] - 09 Mar 2026

### Added
- dynamic Tailscale peer resolution for terminal SSH


## [v11.16.4] - 09 Mar 2026

### Fixed
- cache-bust terminal.js, update error messages to Rust server


## [v11.16.3] - 09 Mar 2026

### Fixed
- restore hover-actions CSS (was lost in previous commit)


## [v11.16.2] - 09 Mar 2026

### Fixed
- update E2E for current dashboard — selectors, widget counts, API 404 tolerance


## [v11.16.1] - 09 Mar 2026

### Changed
- update Cargo.lock (libc dependency)


## [v11.16.0] - 09 Mar 2026

### Added
- WebSocket PTY in Rust + 18 tests + KPI label fix


## [v11.15.4] - 09 Mar 2026

### Fixed
- restore full brain-canvas.js after other agent overwrote it


## [v11.15.3] - 09 Mar 2026

### Fixed
- cache bust kpi.js?v=2


## [v11.15.2] - 09 Mar 2026

### Changed
- remove Python terminal_server.py (will be implemented in Rust)


## [v11.15.1] - 09 Mar 2026

### Fixed
- mesh notification flapping + create terminal_server.py


## [v11.15.0] - 09 Mar 2026

### Added
- centered title, terminal btn prominent, 3-col grid
- redesign header + bigger idea form

### Fixed
- inline button/input reset for dark theme nav


## [v11.14.1] - 09 Mar 2026

### Fixed
- fallback metrics when GitHub stats unavailable
- uniform 32px height, bigger title, consistent controls


## [v11.14.0] - 09 Mar 2026

### Added
- W4 closure — tests, docs, app.js polling fix

### Fixed
- complete rewrite — inline styles, tags fix, error handling


## [v11.9.1] - 09 Mar 2026

### Fixed
- stronger gravity, soft bounds, same-tool-only synapses


## [v11.9.0] - 09 Mar 2026

### Added
- interactive neural network graph with full operational data


## [v11.8.2] - 09 Mar 2026

### Fixed
- unify Idea Jar and modals with shared widget system


## [v11.8.1] - 09 Mar 2026

### Fixed
- restore neural aesthetic with canvas glow + readable session cards


## [v11.8.0] - 09 Mar 2026

### Added
- enforce DB update after task completion, prevent Plan 382 regression


## [v11.7.0] - 09 Mar 2026

### Added
- header nav, idea jar redesign, planner section


## [v11.6.3] - 09 Mar 2026

### Fixed
- cache-bust brain scripts, remove fixed canvas height


## [v11.6.2] - 09 Mar 2026

### Changed
- replace brain canvas bubbles with agent card grid


## [v11.6.1] - 09 Mar 2026

### Fixed
- heartbeat persistence, peers.conf enrichment, remote poll


## [v11.6.0] - 08 Mar 2026

### Added
- unified workflow enforcement hooks — block violations automatically


## [v11.5.0] - 08 Mar 2026

### Fixed
- Mesh daemon peers.conf parser rewritten for INI format (extract `tailscale_ip` per section)
- Mesh daemon now persists peer heartbeats to SQLite `peer_heartbeats` table (was in-memory only)
- Peer name resolution: heartbeats stored as `omarchy`/`m1mario` instead of raw `100.x.x.x:9420`
- Default `--peers-conf` path resolved to `~/.claude/config/peers.conf` (was relative `peers.conf`)
- Tailscale binary detection searches 4 candidate paths including macOS app bundle
- Dashboard brain visualization: restored 5 missing script includes in `index.html`
- Session tracking hooks restored, brain pipeline fixed, Idea Jar widget pinned


## [v11.4.2] - 08 Mar 2026

### Changed
- add Nightly Guardian operations runbook


## [v11.4.1] - 08 Mar 2026

### Changed
- deduplicate CHANGELOG v11.4.0 entry


## [v11.4.0] - 08 Mar 2026

### Added
- Idea Jar system: capture, elaborate, and promote ideas to plans
- REST API: CRUD + notes + promote endpoints for ideas (api_ideas.rs)
- Dashboard: Idea Jar tab with filter bar, idea cards, create/edit modal
- Animated glass jar canvas with floating paper slips (priority-colored)
- Global hotkey Cmd/Ctrl+I for quick idea creation
- Overview widget with compact jar visualization
- CLI script idea-jar.sh (add, list, edit, note, promote, delete)
- Promote-to-plan flow with clipboard copy
- 7 integration tests for ideas API

## [v11.3.8] - 08 Mar 2026

### Fixed
- mktemp pattern in yaml_to_json_temp for macOS compatibility


## [v11.3.7] - 08 Mar 2026

### Fixed
- enable nightly guardian auto-fix and gitignore host configs


## [v11.3.6] - 08 Mar 2026

### Fixed
- cancelled plans shown as active missions in dashboard


## [v11.3.5] - 08 Mar 2026

### Changed
- add 21 integration tests for all dashboard API endpoints


## [v11.3.4] - 08 Mar 2026

### Fixed
- kanban drag bubbling, cancel/reset cascade waves, validate bypass


## [v11.3.3] - 08 Mar 2026

### Fixed
- plan detail API returns frontend-compatible format


## [v11.3.2] - 08 Mar 2026

### Fixed
- kanban parking lot drag-and-drop support


## [v11.3.1] - 08 Mar 2026

### Fixed
- dashboard data accuracy — waves query, project_name, kanban parking lot
- align schema CHECK constraints + resolve Dependabot vulnerability
- resolve audit findings — version alignment, stale files, migrate sync
- disable destructive legacy sync, deploy Rust daemon to all nodes

### Changed
- comprehensive audit and optimization for AI agent consumption
- archive 126 obsolete hooks/agents/prompts/scripts
- archive 32 obsolete scripts (Rust daemon replaces legacy sync)
- add 20+ indexes, optimize overview query with CTEs


## [v11.3.0] - 08 Mar 2026

### Added
- gated plan creation — 3 mandatory reviews before create/import

### Changed
- update architecture for Rust v11, add ADR 0040


## [v11.2.0] - 08 Mar 2026

### Added
- enforce-planner-workflow PreToolUse hook
- post-migration stabilization — logging, health, schema, KB learnings

### Fixed
- full Playwright audit green — 15/15 tests pass


## [v11.1.2] - 08 Mar 2026

### Fixed
- add Plan 100028 learnings — verify globs, PR body compliance, test domains, git auth
- resolve all console errors and add real-server E2E tests


## [v11.1.1] - 08 Mar 2026

### Changed
- ADR-0039 post-plan learning loop + README self-learning section


## [v11.1.0] - 08 Mar 2026

### Added
- post-plan learning loop (Thor 10) — two-level auto-learning system
- add serve subcommand for Axum dashboard server
- add hook subcommand + cargo cache CI + rebuild release binary

### Fixed
- align API response shapes with frontend expectations
- auto-migrate DB schema on server start + fix all endpoint queries
- update piani alias to use Rust claude-core serve
- align API response shapes with frontend expectations
- fallback to shell dispatcher when claude-core lacks hook subcommand
- remove Python from E2E, use static server

### Changed
- apply stashed config updates (CLAUDE.md, shell-aliases, copilot-config)


## [v11.0.0] - 08 Mar 2026

### Added — ConvergioEvolution (Plan 100025)

#### P0a: Conversational Plan Builder
- Chat DB schema with sessions, messages, attachments (ADR-0034)
- Chat API endpoints (CRUD, streaming SSE)
- Phase detector, agent router, requirement accumulator
- Chat panel UI, tab bar, context sidebar

#### P0b: GitHub Integration
- GitHub DB migration (commits, PRs, reviews tables)
- Commit tracking API, repo selector, KPI bar
- GitHub panel with activity timeline widget

#### P0c: Execute + Monitor
- EXECUTE phase with real-time task dispatch
- MONITOR view with mesh delegation UI

#### P1: Token Diet
- Lazy-load agent definitions (AGENTS.md → compact index)
- Document compaction (CLAUDE.md table-only references)
- Agent file trimming (<1500 bytes each)

#### P2: Hook Consolidation
- Single PreToolUse/PostToolUse dispatchers (ADR-0036)
- Consolidated hook checks in hooks/lib/hook-checks.sh
- Hook latency benchmark (<50ms target)

#### P3: Script Consolidation
- Unified digest.sh dispatcher (16 subcommands)
- Lazy-source modules in plan-db.sh
- Canonical sql_escape/sql_lit/sql_quote helpers

#### P4a: Rust Core (ADR-0037)
- Full Rust crate `claude-core` with plan-db, hooks, digest, lock modules
- CR-SQLite CRDT extension for mesh DB replication
- Mesh daemon with TCP/WebSocket, delta sync, heartbeat relay
- Cross-platform build (darwin/linux × aarch64/x86_64)
- Python legacy server removed — Rust-only architecture

#### P4b: Rust Server + TUI
- Axum HTTP server with all API endpoint groups ported
- SSE streaming and WebSocket support
- Mesh handoff via ssh2-rs
- Brain canvas wired to /ws/brain WebSocket
- Tailscale direct IP, socket tuning, delta batching
- Ratatui TUI with kanban, pipeline, mesh, org views
- Makefile with install tiers (minimal/standard/full)
- 99 Rust integration tests (Python tests migrated + new routes)

#### P5: Smart Agent Architecture (ADR-0038)
- Per-role instruction profiles (config/agent-profiles.yaml)
- Context loader script with token-budget capping
- Wired into copilot-worker.sh and delegate.sh
- Token benchmark enforces <12K per role

#### Nightly Jobs
- Dashboard widget with job history and create form
- nightly_job_definitions table for recurring job templates
- /api/nightly/jobs and /api/nightly/jobs/create Rust routes

#### Closure
- ADRs 0034-0038 for all phases