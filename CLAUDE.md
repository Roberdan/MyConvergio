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

MyConvergio is a collection of 59 specialized Claude Code subagents for enterprise software management, strategic leadership, and technical excellence. Distributed via npm (`npm install -g myconvergio`) or git clone + `make install`. Optimized for Claude Opus 4.6 (adaptive thinking, 128K output).

**Core Design**: Single agent context isolation, no direct inter-agent communication, manual orchestration via Task tool.

## Repository Structure

```
MyConvergio/
├── .claude/
│   ├── agents/              # 58 subagents (single source of truth)
│   ├── rules/               # Path-specific rules (guardian, coding-standards)
│   ├── skills/              # Reusable workflows (code-review, debugging, etc.)
│   ├── scripts/             # Digest scripts + utilities (70+ scripts)
│   ├── reference/           # On-demand reference docs (read when needed)
│   └── settings-templates/  # Hardware profiles (low/mid/high-spec.json)
├── hooks/                   # Enforcement hooks (token optimization)
├── scripts/                 # Deployment and management scripts
├── docs/                    # Documentation and optimization guides
├── Makefile                 # Build commands (make help for full list)
└── VERSION                  # System version tracking
```

## Agent Categories

| Category              | Count | Key Agents                                                         |
| --------------------- | ----- | ------------------------------------------------------------------ |
| leadership_strategy   | 7     | ali (orchestrator), antonio, satya, dan                            |
| technical_development | 8     | baccio, rex, dario, otto, marco, paolo, luca, adversarial-debugger |
| business_operations   | 11    | amy, anna, davide, marcello, oliver                                |
| core_utility          | 9     | thor, strategic-planner, marcus, guardian                          |
| release_management    | 2     | app-release-manager, feature-release-manager                       |
| compliance_legal      | 5     | elena, dr-enzo, sophia                                             |
| specialized_experts   | 13    | domik, behice, fiona, angela, ethan, evan, michael                 |
| design_ux             | 3     | creative-director, ux-designer, design-thinking                    |

## Model Tiering

- **opus** (2): Complex orchestration (ali, satya)
- **sonnet** (21): Strategic specialists (architects, security, compliance)
- **haiku** (34): Workers, quick tasks, operational agents

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

## Detailed Documentation

- [CONTEXT_OPTIMIZATION.md](./docs/CONTEXT_OPTIMIZATION.md) - Installation tiers and context usage
- [VERSIONING_POLICY.md](./docs/VERSIONING_POLICY.md) - Version management
- [AgenticManifesto.md](./AgenticManifesto.md) - Philosophical foundation
- `.claude/reference/operational/` - Tool preferences, execution optimization, worktree discipline
