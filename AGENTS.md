# MyConvergio Agents

**v9.19.0** | 76 Claude Agent Files + 83 Copilot Agent Files | Multi-Provider Orchestrator
<!-- AGENT_COUNTS: claude:76 copilot:83 total:159 -->

> _"Intent is human, momentum is agent"_ — [The Agentic Manifesto](./AgenticManifesto.md)

## Overview

MyConvergio is an enterprise AI agent suite providing specialized assistance across strategy, development, compliance, operations, and orchestration. It supports both **Claude Code** (76 agent files) and **GitHub Copilot CLI** (83 agent files), enabling cross-tool agent discovery and unified workflows.

**Key Features**:

- 76 Claude agent files across 8 categories
- 83 Copilot agent files for GitHub Copilot users
- Multi-provider orchestration (Claude, Copilot CLI, OpenCode, Gemini)
- Modular installation tiers (minimal/standard/full)
- Lean variants (~50% smaller) for context optimization
- Built-in quality gates (Thor validation system)

## Agent Categories (Claude Code)

| Category              | Count | Key Agents                                                                            | Providers                      |
| --------------------- | ----- | ------------------------------------------------------------------------------------- | ------------------------------ |
| leadership_strategy   | 7     | ali (orchestrator), antonio, satya, dan                                               | Claude (opus), Gemini          |
| technical_development | 9     | baccio, rex, dario, otto, marco, paolo, luca, adversarial-debugger, task-executor-tdd | Claude (sonnet), Copilot --yolo |
| business_operations   | 11    | amy, anna, davide, marcello, oliver                                                   | Claude (sonnet)                |
| core_utility          | 11    | thor, strategic-planner, marcus, guardian, sentinel, thor-validation-gates            | Claude (opus)                  |
| release_management    | 3     | app-release-manager, feature-release-manager, app-release-manager-execution           | Claude (opus)                  |
| compliance_legal      | 5     | elena, dr-enzo, sophia                                                                | Claude (opus), OpenCode        |
| specialized_experts   | 14    | domik, behice, fiona, angela, ethan, evan, michael, research-report-generator         | Claude (sonnet), Gemini        |
| design_ux             | 3     | creative-director (5 skills), ux-designer, design-thinking                            | Claude (sonnet)                |

**Total**: 159 agent files (76 Claude + 83 Copilot)

### Model Tiering

- **opus** (6): Complex orchestration, critical decisions
- **sonnet** (24): Strategic specialists (architects, security, compliance)
- **haiku** (35): Workers, quick tasks, operational agents

### Agent Metadata

Each agent carries metadata describing its operational characteristics, constraints, and integration requirements.

**Maturity Lifecycle**:
- **alpha**: Experimental, unstable API, breaking changes possible
- **beta**: Stable API, feature-complete but under validation
- **stable**: Production-ready, backward-compatible releases
- **legacy**: Deprecated, no longer maintained (use recommended replacement)

**Constraints**:
- **context_limit**: Maximum input tokens (e.g., "16K" for Claude Haiku)
- **execution_timeout**: Max wall-clock seconds before cancellation
- **rate_limits**: Requests per minute (user + global)
- **cost_tier**: Operating cost category (free, cheap, premium)

**Handoffs**:
- **escalation_to**: Agent to invoke if current agent hits limits
- **dependencies**: Other agents that must run first
- **compatible_with**: List of agents safe to chain after this one

**Providers Field**:
Agents declare their supported AI providers as a prioritized list. Multi-provider routing (see README.md Multi-Provider Routing) uses this field to:
- Select optimal provider by cost, latency, or capability
- Enable fallback chains if primary provider unavailable or over budget
- Enforce constraints (e.g., sensitive data → OpenCode local only)
- Route tasks based on provider specialization (e.g., coding → Copilot --yolo)

Format: `providers: [{ name: "claude", model: "opus", priority: 1 }, { name: "gemini", priority: 2 }]`

**Example Agent Metadata**:
```yaml
name: thor-qa-guardian
maturity: stable
constraints:
  context_limit: 200K
  execution_timeout: 600
  cost_tier: premium
providers:
  - name: claude
    model: opus
    priority: 1
  - name: copilot
    priority: 2
escalation_to: ali-orchestrator
compatible_with: [execute, planner, strategic-planner]
```

## Copilot CLI Agents

MyConvergio ships **83 Copilot CLI agent files** in `copilot-agents/` for GitHub Copilot users:

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

Clones to `~/.myconvergio/`, copies all 76 Claude agent files to `~/.claude/agents/`, installs `myconvergio` CLI.

#### Option 3: Modular Install

```bash
myconvergio install --minimal                       # 9 core agents (~50KB)
myconvergio install --standard                      # 20 agents (~200KB)
myconvergio install --lean                          # 76 Claude agent files, 50% smaller
make install-tier TIER=minimal VARIANT=lean         # Same via Makefile
```

**Installation Tiers**:

- **minimal**: 9 agents (thor, strategic-planner, guardian, task-executor, etc.)
- **standard**: 20 agents (adds architects, core specialists)
- **full**: All 76 Claude agent files

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
**Quality Gates**: See `.claude/agents/core_utility/thor-validation-gates.md` (10 gates, enforced via `plan-db-safe.sh`)

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
│   ├── agents/             # <!-- AGENT_COUNT_MARKER -->74<!-- /AGENT_COUNT_MARKER --> agent files (single source of truth)
│   ├── rules/              # Coding standards, engineering guidelines
│   ├── skills/             # Reusable workflows
│   ├── scripts/            # 89+ utility scripts
│   ├── reference/          # Operational docs (on-demand)
│   └── CLAUDE.md           # Tool-specific config
├── copilot-agents/         # Copilot CLI agents
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

**Current**: v9.19.0
**Release Notes**: See `CHANGELOG.md`
**Versioning**: SemVer 2.0.0 (system + individual agents)

## Agent Deep-Dives

- [Agent Showcase](./docs/agents/agent-showcase.md) — Deep dive into 5 hero agents (Thor, Strategic Planner, Task Executor, Baccio, Ali)
- [Market Comparison](./docs/agents/comparison.md) — MyConvergio vs Squad, AutoGen, CrewAI, LangGraph, OpenAI Agents SDK

---

For detailed agent descriptions, see individual agent files in `agents/` (Claude Code) or `copilot-agents/` (Copilot CLI).
