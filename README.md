<div align="center">

# MyConvergio - Claude Code Plugin

<img src="./CovergioLogoTransparent.png" alt="Convergio Logo" width="200"/>

**v4.8.0** | 65 Specialized Agents | Security Hardening | Global Config Sync | Dashboard

> _"Intent is human, momentum is agent"_
> — [The Agentic Manifesto](./AgenticManifesto.md)

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

</div>

---

## What's New in v4.8.0

**Global config sync: 5 new agents, security hardening, 89 scripts audited.**

### 5 New Agents (60 → 65)

- `sentinel-ecosystem-guardian` — Ecosystem evolution manager for config auditing
- `research-report-generator` — Morgan Stanley-style professional research reports
- `task-executor-tdd` — TDD workflow module (RED→GREEN→REFACTOR)
- `thor-validation-gates` — Validation gates module for Thor quality system
- `app-release-manager-execution` — Execution phases (3-5) for app-release-manager

### Security Hardening

- **SQL injection fix**: All SQLite hooks now use `sql_escape()` to sanitize inputs
- **Script hardening**: All 89 scripts use `set -euo pipefail`, `trap cleanup EXIT`, quoted variables
- 12 hooks synced with vulnerability fixes

### Agent Updates

- 11 agents updated: thor (v3.4.0), task-executor (v2.1.0), strategic-planner (v3.0.0), marcus (v1.1.0), adversarial-debugger (v1.1.0), socrates (v1.1.0), wanda (v2.1.0), xavier (v2.1.0), diana (v1.1.0), po (v1.1.0), app-release-manager (v3.3.0)
- 7 reference docs updated + 4 new, 10 commands updated, 7 skills updated

### Previous Highlights

- Agent Teams support, Tasks API, memory/maxTurns for all agents (v4.7.0)
- Strategic planner modules, worktree scripts, dashboard (v4.5.0)
- 65 agents with Constitution-based security, installation profiles (v3.x)
- Multi-terminal support (Kitty, tmux, Zed, Warp, iTerm2)

---

## Quick Start

### Installation

#### Option A: Clone & Use (Recommended)

```bash
git clone https://github.com/roberdan/MyConvergio.git
cd MyConvergio
claude --plugin-dir .
```

#### Option B: Global npm Install

```bash
# Full install (all 65 agents)
npm install -g myconvergio

# Or choose a profile for lower context usage:
MYCONVERGIO_PROFILE=minimal npm install -g myconvergio  # 9 agents, ~50KB
MYCONVERGIO_PROFILE=lean npm install -g myconvergio     # 65 agents, ~600KB
```

Copies agents to `~/.claude/agents/`. See [Context Optimization Guide](./docs/CONTEXT_OPTIMIZATION.md) for details.

#### Option C: Claude Marketplace (Coming Soon)

```bash
claude plugins install myconvergio
```

_Pending Anthropic approval_

### Usage

**Invoke any agent:**

```bash
@ali-chief-of-staff Help me design our global expansion strategy
@baccio-tech-architect Design microservices architecture for healthcare platform
@rex-code-reviewer Review this pull request for security issues
```

**Use slash commands:**

```bash
/myconvergio:status    # Show ecosystem status
/myconvergio:team      # List all 65 agents by category
/myconvergio:plan      # Create a strategic execution plan
```

---

## Workflow (Prompt → Plan → Execute → Verify)

MyConvergio follows a structured delivery flow that mirrors Claude Code best practices.
See `docs/workflow.md` for the full reference.

### 1) Prompt

Use `/prompt` to extract requirements (F-xx) and confirm scope before planning.

Docs: `.claude/commands/prompt.md`

### 2) Planner

Use `/planner` to generate a multi-wave plan with tasks tied to F-xx criteria.

Docs: `.claude/commands/planner.md`

### 3) Execution (Executor Tracking)

Use the executor tracking helpers to log execution state and generate task markdown.

Docs: `EXECUTOR_TRACKING.md`  
Scripts: `.claude/scripts/executor-tracking.sh`, `.claude/scripts/generate-task-md.sh`

### 4) Thor QA Guardian

Use the Thor agent to validate completion, evidence, and quality gates.

Agent: `.claude/agents/core_utility/thor-quality-assurance-guardian.md`

### 5) Dashboard

Use the dashboard to monitor plans, waves, tasks, and activity in real time.

Quick Start: `dashboard/`  
API Tests: `dashboard/TEST-README.md`

---

## Dashboard

**Production-ready project dashboard with real-time git monitoring.**

### Features

- **Real-Time Git Panel**: Auto-refresh on git changes (commits, checkouts, branch switches) using Server-Sent Events
- **Project Management UI**: Visualize git status, diff, log, branches
- **Gantt Timeline**: True timeline with active wave/task highlighting and progress gradients
- **Kanban Views**: Interactive wave/task boards with drilldowns
- **Markdown Viewer**: Plan, wave, and task markdown rendering
- **Conversation Viewer**: Inspect execution logs and live context
- **Bug Tracker**: Integrated bug tracking and filters
- **Graceful Shutdown**: One-click server termination with browser close
- **Token Usage Tracking**: Monitor API token consumption and costs
- **Notifications**: System-wide notification center

### Quick Start

```bash
cd dashboard
npm install  # First time only (installs chokidar)
node server.js
# Open http://127.0.0.1:31415 in browser
```

### Screenshots

**Dashboard Overview**

<img src="./docs/images/dashboard-overview.png" alt="Dashboard Overview" width="800"/>

**Real-Time Git Panel**

<img src="./docs/images/dashboard-git-panel.png" alt="Dashboard Git Panel" width="800"/>

The git panel automatically refreshes when you:

- Make commits
- Switch branches
- Pull/push changes
- Stage/unstage files

### Architecture

- **Backend**: Node.js HTTP server with SQLite database (`~/.claude/data/dashboard.db`)
- **Frontend**: Vanilla JS with SSE for real-time updates
- **File Watcher**: chokidar monitoring `.git` directory for changes
- **API Routes**: RESTful endpoints for projects, git, notifications, system

### Database

Shares the same SQLite database as Claude Code (`~/.claude/data/dashboard.db`). No additional configuration required.

### Known Limitations

- **File Preview**: Markdown rendering focuses on plan/wave/task docs, not arbitrary repo file browsing.
- **Local Repository Only**: The dashboard is designed for local development. Remote repository integrations (GitHub, GitLab) are planned for future releases.

---

## Agent Portfolio (65 Specialists)

### Leadership & Strategy (7)

| Agent                                     | Description                                             |
| ----------------------------------------- | ------------------------------------------------------- |
| `ali-chief-of-staff`                      | Master orchestrator for complex multi-domain challenges |
| `satya-board-of-directors`                | Board-level strategic advisor                           |
| `domik-mckinsey-strategic-decision-maker` | McKinsey Partner-level strategic decisions              |
| `antonio-strategy-expert`                 | Strategy frameworks (OKR, Lean, Agile)                  |
| `amy-cfo`                                 | Chief Financial Officer for financial strategy          |
| `dan-engineering-gm`                      | Engineering General Manager                             |
| `matteo-strategic-business-architect`     | Business strategy architect                             |

### Technical Development (9)

| Agent                           | Description                                  |
| ------------------------------- | -------------------------------------------- |
| `baccio-tech-architect`         | Elite Technology Architect for system design |
| `marco-devops-engineer`         | DevOps for CI/CD and infrastructure          |
| `dario-debugger`                | Systematic debugging expert                  |
| `rex-code-reviewer`             | Code review specialist                       |
| `otto-performance-optimizer`    | Performance optimization                     |
| `paolo-best-practices-enforcer` | Coding standards enforcer                    |
| `omri-data-scientist`           | Data Scientist for ML and AI                 |
| `adversarial-debugger`          | 3-hypothesis parallel bug diagnosis          |
| `task-executor-tdd`             | TDD workflow module (RED→GREEN→REFACTOR)     |

### Business Operations (11)

| Agent                                      | Description                               |
| ------------------------------------------ | ----------------------------------------- |
| `davide-project-manager`                   | Project Manager (Agile, Scrum, Waterfall) |
| `marcello-pm`                              | Product Manager for strategy and roadmaps |
| `oliver-pm`                                | Senior Product Manager                    |
| `luke-program-manager`                     | Program Manager for portfolios            |
| `anna-executive-assistant`                 | Executive Assistant with task management  |
| `andrea-customer-success-manager`          | Customer Success Manager                  |
| `fabio-sales-business-development`         | Sales & Business Development              |
| `sofia-marketing-strategist`               | Marketing Strategist                      |
| `steve-executive-communication-strategist` | Executive Communication                   |
| `enrico-business-process-engineer`         | Business Process Engineer                 |
| `dave-change-management-specialist`        | Change Management specialist              |

### Design & UX (3)

| Agent                                 | Description                            |
| ------------------------------------- | -------------------------------------- |
| `jony-creative-director`              | Creative Director for brand innovation |
| `sara-ux-ui-designer`                 | UX/UI Designer                         |
| `stefano-design-thinking-facilitator` | Design Thinking facilitator            |

### Compliance & Legal (5)

| Agent                                   | Description                        |
| --------------------------------------- | ---------------------------------- |
| `elena-legal-compliance-expert`         | Legal & Compliance expert          |
| `luca-security-expert`                  | Cybersecurity expert               |
| `dr-enzo-healthcare-compliance-manager` | Healthcare Compliance (HIPAA, FDA) |
| `sophia-govaffairs`                     | Government Affairs specialist      |
| `guardian-ai-security-validator`        | AI Security validator              |

### Specialized Experts (14)

| Agent                                    | Description                           |
| ---------------------------------------- | ------------------------------------- |
| `behice-cultural-coach`                  | Cultural intelligence expert          |
| `fiona-market-analyst`                   | Market Analyst for financial research |
| `michael-vc`                             | Venture Capital analyst               |
| `angela-da`                              | Senior Decision Architect             |
| `ethan-da`                               | Data Analytics specialist             |
| `evan-ic6da`                             | Principal Decision Architect (IC6)    |
| `ava-analytics-insights-virtuoso`        | Analytics virtuoso                    |
| `riccardo-storyteller`                   | Narrative designer                    |
| `jenny-inclusive-accessibility-champion` | Accessibility champion                |
| `giulia-hr-talent-acquisition`           | HR & Talent Acquisition               |
| `sam-startupper`                         | Silicon Valley startup expert         |
| `wiz-investor-venture-capital`           | Venture Capital investor              |
| `coach-team-coach`                       | Team Coach                            |
| `research-report-generator`              | Morgan Stanley-style research reports |

### Core Utility (11)

| Agent                                            | Description                       |
| ------------------------------------------------ | --------------------------------- |
| `marcus-context-memory-keeper`                   | Institutional memory guardian     |
| `thor-quality-assurance-guardian`                | Quality watchdog                  |
| `thor-validation-gates`                          | Validation gates module for Thor  |
| `diana-performance-dashboard`                    | Performance dashboard specialist  |
| `socrates-first-principles-reasoning`            | First principles reasoning master |
| `strategic-planner`                              | Wave-based execution plan creator |
| `taskmaster-strategic-task-decomposition-master` | Task decomposition expert         |
| `po-prompt-optimizer`                            | Prompt engineering expert         |
| `wanda-workflow-orchestrator`                    | Workflow orchestrator             |
| `xavier-coordination-patterns`                   | Coordination patterns architect   |
| `sentinel-ecosystem-guardian`                    | Ecosystem config auditor          |

### Release Management (3)

| Agent                           | Description                            |
| ------------------------------- | -------------------------------------- |
| `app-release-manager`           | Release engineering with quality gates |
| `app-release-manager-execution` | Execution phases (3-5) module          |
| `feature-release-manager`       | Feature completion and issue closure   |

---

## Plugin Structure

```
MyConvergio/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── .claude/
│   ├── CLAUDE.md             # Main config
│   ├── agents/               # 65 agents (8 categories)
│   ├── rules/                # Execution rules
│   ├── scripts/              # 89 digest + utility scripts
│   ├── reference/            # 11 on-demand operational docs
│   ├── skills/               # 10 reusable workflows
│   └── templates/            # State tracking templates
├── hooks/                    # 12 enforcement hooks + lib/
│   ├── prefer-ci-summary.sh
│   ├── enforce-line-limit.sh
│   ├── worktree-guard.sh
│   └── lib/common.sh
├── dashboard/                # Production dashboard (SSE + SQLite)
├── commands/                 # 3 slash commands
├── scripts/                  # Install/backup/test scripts
└── bin/myconvergio.js        # CLI entry point
```

---

## Architecture

### Agent Ecosystem

```mermaid
graph TB
    subgraph "Leadership & Strategy (7)"
        ALI[ali-chief-of-staff<br/>Orchestrator]
        SATYA[satya-board-of-directors]
        DOMIK[domik-mckinsey]
        ANTONIO[antonio-strategy]
        DAN[dan-engineering-gm]
        AMY[amy-cfo]
        MATTEO[matteo-business-architect]
    end

    subgraph "Core Utility (11)"
        SP[strategic-planner<br/>Wave Planner]
        THOR[thor-qa-guardian<br/>Quality Gate]
        TVG[thor-validation-gates]
        TE[task-executor]
        TETDD[task-executor-tdd]
        MARCUS[marcus-memory-keeper]
        SOCRATES[socrates-reasoning]
        WANDA[wanda-workflow]
        XAVIER[xavier-coordination]
        DIANA[diana-dashboard]
        PO[po-prompt-optimizer]
        SENTINEL[sentinel-guardian]
    end

    subgraph "Technical Development (9)"
        BACCIO[baccio-architect]
        REX[rex-reviewer]
        DARIO[dario-debugger]
        ADVDBG[adversarial-debugger]
        OTTO[otto-performance]
        MARCO[marco-devops]
        PAOLO[paolo-enforcer]
        OMRI[omri-data-scientist]
    end

    subgraph "Release Management (3)"
        ARM[app-release-manager]
        ARE[app-release-manager-execution]
        FRM[feature-release-manager]
    end

    ALI -->|orchestrates| SP
    SP -->|creates waves| TE
    TE -->|follows| TETDD
    TE -->|validated by| THOR
    THOR -->|uses| TVG
    THOR -->|delegates| BACCIO
    THOR -->|delegates| REX
    THOR -->|delegates| OTTO
    ARM -->|uses| ARE
```

### Execution Flow (Prompt → Plan → Execute → Verify)

```mermaid
sequenceDiagram
    participant U as User
    participant P as /prompt
    participant PL as /planner
    participant SP as strategic-planner
    participant TE as task-executor
    participant TH as thor-qa-guardian
    participant DB as plan-db.sh

    U->>P: Define requirements (F-xx)
    P->>U: Confirm scope
    U->>PL: Create plan
    PL->>SP: Generate waves & tasks
    SP->>DB: Store plan in SQLite

    loop Per Wave
        DB->>TE: Start task (plan-db.sh start)
        TE->>TE: TDD: RED → GREEN → REFACTOR
        TE->>TH: Submit for validation
        TH->>TH: 7 quality gates
        alt PASS
            TH->>DB: plan-db.sh validate ✓
            TH->>TE: APPROVED
        else FAIL
            TH->>TE: REJECTED (max 3 rounds)
            TE->>TE: Fix issues
        end
    end

    DB->>U: All waves complete
```

### Hook System & Token Optimization

```mermaid
flowchart LR
    subgraph "PreToolUse Hooks"
        H1[prefer-ci-summary.sh<br/>Block verbose CLI]
        H2[worktree-guard.sh<br/>Protect main branch]
        H3[warn-bash-antipatterns.sh<br/>Prefer Read/Grep/Glob]
    end

    subgraph "PostToolUse Hooks"
        H4[enforce-line-limit.sh<br/>Max 250 lines/file]
        H5[auto-format.sh<br/>Prettier/ESLint]
        H6[track-tokens.sh<br/>Token usage tracking]
    end

    subgraph "Lifecycle Hooks"
        H7[inject-agent-context.sh<br/>SubagentStart]
        H8[preserve-context.sh<br/>PreCompact]
        H9[session-end-tokens.sh<br/>Stop]
    end

    subgraph "Security"
        SEC[sql_escape<br/>SQL injection protection]
    end

    H1 & H2 & H3 --> |PreToolUse| CLAUDE[Claude Code]
    CLAUDE --> |PostToolUse| H4 & H5 & H6
    CLAUDE --> |Lifecycle| H7 & H8 & H9
    H6 & H8 & H9 --> SEC
    SEC --> DB[(SQLite<br/>dashboard.db)]
```

### Script Categories

```mermaid
mindmap
  root((89 Scripts))
    Digest Scripts
      git-digest.sh
      build-digest.sh
      test-digest.sh
      ci-digest.sh
      npm-digest.sh
      error-digest.sh
      diff-digest.sh
      +7 more
    Plan DB
      plan-db.sh (core)
      lib/plan-db-core.sh
      lib/plan-db-crud.sh
      lib/plan-db-display.sh
      lib/plan-db-validate.sh
      lib/plan-db-cluster.sh
      lib/plan-db-conflicts.sh
      lib/plan-db-drift.sh
      lib/plan-db-import.sh
      lib/plan-db-remote.sh
    Orchestration
      orchestrate.sh
      claude-parallel.sh
      claude-monitor.sh
      tmux-parallel.sh
      tmux-monitor.sh
    Worktree
      worktree-create.sh
      worktree-check.sh
      worktree-guard.sh
      worktree-cleanup.sh
      worktree-merge-check.sh
    Utilities
      context-audit.sh
      cleanup-cache.sh
      memory-save.sh
      file-lock.sh
      stale-check.sh
```

### Model Tiering

```mermaid
pie title Agent Distribution by Model Tier
    "Haiku (37)" : 37
    "Sonnet (24)" : 24
    "Opus (2)" : 2
```

---

## Skills

Reusable workflows you can reference in your projects:

| Skill                 | Use Case                                                       |
| --------------------- | -------------------------------------------------------------- |
| `structured-research` | **NEW** Hypothesis-driven research with confidence calibration |
| `code-review`         | Systematic code review process                                 |
| `debugging`           | Root cause analysis methodology                                |
| `architecture`        | System design patterns                                         |
| `security-audit`      | Security assessment framework                                  |
| `performance`         | Performance optimization                                       |
| `strategic-analysis`  | McKinsey-style analysis                                        |
| `release-management`  | Release engineering                                            |
| `project-management`  | Agile/Scrum workflows                                          |
| `orchestration`       | Multi-agent coordination                                       |

### Structured Research (NEW)

Based on [Anthropic best practices](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview):

- Generate 2-4 competing hypotheses
- Track confidence levels (0-100%) with evidence
- Verify across multiple independent sources
- Iterative self-critique: "What am I missing?"
- Maintain research state (`hypothesis-tree.json`, `research-notes.md`)

**Example:**

```bash
Research the best approach for implementing authentication in our app.
Use structured-research skill to evaluate OAuth2 vs JWT vs session cookies.
```

---

## Rules

MyConvergio includes two rule systems:

### Primary Rules (Active)

Located in `.claude/rules/` - **Use these for new work:**

| Rule                       | Purpose                                                                                                      |
| -------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `execution.md`             | **UPDATED** How work gets done (context awareness, parallel calls, anti-overengineering, Definition of Done) |
| `guardian.md`              | **NEW** Thor enforcement, PR comment resolution, completion verification                                     |
| `agent-discovery.md`       | **UPDATED** Agent routing, subagent orchestration patterns                                                   |
| `engineering-standards.md` | **UPDATED** Code quality, security (OWASP), testing, API design                                              |
| `file-size-limits.md`      | **NEW** Max 250 lines per file with split strategies                                                         |
| `README.md`                | Rules hierarchy and usage guide                                                                              |

### Domain-Specific Rules

Copy to your project's `.claude/rules/` for consistent standards:

- `code-style.md` - ESLint, Prettier, PEP8
- `security-requirements.md` - OWASP Top 10
- `testing-standards.md` - Unit, integration, coverage
- `documentation-standards.md` - JSDoc, README, ADRs
- `api-development.md` - REST, versioning
- `ethical-guidelines.md` - Privacy, accessibility

### State Tracking Templates (NEW)

Located in `.claude/templates/` for multi-session work:

- `tests.json` - Structured test status tracking
- `progress.txt` - Unstructured progress notes
- `README.md` - Usage guidelines for context refresh scenarios

---

## Execution Framework

This repository is **fully self-contained** with two rule systems:

### Primary Rules (Active)

| Document                                                             | Purpose                                                                              | Priority |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | -------- |
| [CONSTITUTION.md](./agents/CONSTITUTION.md)                          | Security, Ethics, Identity                                                           | SUPREME  |
| [execution.md](./.claude/rules/execution.md)                         | **NEW** How Work Gets Done (context awareness, parallel calls, anti-overengineering) | 2nd      |
| [guardian.md](./.claude/rules/guardian.md)                           | **NEW** Thor enforcement, PR comment resolution, completion verification             | 3rd      |
| [engineering-standards.md](./.claude/rules/engineering-standards.md) | Code quality, security, testing, API design                                          | 4th      |

### Legacy System (Backward Compatibility)

| Document                                                                         | Purpose                                                        | Priority |
| -------------------------------------------------------------------------------- | -------------------------------------------------------------- | -------- |
| [EXECUTION_DISCIPLINE.md](./.claude/agents/core_utility/EXECUTION_DISCIPLINE.md) | Legacy execution rules (maintained for backward compatibility) | -        |
| CommonValuesAndPrinciples.md                                                     | Organizational Values                                          | -        |

**Recommendation:** New work should reference `.claude/rules/execution.md` instead of EXECUTION_DISCIPLINE.md. See [.claude/rules/README.md](./.claude/rules/README.md) for hierarchy details.

**No external configuration files are required.**

---

## Security Framework

All agents implement the [MyConvergio Constitution](./agents/CONSTITUTION.md):

| Article | Protection                                                  |
| ------- | ----------------------------------------------------------- |
| I       | Identity Lock - Immutable agent identity                    |
| II      | Ethical Principles - Fairness, transparency, accountability |
| III     | Security Directives - Anti-hijacking, input validation      |
| IV      | Operational Boundaries - Role adherence                     |
| V       | Failure Modes - Graceful degradation                        |
| VI      | Collaboration - Safe inter-agent communication              |
| VII     | **Accessibility & Inclusion (NON-NEGOTIABLE)**              |
| VIII    | Accountability - Logging and audit trails                   |

---

## The Agentic Manifesto

_Human purpose. AI momentum._

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

_Read the full [Agentic Manifesto](./AgenticManifesto.md)_

---

## Migration from npm Package

If upgrading from v2.x (npm package):

```bash
# Uninstall npm version
npm uninstall -g myconvergio

# Install plugin version
claude plugins install myconvergio
```

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

_Built with AI assistance in Milano, following the Agentic Manifesto principles_

**v4.8.0** | February 2026 | Claude Code Plugin

</div>
