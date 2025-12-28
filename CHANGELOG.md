# Changelog

All notable changes to MyConvergio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
