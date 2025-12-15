# Changelog

All notable changes to MyConvergio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
