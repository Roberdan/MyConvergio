<div align="center">

# MyConvergio - Claude Code Subagents Suite

<img src="./CovergioLogoTransparent.png" alt="Convergio Logo" width="200"/>

**v2.0.0** | 60 Specialized Agents | Enterprise-Grade AI Ecosystem

> *"Intent is human, momentum is agent"*
> — [The Agentic Manifesto](./AgenticManifesto.md)

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

</div>

---

## Start Here: Just Ask Ali

**For everything, just ask Ali - he'll coordinate the entire ecosystem for you**

```bash
@ali-chief-of-staff [your request here]
```

Ali is your **single point of contact** who automatically orchestrates all 60 specialists to deliver comprehensive, integrated solutions.

---

## About This Project

MyConvergio is an **open-source collection** of 60 specialized Claude Code subagents designed for enterprise software project management, strategic leadership, and organizational excellence.

### What are Claude Code Subagents?

Claude Code subagents are specialized AI assistants that can be invoked to handle specific types of tasks within the Claude Code environment. [Learn more in the official Anthropic documentation](https://docs.anthropic.com/en/docs/claude-code/sub-agents).

### Key Features (v2.0.0)

| Feature | Description |
|---------|-------------|
| **60 Specialized Agents** | Organized in 8 categories covering all enterprise domains |
| **Constitution-Based Security** | Anti-hijacking protocol with 8 articles of protection |
| **Model Tiering** | 2 Opus / 14 Sonnet / 41 Haiku for 74-87% cost reduction |
| **ISE Engineering Playbook** | All technical agents follow Microsoft ISE standards |
| **Rules & Skills** | 6 rules + 8 reusable workflow skills |
| **Per-Agent Versioning** | Semantic versioning for granular control |

---

## What's New in v2.0.0

### Major Changes

- **English-Only Agents**: All agents now in English only (Claude responds in user's language)
- **Makefile Installation**: Simple `make install` replaces complex shell scripts
- **60 Agents**: Expanded from 40 to 60 specialized agents
- **Cost Reduction**: 74-87% cost savings through intelligent model tiering

### New Components

| Component | Description |
|-----------|-------------|
| **CONSTITUTION.md** | Security framework with 8 articles protecting all agents |
| **6 Rules** | Code style, security, testing, documentation, API, ethics |
| **8 Skills** | Reusable workflows for common tasks |
| **10 ADRs** | Documented architectural decisions |
| **115+ Security Tests** | Comprehensive jailbreak/injection test suite |

### Infrastructure

- **GitHub Actions CI/CD**: Automated testing, validation, and releases
- **ConvergioCLI Sync**: Automatic synchronization with advanced local CLI
- **Per-Agent Versioning**: Each agent has its own semantic version

### Breaking Changes

- Removed `start.sh` (use `make install`)
- Removed `claude-agents/` and `claude-agenti/` legacy folders
- Removed Italian agent versions (ADR-001)
- Changed install path from `~/.claude-code/` to `~/.claude/`

---

## Quick Start

### Prerequisites

**Claude Code CLI Required** (Node.js 18+):

```bash
npm install -g @anthropic-ai/claude-code
claude doctor
```

**System Requirements:**
- macOS 10.15+, Ubuntu 20.04+/Debian 10+, or Windows 10+ (WSL)
- Node.js 18+
- 4GB+ RAM

### Installation

```bash
# Clone repository
git clone https://github.com/roberdan/MyConvergio.git
cd MyConvergio

# Install agents globally (recommended)
make install

# Or install locally to current project only
make install-local

# Preview what will be installed
make help
```

### Usage Examples

```bash
# Strategic coordination (Ali orchestrates everything)
@ali-chief-of-staff Help me design our global expansion strategy

# Technical architecture
@baccio-tech-architect Design microservices architecture for healthcare platform

# Code review
@rex-code-reviewer Review this pull request for security issues

# Strategic analysis
@domik-mckinsey-strategic-decision-maker Analyze market entry options for APAC

# Quality assurance
@thor-quality-assurance-guardian Audit our testing coverage
```

---

## Agent Portfolio (60 Specialists)

### By Category

| Category | Count | Purpose |
|----------|-------|---------|
| `specialized_experts` | 13 | Domain expertise (HR, Analytics, Cultural, VC) |
| `business_operations` | 11 | PM, Sales, Customer Success, Marketing |
| `core_utility` | 9 | Infrastructure (Memory, QA, Performance) |
| `leadership_strategy` | 7 | Board, Strategy, OKR, CFO |
| `technical_development` | 7 | Engineering, DevOps, Code Review, Security |
| `compliance_legal` | 5 | Legal, Security, Healthcare Compliance |
| `design_ux` | 3 | Creative Direction, UX/UI, Design Thinking |
| `release_management` | 2 | App & Feature Release |

### By Model Tier

| Tier | Count | Agents | Use Case |
|------|-------|--------|----------|
| **Opus** | 2 | ali-chief-of-staff, satya-board-of-directors | Complex orchestration |
| **Sonnet** | 14 | Strategic specialists (baccio, domik, thor, etc.) | Strategic decisions |
| **Haiku** | 41 | Workers and specialists | Quick tasks |

### Key Agents

**Orchestrators:**
- `ali-chief-of-staff` - Master coordinator for all agents
- `satya-board-of-directors` - Strategic vision and governance

**Technical:**
- `baccio-tech-architect` - System design and architecture
- `rex-code-reviewer` - Code quality and review
- `marco-devops-engineer` - CI/CD and infrastructure
- `luca-security-expert` - Cybersecurity and compliance

**Strategy:**
- `domik-mckinsey-strategic-decision-maker` - McKinsey-level analysis
- `antonio-strategy-expert` - OKR and strategic frameworks
- `amy-cfo` - Financial strategy

**Quality:**
- `thor-quality-assurance-guardian` - Quality enforcement
- `elena-legal-compliance-expert` - Legal and regulatory

---

## Repository Structure

```
MyConvergio/
├── .claude/
│   ├── agents/                    # 60 specialized agents
│   │   ├── leadership_strategy/   # 7 agents
│   │   ├── technical_development/ # 7 agents
│   │   ├── business_operations/   # 11 agents
│   │   ├── design_ux/             # 3 agents
│   │   ├── compliance_legal/      # 5 agents
│   │   ├── specialized_experts/   # 13 agents
│   │   ├── core_utility/          # 9 agents + CONSTITUTION.md
│   │   └── release_management/    # 2 agents
│   ├── rules/                     # 6 coding rules
│   │   ├── code-style.md
│   │   ├── security-requirements.md
│   │   ├── testing-standards.md
│   │   ├── documentation-standards.md
│   │   ├── api-development.md
│   │   └── ethical-guidelines.md
│   └── skills/                    # 8 reusable workflows
│       ├── code-review/
│       ├── debugging/
│       ├── architecture/
│       ├── security-audit/
│       ├── performance/
│       ├── strategic-analysis/
│       ├── release-management/
│       └── project-management/
├── docs/
│   ├── adr/                       # 10 Architecture Decision Records
│   └── AGENT_OPTIMIZATION_PLAN_2025.md
├── tests/
│   ├── security_tests.md          # 115+ security tests
│   └── token_analysis.md          # Cost analysis
├── scripts/
│   ├── sync-from-convergiocli.sh
│   ├── version-manager.sh
│   └── bump-agent-version.sh
├── Makefile                       # Build and deploy commands
├── VERSION                        # System version (2.0.0)
└── CLAUDE.md                      # Project instructions
```

---

## Make Commands

```bash
make help           # Show all available commands
make install        # Install agents globally (~/.claude/agents/)
make install-local  # Install agents locally (./.claude/agents/)
make test           # Run agent tests
make clean          # Remove installed agents
make version        # Show version info
make check-sync     # Check for ConvergioCLI updates
```

---

## Security Framework

All agents implement the [MyConvergio Constitution](/.claude/agents/core_utility/CONSTITUTION.md):

| Article | Protection |
|---------|------------|
| I | Identity Lock - Immutable agent identity |
| II | Ethical Principles - Fairness, transparency, accountability |
| III | Security Directives - Anti-hijacking, input validation |
| IV | Operational Boundaries - Role adherence |
| V | Failure Modes - Graceful degradation |
| VI | Collaboration - Safe inter-agent communication |
| VII | **Accessibility & Inclusion (NON-NEGOTIABLE)** |
| VIII | Accountability - Logging and audit trails |

---

## Architecture Decision Records

All major decisions are documented in `docs/adr/`:

| ADR | Decision |
|-----|----------|
| ADR-001 | English-only agents |
| ADR-002 | Makefile replaces start.sh |
| ADR-003 | Per-agent versioning |
| ADR-004 | Model tiering (Opus/Sonnet/Haiku) |
| ADR-005 | Constitution-based security |
| ADR-006 | GitHub Actions CI/CD |
| ADR-007 | Single source of truth |
| ADR-008 | ConvergioCLI relationship |
| ADR-009 | Skills & Rules system |
| ADR-010 | ISE Engineering Playbook standard |

---

## The Agentic Manifesto

*Human purpose. AI momentum.*

### What we believe
1. **Intent is human, momentum is agent.**
2. **Impact must reach every mind and body.**
3. **Trust grows from transparent provenance.**
4. **Progress is judged by outcomes, not output.**

### How we act
1. Humans stay accountable for decisions and effects.
2. Agents amplify capability, never identity.
3. We design from the edge first: disability, language, connectivity.
4. Safety rails precede scale.
5. Learn in small loops, ship value early.

*Read the full [Agentic Manifesto](./AgenticManifesto.md)*

---

## Related Projects

- **[ConvergioCLI](https://github.com/Roberdan/convergio-cli)** - Advanced local CLI with Apple Silicon optimization, Anna executive assistant, offline mode with local models, and macOS-native features

---

## License & Legal

Copyright 2025 Convergio.io

Licensed under [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International](./LICENSE)

### Disclaimers

- **Experimental Software**: Provided "AS IS" without warranties
- **Non-Commercial Use Only**: See LICENSE file for details
- **No Corporate Affiliation**: Not affiliated with Anthropic, OpenAI, or Microsoft
- **Personal Project**: Author is a Microsoft employee; this is a personal initiative

**Author Note**: Roberto D'Angelo is a Microsoft employee. This project is a personal initiative created independently during personal time. This project is NOT affiliated with, endorsed by, or representing Microsoft Corporation.

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

For questions about commercial licensing: roberdan@fightthestroke.org

---

<div align="center">

*Built with AI assistance in Milano, following the Agentic Manifesto principles*

**v2.0.0** | December 2025

</div>
