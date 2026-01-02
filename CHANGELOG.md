# Changelog

All notable changes to MyConvergio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
