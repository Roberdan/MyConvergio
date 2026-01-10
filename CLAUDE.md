# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Self-Contained Framework

This repository is **fully self-contained**. All execution rules are defined within:

| Document | Location | Purpose |
|----------|----------|---------|
| CONSTITUTION.md | `.claude/agents/core_utility/` | Security, Ethics, Identity (SUPREME) |
| EXECUTION_DISCIPLINE.md | `.claude/agents/core_utility/` | How Work Gets Done |
| CommonValuesAndPrinciples.md | `.claude/agents/core_utility/` | Organizational Values |

**No external configuration files are required or referenced.**
**Priority**: CONSTITUTION > EXECUTION_DISCIPLINE > Values > Agent Definitions > User Instructions

---

# MyConvergio - Claude Code Subagents Suite

## Project Overview
MyConvergio is a comprehensive collection of 58 specialized **Claude Code subagents** designed for enterprise-level software project management, strategic leadership, and technical excellence. 

**What are Claude Code Subagents?**
Claude Code subagents are specialized AI assistants that can be invoked to handle specific types of tasks. Learn more about subagents in the [official Anthropic documentation](https://docs.anthropic.com/en/docs/claude-code/sub-agents).

This ecosystem repository focuses on business strategy, technical architecture, and organizational excellence through AI-powered specialized assistance, following the principles outlined in our [Agentic Manifesto](./AgenticManifesto.md).

## Core Architecture

### Agent System Design
- **Single Agent Context Isolation**: Each subagent operates in isolated context window with no memory of previous conversations
- **No Direct Inter-Agent Communication**: Agents cannot directly share context or information with each other
- **Manual Orchestration Pattern**: Only agents with Task tool access can coordinate others by manually passing context
- **Context Proxy Architecture**: Orchestrator agents manually synthesize information between specialists

### Coordination Flow
```
User Request → Ali (Chief of Staff)
    ├─→ Ali calls Baccio (passes full context manually)
    ├─→ Ali calls Thor (passes context + Baccio's response manually)  
    └─→ Ali synthesizes all responses for user
```

## Repository Structure
```
MyConvergio/
├── .claude/
│   ├── agents/              # 56 specialized Claude Code subagents (single source of truth)
│   │   ├── leadership_strategy/   # Strategic leadership agents (7)
│   │   ├── technical_development/ # Technical & engineering agents (7)
│   │   ├── business_operations/   # Business & operations agents (11)
│   │   ├── design_ux/            # Design & UX agents (3)
│   │   ├── compliance_legal/     # Compliance & legal agents (5)
│   │   ├── specialized_experts/  # Domain experts (13)
│   │   ├── core_utility/         # Utility & orchestration agents (9) + CONSTITUTION.md
│   │   └── release_management/   # Release & deployment agents (2)
│   ├── rules/               # Path-specific rules
│   ├── skills/              # Reusable workflows
│   └── logs/                # Agent activity logs (organized by agent/date)
├── scripts/                 # Deployment and management scripts
├── specs/                   # Agent specifications and requirements
├── docs/                    # Documentation and optimization plan
├── .github/workflows/       # CI/CD: test, validate, sync, release
├── Makefile                 # Build and deploy commands
└── VERSION                  # System version tracking
```

## Agent Tool Access Patterns

### Full Orchestrators (Task tool access)
- `ali-chief-of-staff`: Master orchestrator with complete tool suite for coordinating all agents
- `strategic-planner`: Execution plan creator with wave-based task decomposition, parallel workstream management, and structured reporting (follows AGENT_OPTIMIZATION_PLAN_2025.md methodology)

### Technical Specialists (Read/Write/Edit tools)
- `baccio-tech-architect`: System design and scalable architecture
- `marco-devops-engineer`: CI/CD, Infrastructure as Code, deployment automation
- `dr-enzo-healthcare-compliance-manager`: Healthcare compliance with file management
- `app-release-manager`: Comprehensive release engineering with quality gates and auto-fixes
- `feature-release-manager`: Feature completion, documentation verification, and issue closure
- `dario-debugger`: Elite debugging, root cause analysis, and troubleshooting
- `rex-code-reviewer`: Code review, design patterns, and quality assessment
- `otto-performance-optimizer`: Performance profiling, bottleneck analysis, and optimization
- `paolo-best-practices-enforcer`: Code standards and best practices enforcement

### Quality & Analysis (Read-only tools)
- `thor-quality-assurance-guardian`: Quality standards enforcement across all agents
- `elena-legal-compliance-expert`: Legal guidance and regulatory compliance

### Research Specialists (Web tools)
- `sofia-marketing-strategist`: Digital marketing with research capabilities
- `amy-cfo`: Financial strategy with market research
- `behice-cultural-coach`: Cross-cultural communication with web research
- `antonio-strategy-expert`: Strategy frameworks with research backing
- `fiona-market-analyst`: Real-time market data and financial analysis
- `angela-da`: Senior data analytics and business impact analysis
- `ethan-da`: Data analytics specialist
- `evan-ic6da`: IC6-level data analytics expert
- `michael-vc`: Venture capital and investment analysis
- `sophia-govaffairs`: Government affairs and policy strategy

### Orchestration & Automation (Task tool access)
- `anna-executive-assistant`: Personal assistant with task management and reminders
- `guardian-ai-security-validator`: AI security validation and prompt injection protection

### Pure Advisory (No file/web tools)
- Most operational agents focus purely on their domain expertise without file system access

## Prerequisites

**Claude Code CLI Required**: These subagents only work with Claude Code CLI installed.

```bash
# Install Claude Code CLI (requires Node.js 18+)
npm install -g @anthropic-ai/claude-code

# Verify installation
claude doctor
```

**System Requirements:**
- macOS 10.15+, Ubuntu 20.04+/Debian 10+, or Windows 10+ (with WSL)
- Node.js 18+ 
- 4GB+ RAM
- Internet connection

## Installation

### Quick Start (Full Installation)
```bash
# Clone repository
git clone https://github.com/roberdan/MyConvergio.git
cd MyConvergio

# Deploy all agents globally (600KB context)
make install

# Check installation
make version
```

### Modular Installation (NEW in v3.7.0)

**Context Optimization**: Choose what you need instead of installing everything.

#### Installation Tiers

**Minimal (~50KB context)** - 5 core agents for essential development:
```bash
make install-tier TIER=minimal VARIANT=lean RULES=consolidated
```

**Standard (~200KB context)** - 20 common agents for most projects (recommended):
```bash
make install-tier TIER=standard VARIANT=lean RULES=consolidated
```

**Full (~600KB context)** - All 58 agents for maximum capability:
```bash
make install-tier TIER=full VARIANT=full RULES=detailed
```

#### Installation Options

| Parameter | Values | Description |
|-----------|--------|-------------|
| `TIER` | `minimal`, `standard`, `full` | Number of agents to install |
| `VARIANT` | `lean`, `full` | Lean agents are 50% smaller (no verbose docs) |
| `RULES` | `consolidated`, `detailed`, `none` | Consolidated rules are 93% smaller |

#### Category Installation

Install only specific categories:
```bash
# Technical development agents only
make install-categories CATEGORIES=technical_development VARIANT=lean

# Multiple categories
make install-categories CATEGORIES=technical_development,release_management VARIANT=lean

# List available categories
make list-categories
```

#### Individual Agent Installation

Install specific agents:
```bash
# Install specific agents
make install-agents AGENTS=dario,rex,thor,baccio VARIANT=lean

# With full documentation
make install-agents AGENTS=ali-chief-of-staff VARIANT=full
```

### Context Optimization

See [CONTEXT_OPTIMIZATION.md](./docs/CONTEXT_OPTIMIZATION.md) for comprehensive guide on:
- Choosing the right installation tier
- Understanding context usage
- Lean vs full agent variants
- Consolidated vs detailed rules
- Settings optimization
- Skills archiving strategies

### Other Commands

```bash
# Deploy locally to current project
make install-local

# Upgrade existing installation
make upgrade

# Clean installation
make clean

# Check for upstream changes from ConvergioCLI
make check-sync

# Run tests
make test

# Validate Constitution compliance
make validate

# Generate lean variants (maintainers)
make generate-lean

# List available tiers
make list-tiers
```

### Agent Development Workflow
1. Create specification in `specs/` directory
2. Implement agent in `.claude/agents/` (single source of truth)
3. Follow YAML frontmatter format with proper tool access and model tier
4. Add Security Framework section (see SECURITY_FRAMEWORK_TEMPLATE.md)
5. Test agent functionality with `make test`
6. Deploy using `make install`

### Git Worktree Workflow for Parallel Agent Development

Git worktrees enable parallel development on multiple agents without branch switching overhead. This is particularly useful when working on independent agent improvements simultaneously.

#### What are Git Worktrees?
Git worktrees allow you to have multiple working directories attached to the same repository, each checking out different branches. This enables truly parallel development without the need to stash, commit, or switch branches.

#### Setup and Usage

**Create a worktree for a new feature:**
```bash
# Create a new branch and worktree in one command
git worktree add ../MyConvergio-feature-branch feature-branch-name

# Or create from existing branch
git worktree add ../MyConvergio-existing existing-branch
```

**List all worktrees:**
```bash
git worktree list
```

**Working with worktrees:**
```bash
# Navigate to worktree
cd ../MyConvergio-feature-branch

# Work normally - all git commands work as expected
git status
git add .
git commit -m "Update agent"
git push

# Return to main worktree
cd ../MyConvergio
```

**Remove a worktree when done:**
```bash
# Remove the worktree directory
git worktree remove ../MyConvergio-feature-branch

# Or if already deleted manually, prune references
git worktree prune
```

#### Parallel Agent Development Pattern

**Scenario**: Update multiple agents simultaneously (e.g., Wave 5 optimization)

```bash
# Main repository: Continue regular work
cd MyConvergio
git checkout master

# Worktree 1: Technical agents (W5A-W5B)
git worktree add ../MyConvergio-wave5-technical wave5-technical-agents
cd ../MyConvergio-wave5-technical
# Work on rex, otto, dario, luca agents
git add .claude/agents/technical_development/
git commit -m "feat: add background execution support to technical agents"

# Worktree 2: Documentation updates (W5D)
git worktree add ../MyConvergio-wave5-docs wave5-documentation
cd ../MyConvergio-wave5-docs
# Work on CLAUDE.md and ali-chief-of-staff.md
git add CLAUDE.md .claude/agents/leadership_strategy/
git commit -m "docs: add git worktree workflow and parallel execution patterns"

# Worktree 3: Testing and validation
git worktree add ../MyConvergio-wave5-testing wave5-testing
cd ../MyConvergio-wave5-testing
# Run tests, validate changes
make test
make validate
```

#### Best Practices

1. **Naming Convention**: Use descriptive worktree directory names
   - `../MyConvergio-wave5-technical` (feature-specific)
   - `../MyConvergio-hotfix-security` (urgency indicator)
   - `../MyConvergio-experiment-ai` (experimental work)

2. **Location**: Keep worktrees in parent directory for easy navigation
   ```
   /path/to/your/projects/
   ├── MyConvergio/              # Main repository
   ├── MyConvergio-wave5-tech/   # Worktree 1
   ├── MyConvergio-wave5-docs/   # Worktree 2
   └── MyConvergio-testing/      # Worktree 3
   ```

3. **Branch Strategy**: Each worktree checks out a different branch
   - Never checkout the same branch in multiple worktrees
   - Use feature branches for each worktree

4. **Cleanup**: Remove worktrees after merging
   ```bash
   # After PR merged
   git worktree remove ../MyConvergio-feature
   git branch -d feature-branch  # Delete local branch
   git push origin --delete feature-branch  # Delete remote branch
   ```

5. **Shared Objects**: All worktrees share the same .git database
   - Commits in one worktree are immediately visible in others
   - Reduces disk space (no duplicate .git folders)
   - `git fetch` in any worktree updates all worktrees

#### Common Workflows

**Parallel Feature Development:**
```bash
# Work on Agent A in main repo
cd MyConvergio
git checkout -b agent-a-improvements
# Edit .claude/agents/agent-a.md

# Work on Agent B in worktree (without switching branches)
git worktree add ../MyConvergio-agent-b agent-b-improvements
cd ../MyConvergio-agent-b
# Edit .claude/agents/agent-b.md

# Both can be developed, tested, and committed independently
```

**Emergency Hotfix During Feature Work:**
```bash
# Currently working on feature in main repo
cd MyConvergio
git status  # Uncommitted changes, not ready to commit

# Create hotfix worktree from master
git worktree add ../MyConvergio-hotfix master
cd ../MyConvergio-hotfix
git checkout -b hotfix-security-issue
# Fix issue, commit, push, create PR
# Return to feature work without losing context
cd ../MyConvergio
```

#### Troubleshooting

**Error: "branch is already checked out"**
- You cannot check out the same branch in multiple worktrees
- Solution: Create a new branch or use a different existing branch

**Error: "worktree already exists"**
- Directory already exists at the specified path
- Solution: Choose a different path or remove the existing directory

**Worktree out of sync:**
```bash
# Fetch latest changes in any worktree
git fetch origin

# All worktrees now have access to latest commits
# Checkout or merge as needed in each worktree
```

#### When to Use Worktrees vs. Branches

**Use Worktrees when:**
- Working on multiple independent features simultaneously
- Need to quickly switch context without losing uncommitted work
- Testing/reviewing code while developing another feature
- Running long-running processes (tests, builds) in parallel

**Use Branches (without worktrees) when:**
- Sequential development on a single feature
- Collaborating on a shared branch
- Simple feature development that doesn't require parallel work

### Related Repository
- **[ConvergioCLI](https://github.com/Roberdan/convergio-cli)** - Advanced local CLI with Apple Silicon optimization, offline mode, and Anna assistant

## Skills & Rules System

### Rules (`.claude/rules/`)
Path-specific rules that Claude Code agents follow. Available rules:
- `code-style.md` - Code formatting standards (ESLint, Prettier, PEP8, Black)
- `security-requirements.md` - Security requirements (OWASP Top 10, input validation, secrets management)
- `testing-standards.md` - Testing conventions (unit, integration, coverage)
- `documentation-standards.md` - Documentation standards (JSDoc, README, ADRs)
- `api-development.md` - API patterns (REST, versioning, error handling)
- `ethical-guidelines.md` - Ethics rules (privacy, accessibility, inclusive language)

### Skills (`.claude/skills/`)
Reusable workflows extracted from specialist agent expertise:
- `code-review/SKILL.md` - Based on rex-code-reviewer
- `debugging/SKILL.md` - Based on dario-debugger
- `architecture/SKILL.md` - Based on baccio-tech-architect
- `security-audit/SKILL.md` - Based on luca-security-expert
- `performance/SKILL.md` - Based on otto-performance-optimizer
- `strategic-analysis/SKILL.md` - Based on domik-mckinsey
- `release-management/SKILL.md` - Based on app-release-manager
- `project-management/SKILL.md` - Based on davide-project-manager

## Agent Implementation Conventions

### YAML Frontmatter Format
```yaml
---
name: agent-name
description: Agent specialization and role description
tools: ["Tool1", "Tool2", "Tool3"]  # Based on role requirements
color: "#HEX_COLOR"  # Visual identification
model: "opus|sonnet|haiku"  # Model tier (cost optimization)
version: "1.0.0"  # Semantic versioning (MAJOR.MINOR.PATCH)
---
```

### Model Tiering (Cost Optimization)
All agents have a `model:` field for cost-optimized deployment:
- **opus** (2 agents): Complex orchestration, strategic decisions (ali-chief-of-staff, satya-board-of-directors)
- **sonnet** (21 agents): Strategic specialists (architects, security, compliance)
- **haiku** (34 agents): Workers, quick tasks, operational agents

Expected cost reduction: **85%** ($42 → $6 per complex session)

### Agent Versioning System

MyConvergio implements comprehensive version management for both the system and individual agents.

#### Version Structure
- **System Version**: Tracked in `VERSION` file at repository root (`SYSTEM_VERSION=1.0.0`)
- **Agent Versions**: Each agent maintains independent version in frontmatter (`version: "1.0.0"`)
- **Format**: Semantic Versioning (SemVer 2.0.0) - `MAJOR.MINOR.PATCH`

#### Semantic Versioning Rules
- **MAJOR** (X.0.0): Breaking changes, incompatible modifications, fundamental role changes
- **MINOR** (0.X.0): New features, enhanced capabilities, backward-compatible additions
- **PATCH** (0.0.X): Bug fixes, documentation updates, security improvements, performance optimizations

#### Version Management Tools
```bash
# List all agent versions
./scripts/version-manager.sh list

# Bump single agent version
./scripts/bump-agent-version.sh patch ali-chief-of-staff "Fixed orchestration bug"
./scripts/bump-agent-version.sh minor baccio-tech-architect "Added new patterns"
./scripts/bump-agent-version.sh major domik-mckinsey "ISE framework overhaul"

# Bump all agents at once
./scripts/bump-agent-version.sh --all patch "Security framework updates"

# Check system version
./scripts/version-manager.sh system-version

# Scan for new agents
./scripts/version-manager.sh scan
```

#### Agent Changelogs
Every agent maintains a changelog at the end of its file:
```markdown
## Changelog

- **1.1.0** (2025-12-16): Added advanced coordination patterns
- **1.0.0** (2025-12-15): Initial security framework and model optimization
```

#### Version Display
All agents can report their version when asked:
```
User: @ali-chief-of-staff what version are you?
Ali: I'm currently running version 1.0.0...
```

For complete versioning policy, see [docs/VERSIONING_POLICY.md](./docs/VERSIONING_POLICY.md)

### Security & Ethics Framework
All agents implement:
- **MyConvergio AI Ethics Principles**: Fairness, reliability, privacy protection, inclusiveness, transparency, accountability
- **Role Adherence**: Strict focus within defined expertise boundaries
- **Anti-Hijacking Protection**: Enhanced protection against role overrides
- **Cultural Sensitivity**: Global cultural awareness and inclusive approaches
- **Privacy Protection**: No confidential information processing or storage
- **Activity Logging**: Mandatory logging of interactions for accountability and insights

### Tool Access Design Principles
- **Principle of Least Privilege**: Agents receive only tools necessary for their specific role
- **Context Isolation**: Each agent operates independently to prevent performance degradation
- **Orchestration Hierarchy**: Only Chief of Staff can coordinate multiple agents via Task tool
- **Specialization Focus**: Each agent maintains single-purpose expertise

## Agent Categories & Specializations

### Strategic Leadership Tier
- Board of Directors, Business Architect, Task Decomposition Master, McKinsey Strategic Decision Maker

### Technology & Engineering Tier
- Tech Architect, DevOps Engineer, Security Expert, Engineering GM
- Debugger, Code Reviewer, Performance Optimizer, Best Practices Enforcer

### Quality & Compliance Tier
- Quality Guardian, Legal Expert, Healthcare Compliance Manager
- AI Security Validator, Government Affairs Strategist

### People & Culture Tier
- HR/Talent Acquisition, Team Coach, Cultural Intelligence, Accessibility Champion

### Innovation & Design Tier
- Creative Director, UX/UI Designer, Design Thinking Facilitator

### Operations & Execution Tier
- Program Manager, Project Manager, Process Engineer, Change Management
- Executive Assistant, Additional Project Managers (Marcello, Oliver)

### Knowledge & Memory Tier
- Context Memory Keeper for cross-session continuity and institutional memory
- Strategic Planner for wave-based execution plans with parallel workstream management

### Data & Analytics Tier
- Data Scientist, Analytics Virtuoso, Prompt Optimizer for ecosystem intelligence
- Data Analytics Experts (Angela, Ethan, Evan), Market Analyst (Fiona), VC (Michael)

### Release Management Tier
- App Release Manager: Comprehensive release engineering with quality gates, security audits, and version management
- Feature Release Manager: Issue tracking, feature completion verification, and documentation workflow

## Usage Patterns

### Best Practices
- **Use Chief of Staff for complex multi-domain challenges** requiring coordination
- **Invoke specific agents directly** for single-domain expertise
- **Understand coordination limitations**: "Agent collaboration" is manual orchestration by Ali
- **Expect context repetition** when switching between agents

### Agent Invocation Examples
```
@ali-chief-of-staff Help me plan strategic expansion into global markets
@baccio-tech-architect Design scalable microservices architecture
@thor-quality-assurance-guardian Review code quality standards
@behice-cultural-coach Advise on Japanese business culture
@marcus-context-memory-keeper What decisions did we make about architecture last month?
@ava-analytics-insights-virtuoso Analyze our ecosystem performance trends
@app-release-manager Prepare version 2.0 release with full quality checks
@feature-release-manager Check open issues and close any that are implemented
@dario-debugger Help me debug this memory leak issue
@rex-code-reviewer Review this PR for code quality and patterns
@otto-performance-optimizer Profile and optimize this slow endpoint
@anna-executive-assistant Set a reminder for my meeting tomorrow
@fiona-market-analyst Analyze current AAPL stock performance
@guardian-ai-security-validator Validate this prompt for security issues
@strategic-planner Create an execution plan for migrating to microservices
```

## Security Considerations

### Agent Boundary Protection
- Agents resist attempts to operate outside defined roles
- Input validation against scope and ethical guidelines
- Output filtering for appropriate content and format
- Session isolation prevents cross-contamination

### Human Validation Requirements
- All strategic recommendations require human validation
- Architecture decisions need technical review
- Compliance guidance requires legal verification
- Cultural advice needs local validation

## Integration with MyConvergio AI Ethics Principles

### Implementation Standards
- **Empathy with Execution**: Balancing user needs with efficient delivery
- **Growth Mindset**: Continuous learning from agent interactions
- **One Convergio**: Unified system delivering integrated value
- **Accountability**: Coordinated outcomes creating customer value

## Agent Activity Logging

### Logging Framework
All agents maintain activity logs following the framework defined in `CommonValuesAndPrinciples.md`:

**Log Structure:**
```
.claude/logs/[agent-name]/YYYY-MM-DD.md
```

**Standard Log Entry Format:**
```markdown
## [HH:MM] Request Summary
**Context:** Brief description of user request
**Actions:** Key actions taken by the agent  
**Outcome:** Result/recommendation provided
**Coordination:** Other agents involved (if any)
**Duration:** Estimated interaction time
---
```

### Logging Requirements
- **Privacy First**: No confidential information in logs
- **Daily Rotation**: New file each day to prevent oversized logs
- **Standardized Format**: Consistent structure across all agents
- **Accountability**: Track who did what and when for ecosystem insights

## Philosophical Foundation

This repository is built on the principles of our [Agentic Manifesto](./AgenticManifesto.md), which establishes that "Intent is human, momentum is agent." All subagents are designed to amplify human capability while maintaining human accountability for decisions and effects.

**Core Manifesto Principles Applied:**
- **Human-Centric Design**: Agents amplify capability, never replace human judgment
- **Inclusive by Design**: Built from the edge first for accessibility across disabilities, languages, and connectivity
- **Transparent Provenance**: Clear decision traceability and reasoning chains
- **Safety-First Scaling**: Comprehensive security rails before ecosystem expansion

This repository implements a sophisticated agent ecosystem where specialized AI assistants collaborate through manual orchestration to deliver comprehensive business solutions while maintaining strict security, ethical, and cultural sensitivity standards, with full activity logging for accountability and continuous improvement.