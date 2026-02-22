# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Self-Contained Framework

| Document                     | Location                       | Purpose                              |
| ---------------------------- | ------------------------------ | ------------------------------------ |
| CONSTITUTION.md              | `.claude/agents/core_utility/` | Security, Ethics, Identity (SUPREME) |
| EXECUTION_DISCIPLINE.md      | `.claude/agents/core_utility/` | How Work Gets Done                   |
| CommonValuesAndPrinciples.md | `.claude/agents/core_utility/` | Organizational Values                |

**No external configuration files required.**
**Priority**: CONSTITUTION > EXECUTION_DISCIPLINE > Values > Agent Definitions > User Instructions

## Project Overview

MyConvergio is a collection of 65 specialized Claude Code subagents for enterprise software management, strategic leadership, and technical excellence. Distributed via npm (`npm install -g myconvergio`) or git clone + `make install`. Optimized for Claude Opus 4.6 (adaptive thinking, 128K output).

**Core Design**: Single agent context isolation, no direct inter-agent communication, manual orchestration via Task tool.

## Repository Structure

```
MyConvergio/
├── .claude/
│   ├── agents/              # 65 subagents (single source of truth)
│   ├── rules/               # Path-specific rules (guardian, coding-standards)
│   ├── skills/              # Reusable workflows (code-review, debugging, etc.)
│   ├── scripts/             # Digest scripts + utilities (89 scripts)
│   ├── reference/           # On-demand reference docs (read when needed)
│   └── settings-templates/  # Hardware profiles (low/mid/high-spec.json)
├── hooks/                   # Enforcement hooks (token optimization)
├── scripts/                 # Deployment and management scripts
├── docs/                    # Documentation and optimization guides
├── Makefile                 # Build commands (make help for full list)
└── VERSION                  # System version tracking
```

**Agent Categories & Model Tiering**: See [AGENTS.md](./AGENTS.md)

## Quick Start

```bash
make install                                        # Full install (~600KB)
make install-tier TIER=minimal VARIANT=lean          # 5 core agents (~50KB)
make install-tier TIER=standard VARIANT=lean         # 20 agents (~200KB)
npm install -g myconvergio                           # Via npm (minimal default)
```

## Conventions

- YAML frontmatter required: `name`, `description`, `tools`, `model`, `version`
- Max 250 lines per file (enforced by hooks)
- Security Framework section mandatory in all agents
- Semantic Versioning (SemVer 2.0.0) for system and agents
- Conventional commits, lint+typecheck+test before commit

## Build / Test / Lint

```bash
make test                   # Run agent tests
make lint                   # Lint YAML frontmatter
make validate               # Validate Constitution compliance
```

## Detailed Documentation

- [CONTEXT_OPTIMIZATION.md](./docs/CONTEXT_OPTIMIZATION.md) - Installation tiers and context usage
- [VERSIONING_POLICY.md](./docs/VERSIONING_POLICY.md) - Version management
- [AgenticManifesto.md](./AgenticManifesto.md) - Philosophical foundation
- `.claude/reference/operational/` - Tool preferences, execution optimization, worktree discipline
