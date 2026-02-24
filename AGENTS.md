# MyConvergio Agents

**v9.3.0** | 65 Claude Code Agents + 9 Copilot CLI Agents | Multi-Provider Orchestrator

> _"Intent is human, momentum is agent"_ — [The Agentic Manifesto](./AgenticManifesto.md)

## Overview

MyConvergio is an enterprise AI agent suite providing specialized assistance across strategy, development, compliance, operations, and orchestration. It supports both **Claude Code** (65 agents) and **GitHub Copilot CLI** (9 agents), enabling cross-tool agent discovery and unified workflows.

**Key Features**:

- 65 specialized Claude agents across 8 categories
- 9 Copilot CLI agents for GitHub Copilot users
- Multi-provider orchestration (Claude, Copilot CLI, OpenCode, Gemini)
- Modular installation tiers (minimal/standard/full)
- Lean variants (~50% smaller) for context optimization
- Built-in quality gates (Thor validation system)

## Agent Categories (Claude Code)

| Category              | Count | Key Agents                                                                            |
| --------------------- | ----- | ------------------------------------------------------------------------------------- |
| leadership_strategy   | 7     | ali (orchestrator), antonio, satya, dan                                               |
| technical_development | 9     | baccio, rex, dario, otto, marco, paolo, luca, adversarial-debugger, task-executor-tdd |
| business_operations   | 11    | amy, anna, davide, marcello, oliver                                                   |
| core_utility          | 11    | thor, strategic-planner, marcus, guardian, sentinel, thor-validation-gates            |
| release_management    | 3     | app-release-manager, feature-release-manager, app-release-manager-execution           |
| compliance_legal      | 5     | elena, dr-enzo, sophia                                                                |
| specialized_experts   | 14    | domik, behice, fiona, angela, ethan, evan, michael, research-report-generator         |
| design_ux             | 3     | creative-director (5 skills), ux-designer, design-thinking                            |

**Total**: 65 agents (including 2 constitutional documents: CONSTITUTION.md, CommonValuesAndPrinciples.md)

### Model Tiering

- **opus** (6): Complex orchestration, critical decisions
- **sonnet** (24): Strategic specialists (architects, security, compliance)
- **haiku** (35): Workers, quick tasks, operational agents

## Copilot CLI Agents

MyConvergio ships **9 Copilot CLI agents** in `copilot-agents/` for GitHub Copilot users:

| Agent               | Purpose                                      |
| ------------------- | -------------------------------------------- |
| @code-reviewer      | Code review with security + quality checks   |
| @compliance-checker | Verify compliance requirements               |
| @ecosystem-sync     | Cross-repo synchronization with sanitization |
| @execute            | Task executor with Thor validation           |
| @planner            | Multi-wave strategic planning                |
| @prompt             | Extract feature requests into plan templates |
| @strategic-planner  | High-level roadmap and architecture          |
| @tdd-executor       | TDD-enforced task execution                  |
| @validate           | Wave/task validation with quality gates      |

## Installation

### Claude Code

#### Option 1: Clone & Use (Recommended)

```bash
git clone https://github.com/roberdan/MyConvergio.git
cd MyConvergio
claude --plugin-dir .
```

#### Option 2: Curl Install (Full)

```bash
curl -sSL https://raw.githubusercontent.com/roberdan/MyConvergio/main/install.sh | bash
```

Clones to `~/.myconvergio/`, copies all 65 agents to `~/.claude/agents/`, installs `myconvergio` CLI.

#### Option 3: Modular Install

```bash
myconvergio install --minimal                       # 9 core agents (~50KB)
myconvergio install --standard                      # 20 agents (~200KB)
myconvergio install --lean                          # 65 agents, 50% smaller
make install-tier TIER=minimal VARIANT=lean         # Same via Makefile
```

**Installation Tiers**:

- **minimal**: 9 agents (thor, strategic-planner, guardian, task-executor, etc.)
- **standard**: 20 agents (adds architects, core specialists)
- **full**: All 65 agents

### Copilot CLI

```bash
# Copy agents to Copilot config
cp copilot-agents/*.agent.md ~/.copilot/agents/

# Or symlink for auto-updates
ln -sf "$(pwd)/copilot-agents"/*.agent.md ~/.copilot/agents/

# Verify
gh copilot --list-agents
```

## Usage

### Claude Code

Invoke any agent by name:

```bash
# In Claude Code
@ali Create a 3-month roadmap for API migration
@baccio Review this architecture for scalability issues
@thor Validate the current task against quality gates
```

### Copilot CLI

```bash
# Via GitHub CLI
gh copilot @planner "Create a plan for migrating to Next.js 15"
gh copilot @execute "Implement authentication with NextAuth"
gh copilot @code-reviewer "Review PR #123 for security issues"
```

**Coding Standards**: See `.claude/rules/coding-standards.md`
**Quality Gates**: See `.claude/agents/core_utility/thor-validation-gates.md` (9 gates, enforced via `plan-db-safe.sh`)

## Development Commands

```bash
# Testing
make test                   # Run agent tests
make lint                   # Lint YAML frontmatter
make validate               # Validate Constitution compliance

# Installation Management
make upgrade                # Update to latest version
make clean                  # Remove all installed components
make version                # Show version info

# Modular Installation
make list-tiers             # Show available tiers
make list-categories        # Show agent categories
make install-tier TIER=minimal VARIANT=lean RULES=consolidated
```

## Configuration

For tool-specific configuration, environment setup, and operational guidelines, see:

- **Claude Code**: `.claude/CLAUDE.md` (agent routing, model tiering, workflow)
- **Repository Root**: `CLAUDE.md` (high-level conventions, quick start)
- **Reference Docs**: `.claude/reference/operational/` (digest scripts, worktree discipline)
- **Coding Standards**: `.claude/rules/coding-standards.md`
- **Testing Standards**: `.claude/rules/testing-standards.md`

## Repository Structure

```
MyConvergio/
├── .claude/                # Claude Code configuration
│   ├── agents/             # 65 subagents (single source of truth)
│   ├── rules/              # Coding standards, engineering guidelines
│   ├── skills/             # Reusable workflows
│   ├── scripts/            # 89+ utility scripts
│   ├── reference/          # Operational docs (on-demand)
│   └── CLAUDE.md           # Tool-specific config
├── agents/                 # Agent definitions (deployed to ~/.claude/agents/)
├── copilot-agents/         # 9 Copilot CLI agents
├── hooks/                  # Enforcement hooks (token optimization)
├── scripts/                # Deployment and management
├── docs/                   # Documentation
│   ├── CONTEXT_OPTIMIZATION.md
│   ├── VERSIONING_POLICY.md
│   └── adr/                # Architecture Decision Records
├── Makefile                # Build commands
├── CLAUDE.md               # High-level config (repo root)
├── AGENTS.md               # This file
└── VERSION                 # System version tracking
```

## Support

- **Issues**: https://github.com/Roberdan/MyConvergio/issues
- **Documentation**: See `docs/` directory
- **ADRs**: Architecture decisions in `docs/adr/`
- **License**: CC BY-NC-SA 4.0 (non-commercial)

## Version

**Current**: v9.3.0
**Release Notes**: See `CHANGELOG.md`
**Versioning**: SemVer 2.0.0 (system + individual agents)

## Agent Deep-Dives

- [Agent Showcase](./docs/agents/agent-showcase.md) — Deep dive into 5 hero agents (Thor, Strategic Planner, Task Executor, Baccio, Ali)
- [Market Comparison](./docs/agents/comparison.md) — MyConvergio vs Squad, AutoGen, CrewAI, LangGraph, OpenAI Agents SDK

---

For detailed agent descriptions, see individual agent files in `agents/` (Claude Code) or `copilot-agents/` (Copilot CLI).
