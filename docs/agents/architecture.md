# Architecture & Diagrams

This document contains the detailed architecture diagrams and technical deep-dives for MyConvergio.

## How It Works - High-Level Flow

```mermaid
graph TB
    subgraph USER["You"]
        REQ[Requirements]
    end

    subgraph PIPELINE["Structured Delivery Pipeline"]
        direction LR
        P["Prompt<br/>Extract F-xx"]
        PL["Plan<br/>Waves & Tasks"]
        EX["Execute<br/>TDD Cycle"]
        TH["Thor<br/>Quality Gate"]
    end

    subgraph ORCHESTRATOR["Convergio Orchestrator (delegate.sh)"]
        direction TB
        ROUTE{"Route by<br/>Priority / Privacy<br/>Cost / Task Type"}
        subgraph PROVIDERS["4 Providers"]
            direction LR
            CL["Claude<br/><i>Premium, review/critical</i>"]
            CO["Copilot CLI<br/><i>Subscription, coding/PR-ops</i>"]
            OC["OpenCode<br/><i>Local/Ollama, sensitive data</i>"]
            GE["Gemini<br/><i>Premium, research</i>"]
        end
        ROUTE --> CL & CO & OC & GE
    end

    subgraph AGENTS["65 Specialized Agents"]
        direction TB
        L["7 Leadership"]
        T["9 Technical"]
        C["11 Core Utility"]
        B["11 Business"]
        O["27 More"]
    end

    subgraph INFRA["Infrastructure"]
        DB["SQLite DB<br/><i>Plans, tasks, tokens</i>"]
        HOOKS["12 Hooks<br/><i>Pre/Post guards</i>"]
        SCRIPTS["100+ Scripts<br/><i>Digest, DB, worktree</i>"]
        BUDGET["Budget Engine<br/><i>Daily caps, fallback chain</i>"]
    end

    REQ --> P --> PL --> EX
    EX --> ORCHESTRATOR
    ORCHESTRATOR --> TH
    TH -->|PASS| DB
    TH -->|FAIL max 3x| EX
    ORCHESTRATOR --> AGENTS
    AGENTS --> INFRA
    BUDGET -.->|enforces| ROUTE
```

## Agent Ecosystem Architecture

```mermaid
graph TB
    subgraph "Platforms"
        CC[Claude Code<br/>65 agents, parallel workers]
        COP[Copilot CLI<br/>9 agents, sequential TDD]
    end

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

    subgraph "Release Management (4)"
        ARM[app-release-manager]
        ARE[app-release-manager-execution]
        FRM[feature-release-manager]
        ESYNC[ecosystem-sync<br/>Dual Platform]
    end

    CC -->|full suite| ALI
    COP -->|workflow agents| SP
    COP -->|code-reviewer| REX
    COP -->|validate| THOR

    ALI -->|orchestrates| SP
    SP -->|creates waves| TE
    TE -->|follows| TETDD
    TE -->|validated by| THOR
    THOR -->|uses| TVG
    THOR -->|delegates| BACCIO
    THOR -->|delegates| REX
    THOR -->|delegates| OTTO
    ARM -->|uses| ARE
    ESYNC -->|syncs| ARM
```

## Execution Flow (Prompt → Plan → Execute → Verify)

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

## Hook System & Token Optimization

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

## Script Architecture (100+ Scripts)

```mermaid
flowchart LR
    subgraph ORCH["Orchestrator (14)"]
        D[delegate.sh]
        EP[execute-plan.sh]
        CW2[copilot-worker.sh]
        OW2[opencode-worker.sh]
        GW2[gemini-worker.sh]
        MR[model-registry.sh]
        EV[env-vault.sh]
        WS[worktree-safety.sh]
        HC[hardening-check.sh]
    end

    subgraph LIBS["Shared Libraries (11)"]
        DU[delegate-utils.sh]
        AP[agent-protocol.sh]
        GH[gh-ops-routing.sh]
        QG[quality-gate-templates.sh]
        PDD[plan-db-delegate.sh]
        DD[dashboard-delegation.sh]
        PDC[plan-db-core.sh]
        PDCR[plan-db-crud.sh]
        PDV[plan-db-validate.sh]
    end

    subgraph DIGEST["Digest Scripts (14)"]
        GD[git-digest]
        BD[build-digest]
        TD[test-digest]
        CD[ci-digest]
        MORE["+ 10 more"]
    end

    subgraph PLANDB["Plan DB"]
        PDB[plan-db.sh]
        PDBS[plan-db-safe.sh]
    end

    subgraph INFRA["Infrastructure"]
        DASH[dashboard-mini.sh]
        FL[file-lock.sh]
        PR[pr-ops.sh]
        WT[worktree-create.sh]
    end

    D --> DU & AP
    EP --> D & PDB
    PDB --> PDC & PDCR & PDV
    DASH --> PDB
```

## Plugin Structure

```
MyConvergio/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── .claude/
│   ├── CLAUDE.md             # Main config
│   ├── agents/               # 65 agents (8 categories)
│   ├── config/               # orchestrator.yaml (with learnings section)
│   ├── docs/                 # gemini-setup.md, ADRs
│   ├── hooks/                # model-registry-refresh.sh
│   ├── rules/                # Execution rules
│   ├── scripts/              # 100+ scripts (digest, orchestrator, DB, worktree)
│   │   └── lib/              # Shared libs (delegate-utils, agent-protocol, etc.)
│   ├── reference/            # 11 on-demand operational docs
│   ├── skills/               # 10 reusable workflows + hardening
│   └── templates/            # State tracking templates
├── copilot-agents/           # 9 Copilot CLI agents
├── hooks/                    # 12 enforcement hooks + lib/
├── commands/                 # 3 slash commands
├── scripts/                  # Install/backup/test scripts
├── tests/                    # 25 test files (0 failures)
└── bin/myconvergio.js        # CLI entry point
```

---

For orchestrator details, see [orchestrator.md](./orchestrator.md).
For agent portfolio, see [agent-portfolio.md](./agent-portfolio.md).
