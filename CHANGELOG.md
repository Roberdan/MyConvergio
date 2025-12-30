# Changelog

All notable changes to MyConvergio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
