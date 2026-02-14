# Changelog

All notable changes to MyConvergio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.7.1] - 2026-02-14

### Fixed

- **selective-install.sh**: Removed `local` keyword from 7 occurrences outside functions (fixes `make install-tier`, closes #1)

---

## [4.7.0] - 2026-02-14

### Added

- **Agent Teams support**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var in all settings templates
- **TeammateIdle/TaskCompleted hooks**: Track team events in token dashboard (all settings tiers)
- **Setup hook**: Auto-detect Claude Code version changes via version-check.sh (high-spec)
- **memory field**: Added to all 60 invocable agents (user/project scope based on category)
- **maxTurns field**: Added to all 60 invocable agents (15-50 based on role complexity)

### Changed

- **TodoWrite → Tasks API**: Migrated strategic-planner, ali-chief-of-staff, anna-executive-assistant to TaskCreate/TaskList/TaskGet/TaskUpdate
- **EXECUTION_DISCIPLINE.md**: Updated TodoWrite reference to TaskCreate
- **track-tokens.sh**: Added teammate-idle and task-completed event handling
- **Settings templates**: Added AGENT_TEAMS env var

### Fixed

- Agent frontmatter alignment with Claude Code v2.1.42 schema (memory, maxTurns fields)

---

## [4.6.0] - 2026-02-07

### Added

- **adversarial-debugger agent** (v1.0.0): Spawns 3 parallel Explore subagents with competing hypotheses for complex bug diagnosis. Read-only, evidence-based, adversarial pattern inspired by Agent Teams.
- **plan-db-safe.sh**: Wrapper around plan-db.sh with pre-checks (file existence, lint, untracked tests) before allowing update-task done transitions.

### Changed

- **Settings templates**: Removed deprecated `MAX_THINKING_TOKENS` from all tiers (Opus 4.6 uses adaptive thinking). Doubled `CLAUDE_CODE_MAX_OUTPUT_TOKENS` across all tiers (high: 128K, mid: 64K, low: 32K) to leverage Opus 4.6 128K output support.
- **CLAUDE.md**: Updated agent count (59), added Opus 4.6 optimization note, added adversarial-debugger to technical_development category.

### Removed

- `MAX_THINKING_TOKENS` env var from all settings templates (deprecated on Opus 4.6, replaced by adaptive thinking with effort levels).

---

## [4.5.0] - 2026-02-07

### Added

- **Hooks System**: 10 enforcement hooks + lib for token optimization (~21k tokens saved/session)
  - `prefer-ci-summary.sh`: Blocks verbose CLI commands, enforces digest scripts
  - `enforce-line-limit.sh`: PostToolUse guard for 250-line file limit
  - `worktree-guard.sh`: Prevents destructive git operations on main
  - `warn-bash-antipatterns.sh`: Flags cat/grep/find when Read/Grep/Glob preferred
  - `auto-format.sh`: Auto-runs prettier/eslint on edited files
  - `inject-agent-context.sh`: Loads project context for subagent launches
  - `preserve-context.sh`: Saves context before compaction
  - `session-end-tokens.sh`: Logs token usage on session end
  - `track-tokens.sh`: Tracks cumulative token usage
  - `lib/common.sh`: Shared utilities for all hooks
- **Digest Scripts**: 14 token-optimized CLI wrappers replacing verbose commands
  - git-digest, build-digest, test-digest, npm-digest, audit-digest, ci-digest,
    diff-digest, error-digest, merge-digest, migration-digest, pr-digest,
    service-digest, deploy-digest, ci-check
- **Reference Documentation**: 7 on-demand docs in `.claude/reference/operational/`
  - tool-preferences, execution-optimization, memory-protocol, continuous-optimization,
    worktree-discipline, external-services, codegraph
- **Settings Templates**: Hardware-specific hooks configuration
  - `high-spec.json`: Full 11 hooks (PreToolUse, PostToolUse, SubagentStart, PreCompact, Stop)
  - `mid-spec.json`: 7 hooks (no sqlite3-dependent Stop hook)
  - `low-spec.json`: 3 essential hooks (worktree-guard, prefer-ci-summary, enforce-line-limit)
- **Rules**: Added `coding-standards.md` matching global Claude config

### Changed

- **CLAUDE.md (root)**: Compacted from 653 to 82 lines (87% reduction)
- **guardian.md**: Replaced with compact 29-line version matching global config
- **Makefile**: Updated install/clean/version targets for hooks, reference, scripts
- **bin/myconvergio.js**: Install/backup/uninstall now handles hooks + reference directories
- **scripts/postinstall.js**: npm postinstall now copies hooks + reference + chmod +x
- **package.json**: Added hooks/ and .claude/reference/ to files array, version 4.5.0
- **.claude/CLAUDE.md**: Fixed model reference ("Claude Code"), line limit (250)

### Improved

- **Token Optimization**: Hooks + digest scripts save ~21k tokens per session
- **Install System**: Full coverage of all components (agents, rules, skills, hooks, reference, scripts)
- **Global Config Alignment**: Rules, hooks, and settings now match author's optimized ~/.claude/
- **Agent Compaction**: All 16 oversized agents trimmed to max 250 lines (total -3308 lines)
  - Heavy agents split into compact core + `.claude/reference/` docs
  - 4 new reference docs: task-executor-workflow, app-release-checklist, ali-orchestration-protocol, strategic-planner-modules
- **Skill Compaction**: All 6 oversized skills trimmed to max 250 lines (-804 lines)
- **Removed**: `thor-quality-assurance-guardian.lean.md` (was larger than full version)
- **Fixed**: `commands/status.md` — agent count (57→58), version (3.0.0→4.5.0)
- **Fixed**: "Claude 4.5" outdated references → generic model-agnostic text

## [4.4.0] - 2026-01-27

### Added

- **Context Isolation**: Added `context_isolation: true` to key agents for token optimization
  - task-executor, thor-quality-assurance-guardian, strategic-planner
- **Skills Frontmatter**: All 9 skills now have YAML frontmatter with:
  - `context: fork` for isolated execution
  - `allowed-tools` for security boundaries
  - `user-invocable: true` for slash command access

### Changed

- **task-executor** (v1.5.0): Added TDD workflow, disallowedTools, context isolation
- **thor-quality-assurance-guardian** (v3.3.0): Fixed tools (removed invalid LS, added Bash+Task), context isolation
- **strategic-planner** (v2.0.0): Updated to opus model, context isolation

### Fixed

- **plugin.json**: Version aligned with package.json (was 3.0.0, now 4.4.0)
- **Invalid "LS" tool**: Replaced in 5 agents (diana, marcus, socrates, ava, baccio)
- **Invalid custom tools**: Cleaned anna-executive-assistant, ali-chief-of-staff, guardian-ai-security-validator
- **Missing fields**: Added tools/color to app-release-manager, feature-release-manager
- **Malformed frontmatter**: Fixed feature-release-manager YAML structure

### Improved

- **Token Optimization**: Context isolation reduces token usage by 50-70% per subagent call
- **Claude Code 2.1.20 Alignment**: All configurations aligned with latest Claude Code features

## [4.3.0] - 2026-01-18

### Added

- **Strategic Planner Modules**: Extracted reusable modules from strategic-planner.md
  - `strategic-planner-templates.md`: Plan document templates and formats
  - `strategic-planner-thor.md`: Thor validation gate integration
  - `strategic-planner-git.md`: Git worktree workflow for parallel execution
- **Worktree Scripts**: New shell scripts for worktree management
  - `worktree-create.sh`: Creates worktree with automatic .env symlinks
  - `worktree-check.sh`: Shows current git context with worktree verification

### Changed

- **guardian.md**: Updated rules with performance gates and zero technical debt enforcement
- **Dashboard Kanban**: Enhanced with git state snapshot, validation badges, and confidence indicators

### Improved

- **Git State Tracking**: Plans now capture `git_clean_at_closure` status
- **Kanban UX**: Better visual indicators for validation status (Verified/Unverified/Inconsistent)

## [4.2.0] - 2026-01-10

### Added

- **Enhanced Route Handling**: Server now passes `url` parameter to route handlers for query string access
- **Token Aggregation**: Plan tokens now aggregate from both `token_usage` table and `tasks.tokens` field

### Changed

- **Dashboard Sync**: Full synchronization of dashboard components from development environment
  - Updated server.js with improved route handling
  - Updated routes-plans-core.js with token aggregation and computed wave dates
  - Updated routes-notifications.js with proper JSON body parsing
  - Updated 9 JS modules (charts, gantt-core/render/view, github-data, toast, unified-waves, views-core/secondary)
  - Updated 12 CSS files (gantt-\*, bug-tracker, main)

### Fixed

- **Token Display**: Token statistics now correctly aggregate from all sources
- **Wave Dates**: Wave started_at and completed_at now computed from tasks when null
- **Notification API**: Fixed JSON body parsing for POST requests
- **Portability**: Removed all project-specific references (replaced with generic examples)
  - Updated EXECUTOR_TRACKING.md with generic project names
  - Updated IMPLEMENTATION_STATUS.md with generic examples
  - Updated docs/projects.md with template content
  - Updated strategic-planner.md examples
  - Fixed dashboard default labels

## [3.8.0] - 2026-01-03

### Added

- **EXECUTION_DISCIPLINE.md**: New foundational document defining execution standards
  - Location: `.claude/agents/core_utility/EXECUTION_DISCIPLINE.md`
  - 10 articles covering planning, verification, error recovery, parallel execution, quality gates, git discipline
  - Second in priority after CONSTITUTION.md
  - Single source of truth for all execution rules

- **Example CLAUDE.md Configuration**: Template for users integrating MyConvergio
  - Location: `docs/examples/CLAUDE.md`
  - Portable template showing agent invocation and framework reference

### Changed

- **Self-Contained Repository**: Repository now fully self-contained and publishable
  - Removed all external configuration dependencies
  - Removed all hardcoded author-specific paths (e.g. `/Users/NAME/` → generic paths)
  - No SmartClaude.md or external file references

- **.claude/CLAUDE.md**: Refactored using Reference Model
  - Reduced from 257 lines to 119 lines (54% reduction)
  - Removed duplicated execution rules (now in EXECUTION_DISCIPLINE.md)
  - Retains only: project context, agent development, architecture, references

- **Root CLAUDE.md**: Added self-contained framework declaration

### Improved

- **Context Efficiency**: ~4,000 tokens saved per session by eliminating duplication
- **Document Hierarchy**: Clear priority order established
  - CONSTITUTION > EXECUTION_DISCIPLINE > Values > Agent Definitions > User Instructions

### Fixed

- Removed 27+ hardcoded `/Users/NAME/` paths across 10 files
- Fixed all test documentation paths to use relative/generic paths

## [4.1.0] - 2026-01-07

### Added

- **Dashboard Overhaul**: Modular UI with Gantt timeline, kanban views, markdown viewer, conversation viewer, and bug tracking
- **Dashboard API Tests**: Comprehensive API test suites and reports
- **Plan-DB Utilities**: New migration helpers, validators, and quick reference docs
- **Task Executor Agent**: Added `task-executor.md` to `.claude/agents/technical_development/`
- **Workflow Guide**: New `docs/workflow.md` covering Prompt → Planner → Execution → Thor → Dashboard

### Changed

- **Global Config Sync**: Updated rules, commands, scripts, and agents to match latest global config
- **Documentation Refresh**: Dashboard and orchestration docs updated for new capabilities
- **Portability**: Removed author-specific paths from public docs and routing rules

### Fixed

- **Constitution Compliance**: Added missing articles for CI validation

## [3.7.0] - 2026-01-02

### Added

- **Context Optimization System**: Three-tier installation profiles with hardware-aware configuration
  - **Minimal Profile** (8 agents, ~50KB): Core development agents for low-memory systems (8GB RAM)
  - **Standard Profile** (20 agents, ~200KB): Balanced coverage for mid-tier systems (16GB RAM) - now default
  - **Full Profile** (57 agents, ~600KB): Complete ecosystem for high-end systems (32GB+ RAM)
  - **Lean Agent Variants**: Stripped versions with ~50% context reduction, preserving full functionality
  - **Consolidated Rules**: Single `engineering-standards.md` (3.6KB, 93% smaller than detailed rules)

- **Enhanced CLI Commands**: `myconvergio install` now supports installation profiles
  - `--minimal` flag: Install 8 core agents (~50KB context)
  - `--standard` flag: Install 20 essential agents (~200KB context)
  - `--full` flag: Install all 57 agents (~600KB context)
  - `--lean` flag: Use lean agent variants for any profile (~50% context reduction)

- **Hardware-Specific Settings Templates**: Pre-configured settings for three hardware tiers
  - `docs/templates/settings-low.json`: 8GB RAM, 4 cores (MacBook Air, entry laptops)
  - `docs/templates/settings-mid.json`: 16GB RAM, 8 cores (M1/M2 MacBook Pro, standard workstations)
  - `docs/templates/settings-high.json`: 32GB+ RAM, 12+ cores (M3 Max, high-end workstations)

- **Comprehensive Documentation**:
  - `docs/CONTEXT_OPTIMIZATION.md`: Complete guide to context optimization strategies
    - Performance impact analysis
    - Hardware-specific recommendations
    - Context budget table with token estimates
    - Installation examples for common scenarios
    - Troubleshooting guide for performance issues
  - Updated README with new installation workflow and profile selection

- **npm Postinstall Enhancement**: `MYCONVERGIO_PROFILE` environment variable support
  - `MYCONVERGIO_PROFILE=minimal npm install -g myconvergio`: Install minimal profile
  - `MYCONVERGIO_PROFILE=standard npm install -g myconvergio`: Install standard profile (default)
  - `MYCONVERGIO_PROFILE=full npm install -g myconvergio`: Install full profile

- **Lean Agent Variants**:
  - `thor-quality-assurance-guardian.lean.md`: 50% smaller, full functionality
  - `dario-debugger.lean.md`: Optimized debugging agent
  - Auto-generation script: `scripts/generate-lean-variants.sh --all`

### Changed

- **Default Installation Profile**: Changed from `full` to `standard` for npm postinstall
  - Reduces initial context from ~600KB to ~200KB
  - Users can opt-in to full profile with `MYCONVERGIO_PROFILE=full`
  - Provides better out-of-box experience for most users

- **CLI Help Text**: Enhanced with profile descriptions and context size estimates

- **bin/myconvergio.js**: Refactored `install()` function to support profile-based installation
  - Added `getAgentsForProfile()` helper
  - Added `copyAgentsByProfile()` for selective agent copying
  - Interactive mode if no profile specified

- **package.json**: Updated files array to include `docs/` directory

### Improved

- **Installation Performance**: Standard profile installs 70% fewer files than previous default (full)
- **Memory Usage**: Lean variants reduce Claude Code memory footprint by ~40-50%
- **Response Time**: Smaller context improves Claude response latency
- **Hardware Compatibility**: Now optimized for systems with 8GB-64GB RAM

### Performance Metrics

- **Minimal Profile (Lean)**: ~29KB context (~14K tokens), <1s load time, 400MB memory
- **Standard Profile (Lean)**: ~104KB context (~52K tokens), ~1s load time, 600MB memory
- **Full Profile (Full)**: ~604KB context (~302K tokens), 3-5s load time, 1.2GB memory

## [3.6.0] - 2025-12-31 15:01 CET

### Added

- **Universal Multi-Terminal Orchestration**: Expanded beyond Kitty to support all terminals
  - `orchestrate.sh`: Universal entry point with automatic terminal detection
  - `detect-terminal.sh`: Smart terminal type detection (kitty/tmux/plain)
  - **tmux Support**: Full tmux-based orchestration for Zed, Warp, iTerm, and any terminal
    - `tmux-parallel.sh`: Launch N parallel Claude instances in tmux windows
    - `tmux-monitor.sh`: Monitor tmux workers with live status updates
    - `tmux-send-all.sh`: Broadcast messages to all workers simultaneously
  - **Terminal Detection Matrix**:
    - Kitty → Uses native `kitty @ send-text` remote control
    - Zed/Warp/iTerm → Uses tmux session orchestration
    - tmux (already running) → Uses existing tmux session
    - Plain terminal → Prompts to install tmux

### Changed

- **scripts/orchestration/README.md**: Complete rewrite for multi-terminal support
  - Quick Start section with auto-detection workflow
  - Terminal support comparison table (Kitty vs tmux vs plain)
  - Separate setup instructions for Kitty users vs Other terminal users
  - tmux navigation guide (Ctrl+B shortcuts)
  - Zed editor integration examples with keymap/tasks.json
  - Updated troubleshooting for both Kitty and tmux scenarios

### Improved

- **Orchestration Accessibility**: No longer requires Kitty terminal
  - Works from ANY terminal (Zed, Warp, iTerm, VS Code integrated terminal, etc.)
  - Automatically falls back to tmux if Kitty not detected
  - Maintains backward compatibility with existing Kitty-based workflows
  - Enables parallel Claude orchestration for all users regardless of terminal choice

## [3.5.0] - 2025-12-30

### Added

- **Thor Quality Assurance System**: Complete validation gatekeeper for multi-Claude orchestration
  - `thor-quality-assurance-guardian` v2.0.0: Brutal quality gatekeeper with full tool access
  - Queue-based validation service at `/tmp/thor-queue/`
  - Dual-channel communication: file-based (persistent) + Kitty (real-time)
  - 7 validation gates: Task Compliance, Code Quality, Engineering Fundamentals, Repository Compliance, Documentation, Git Hygiene, Brutal Challenge
  - 10 mandatory challenge questions asked to every worker
  - Specialist delegation: Thor can invoke Baccio (architecture), Luca (security), Otto (performance), Rex (code review)
  - Response types: APPROVED, REJECTED, CHALLENGED, ESCALATED
  - Retry management with escalation to Roberto after 3 failures
  - Validates orchestrators too (Planner, Ali) - no one exempt

- **Thor Validation Protocol** v1.0.1: Complete communication specification
  - Request/response JSON formats
  - Worker submission flow with evidence gathering
  - Audit logging in JSONL format

- **Thor Worker Instructions** v1.0.0: Mandatory rules for all Claude workers
  - Step-by-step validation flow
  - "You are NOT done until Thor says you are done" enforcement
  - Common mistakes that get rejected

- **Scripts for Thor System**:
  - `scripts/thor-queue-setup.sh`: Initialize validation queue directories
  - `scripts/thor-worker-submit.sh`: Submit validation requests with auto-evidence gathering
  - `scripts/thor-monitor.sh`: Monitor queue status and recent validations

### Changed

- **strategic-planner** v1.6.0 → v1.6.1: Added mandatory THOR VALIDATION GATE section
  - All workers must get Thor approval before claiming task complete
  - Thor launch instructions for Kitty tab
  - Worker validation flow with bash examples
  - Fixed heredoc quoting bug preventing variable expansion
- **.gitignore**: Added `.claude/protocols/` to tracked directories

### Fixed

- Heredoc variable expansion bugs in planner and protocol documentation
- JSON escaping for git output in thor-worker-submit.sh (newlines/quotes)
- Architecture diagram role labels (Claude-1 is Planner, not Claude-4)
- Missing Return key press in Kitty notifications

## [3.4.0] - 2025-12-30

### Added

- **strategic-planner**: Mandatory GIT WORKFLOW section
  - Git worktree workflow for parallel development on independent tasks
  - PR workflow enforcement: feature branches → PR → review → merge
  - Branch naming conventions (feature/, fix/, hotfix/)
  - Never merge directly to main/master rule

### Changed

- strategic-planner: v1.4.0 (added GIT WORKFLOW requirements)

## [3.3.0] - 2025-12-30

### Added

- **strategic-planner v1.4.0**: Full Inter-Claude Communication Protocol
  - Bidirectional messaging: Coordinator ↔ Worker, Worker ↔ Worker communication
  - Worker → Coordinator status reports for progress updates
  - Worker → Worker direct synchronization for dependency coordination
  - Broadcast notifications (one-to-all) for urgent alerts and gate unlocks
  - Gate unlock notification patterns for phase synchronization
  - Help request patterns for worker collaboration
  - Message format convention: `[SENDER]: [EMOJI] [CONTENT]`
  - Emoji reference table for quick message parsing (✅ ✓ 🟢 🔴 🚨 ❓ 📊 ⏳)
  - Six documented communication scenarios with code examples

### Changed

- strategic-planner: v1.3.3 → v1.4.0 (expanded communication protocol)

## [3.2.0] - 2025-12-29

### Added

- **strategic-planner v1.3.3**: Critical improvements for execution quality and compliance
  - Mandatory WAVE FINAL with 6 documentation tasks (README, CHANGELOG, Tests, Docs, PR Description, ADRs)
  - Documentation Rules in NON-NEGOTIABLE section ensuring all deliverables are properly documented
  - ISE Engineering Fundamentals requirement with Microsoft playbook link (https://microsoft.github.io/code-with-engineering-playbook/)

### Fixed

- **strategic-planner v1.3.3**: Kitty send-text commands now include `\r` for auto-execution
  - Previously commands were sent but not executed, requiring manual Enter key press
  - Now all worker commands execute automatically when sent via `kitty @ send-text`

### Changed

- strategic-planner: v1.3.0 → v1.3.3 (execution quality and documentation enforcement)

## [3.1.0] - 2025-12-29

### Added

- **strategic-planner v1.3.0**: Complete multi-Claude orchestration framework
  - Phase Gates synchronization system for coordinating parallel workers
  - Polling protocol for Claude instance progress tracking
  - Coordinator responsibilities and delegation rules
  - NON-NEGOTIABLE RULES for execution discipline
  - CLAUDE ROLES STRUCTURE defining Worker/Coordinator behaviors
  - EXECUTION TRACKER with GitHub Issue linkage (#xxx syntax)
  - TIME STATISTICS dashboard for wave/phase duration tracking
  - Clean Markdown dashboard format without code fences
  - Enhanced parallel execution patterns for complex projects

### Changed

- strategic-planner: v1.1.0 → v1.3.0 (major orchestration framework update)

## [2.2.0] - 2025-12-28

### Added

- **Multi-Claude Parallel Orchestration**: Execute complex plans with up to 4 parallel Claude instances via Kitty terminal
- `scripts/orchestration/` directory with orchestration tooling:
  - `claude-parallel.sh` - Launch N parallel Claude workers in Kitty tabs
  - `claude-monitor.sh` - Real-time monitoring of worker progress
  - `kitty-check.sh` - Verify Kitty terminal configuration
  - `README.md` - Complete setup and usage documentation
- `.claude/skills/orchestration/SKILL.md` - Orchestration skill documentation
- strategic-planner agent: Kitty parallel orchestration support (v1.1.0)
  - Wave-based execution with parallel agent assignments
  - Automatic worker launching and monitoring
  - File overlap prevention to avoid git conflicts

### Changed

- strategic-planner: v0.1.0 → v1.1.0 (parallel orchestration capability)

## [2.1.2] - 2025-12-28

### Added

- `myconvergio agents` command to list all installed agents with versions and model tiers

### Fixed

- Repository URL case sensitivity for npm OIDC trusted publishing (Roberdan vs roberdan)
- Postinstall now always creates backup if existing content found (not just if manifest exists)
- Postinstall output now visible during npm install (uses stderr)
- Consistent backup behavior between postinstall.js and CLI

## [2.1.0] - 2025-12-28

### Added

- **npm distribution**: `npm install -g myconvergio` (cross-platform: macOS, Linux, Windows)
- `myconvergio` CLI with install, uninstall, version commands
- ADR-011: Modular Execution Plans and Enhanced Security Framework
- Modular Execution Plan Structure for large projects (15+ tasks) in taskmaster and davide agents
- Mandatory test requirements per phase in execution plans
- Security & Anti-Manipulation framework in CommonValuesAndPrinciples (prompt injection protection, ethical boundaries, inclusive language)

### Changed

- taskmaster-strategic-task-decomposition-master: v1.0.2 → v1.0.3
- davide-project-manager: v1.0.2 → v1.0.3
- CommonValuesAndPrinciples: Added ~90 lines of security guidelines
- Makefile: Now installs agents, rules, AND skills (was agents-only)
- Makefile: Added `make upgrade` command for existing users
- README: Complete rewrite of installation section with npm as primary method

## [2.0.1] - 2025-12-15

### Fixed

- Excluded `MICROSOFT_VALUES.md` from YAML frontmatter validation in test scripts and Makefile lint command
- Documentation files (CONSTITUTION.md, CommonValuesAndPrinciples.md, SECURITY_FRAMEWORK_TEMPLATE.md, MICROSOFT_VALUES.md) are now properly excluded from agent validation

## [2.0.0] - 2025-12-15

### Added

- Complete README rewrite with accurate agent architecture documentation
- 57 specialized Claude Code subagents across 8 categories
- Git worktree workflow documentation for parallel agent development
- Agent versioning system with semantic versioning support
- Comprehensive rules system (code-style, security, testing, documentation, API, ethics)
- Skills system extracted from specialist agent expertise
- Activity logging framework for agent accountability
- Security framework template for all agents
- Model tiering (opus/sonnet/haiku) for cost optimization

### Changed

- Clarified that agents operate in isolated contexts without direct inter-agent communication
- Updated coordination flow documentation to reflect manual orchestration pattern
- Reorganized agent categories into logical groupings

### Fixed

- Corrected README to reflect actual agent architecture (context isolation, manual orchestration)

## [1.0.0] - 2025-12-14

### Added

- Initial release of MyConvergio agent ecosystem
- Core agent framework with CONSTITUTION.md
- Basic agent deployment via Makefile
- Test suite for agent validation
