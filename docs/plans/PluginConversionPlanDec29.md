# PluginConversionPlanDec29 - MyConvergio to Claude Code Plugin

**Data**: 2025-12-29
**Target**: Convertire MyConvergio da npm package a Claude Code plugin per marketplace
**Metodo**: VERIFICA BRUTALE - ogni task testato prima di dichiararlo fatto

---

## 🎭 RUOLI CLAUDE

| Claude | Ruolo | Task Assegnati |
|--------|-------|----------------|
| **CLAUDE 1** | 🎯 COORDINATORE | Monitora piano, crea plugin.json, verifica finale, merge |
| **CLAUDE 2** | 👨‍💻 AGENT MIGRATOR | T-01 → T-04 (4 categorie agenti: leadership, technical, operations, design) |
| **CLAUDE 3** | 👨‍💻 AGENT MIGRATOR | T-05 → T-08 (4 categorie agenti: compliance, specialists, core, release) |
| **CLAUDE 4** | 👨‍💻 COMPONENTS | T-09 → T-14 (skills, rules, commands, hooks, docs) |

> **MAX 4 CLAUDE** - Oltre diventa ingestibile e aumenta rischio conflitti git

---

## ⚠️ REGOLE OBBLIGATORIE PER TUTTI I CLAUDE

```
1. PRIMA di iniziare: leggi TUTTO questo file
2. Trova i task assegnati a te (cerca "CLAUDE X" dove X è il tuo numero)
3. Per OGNI task:
   a. Leggi i file indicati
   b. Esegui la migrazione/creazione
   c. Esegui TUTTI i comandi di verifica
   d. Solo se TUTTI passano, aggiorna questo file marcando ✅ DONE

4. VERIFICA OBBLIGATORIA dopo ogni task:
   - Verifica che i file esistano: ls -la [path]
   - Verifica YAML frontmatter valido (se applicabile)
   - Verifica che il plugin si carichi: claude --plugin-dir . --help

5. NON DIRE MAI "FATTO" SE:
   - Non hai eseguito i comandi di verifica
   - Il file non esiste o ha errori di sintassi
   - Non hai aggiornato questo file

6. Se trovi problemi/blocchi: CHIEDI invece di inventare soluzioni

7. Dopo aver completato: aggiorna la sezione EXECUTION TRACKER con ✅

8. CONFLITTI GIT: Se ci sono conflitti, risolvi mantenendo ENTRAMBE le modifiche

9. STRUTTURA PLUGIN RICHIESTA:
   MyConvergio/
   ├── .claude-plugin/
   │   └── plugin.json          # CLAUDE 1 crea questo
   ├── agents/                   # Tutti gli agenti qui (flat structure)
   ├── skills/                   # Skills esistenti
   ├── commands/                 # CLAUDE 4 crea questi
   └── hooks/                    # CLAUDE 4 crea questi
```

---

## 🎯 EXECUTION TRACKER

### Phase 1: Setup Plugin Structure — 2/2 ✅

| Status | ID | Task | Assignee | Files | Note |
|:------:|-----|------|----------|-------|------|
| ✅ | T-00 | Crea .claude-plugin/plugin.json | **CLAUDE 1** | `.claude-plugin/plugin.json` | Manifest obbligatorio |
| ✅ | T-00b | Crea directory agents/ vuota | **CLAUDE 1** | `agents/` | Preparazione struttura |

### Phase 2: Agent Migration (PARALLELIZZABILE) — 8/8 ✅

| Status | ID | Task | Assignee | Files | Note |
|:------:|-----|------|----------|-------|------|
| ✅ | T-01 | Migrate leadership_strategy (7 agents) | **CLAUDE 2** | `agents/ali-*.md`, `agents/satya-*.md`, etc. | Copia da .claude/agents/ |
| ✅ | T-02 | Migrate technical_development (7 agents) | **CLAUDE 2** | `agents/baccio-*.md`, `agents/dario-*.md`, etc. | Copia da .claude/agents/ |
| ✅ | T-03 | Migrate business_operations (11 agents) | **CLAUDE 2** | `agents/davide-*.md`, `agents/anna-*.md`, etc. | Copia da .claude/agents/ |
| ✅ | T-04 | Migrate design_ux (3 agents) | **CLAUDE 2** | `agents/jony-*.md`, `agents/sara-*.md`, etc. | Copia da .claude/agents/ |
| ✅ | T-05 | Migrate compliance_legal (5 agents) | **CLAUDE 3** | `agents/elena-*.md`, `agents/luca-*.md`, etc. | ✅ DONE - 5 files |
| ✅ | T-06 | Migrate specialized_experts (13 agents) | **CLAUDE 3** | `agents/behice-*.md`, `agents/fiona-*.md`, etc. | ✅ DONE - 13 files |
| ✅ | T-07 | Migrate core_utility (13 files) | **CLAUDE 3** | `agents/marcus-*.md`, `agents/thor-*.md`, etc. | ✅ DONE - incl. CONSTITUTION.md |
| ✅ | T-08 | Migrate release_management (2 agents) | **CLAUDE 3** | `agents/app-release-*.md`, `agents/feature-release-*.md` | ✅ DONE - 2 files |

### Phase 3: Skills & Rules Migration — 2/2 ✅

| Status | ID | Task | Assignee | Files | Note |
|:------:|-----|------|----------|-------|------|
| ✅ | T-09 | Migrate skills (8 directories) | **CLAUDE 4** | `skills/*/SKILL.md` | 9 skills migrated |
| ✅ | T-10 | Migrate rules (6 files) | **CLAUDE 4** | `.claude/rules/*.md` → includi in plugin | Rules in .claude/rules/ (user copies) |

### Phase 4: Commands & Hooks — 4/4 ✅

| Status | ID | Task | Assignee | Files | Note |
|:------:|-----|------|----------|-------|------|
| ✅ | T-11 | Crea command: status.md | **CLAUDE 4** | `commands/status.md` | DONE |
| ✅ | T-12 | Crea command: team.md | **CLAUDE 4** | `commands/team.md` | DONE - 57 agents |
| ✅ | T-13 | Crea command: plan.md | **CLAUDE 4** | `commands/plan.md` | DONE |
| ✅ | T-14 | Crea hooks.json | **CLAUDE 4** | `hooks/hooks.json` | DONE - empty |

### Phase 5: Documentation & Verification — 0/3

| Status | ID | Task | Assignee | Files | Note |
|:------:|-----|------|----------|-------|------|
| ⬜ | T-15 | Aggiorna README.md per marketplace | **CLAUDE 1** | `README.md` | Descrizione, installazione, features |
| ⬜ | T-16 | Test plugin completo | **CLAUDE 1** | - | `claude --plugin-dir .` |
| ⬜ | T-17 | Commit finale | **CLAUDE 1** | - | `feat(v3.0.0): Claude Code marketplace plugin` |

---

## 📋 TASK DETTAGLIATI PER CLAUDE

## CLAUDE 1: COORDINATORE

### Responsabilità
1. **Setup Iniziale**: Crea plugin.json e struttura base
2. **Monitoraggio**: Controlla periodicamente questo file per aggiornamenti
3. **Verifica Finale**: Test completo del plugin
4. **Merge/Commit**: Quando tutti i task sono ✅

### Task T-00: Crea plugin.json

#### File da creare
`.claude-plugin/plugin.json`

#### Contenuto
```json
{
  "name": "myconvergio",
  "version": "3.0.0",
  "description": "Enterprise Agent Suite: 57 specialized AI agents for strategy, development, compliance, and operations",
  "author": {
    "name": "Roberto Dandrea",
    "email": "info@roberdan.com",
    "url": "https://github.com/roberdan"
  },
  "homepage": "https://github.com/roberdan/MyConvergio",
  "repository": "https://github.com/roberdan/MyConvergio",
  "license": "CC-BY-NC-SA-4.0",
  "keywords": [
    "enterprise",
    "agents",
    "strategy",
    "architecture",
    "compliance",
    "operations",
    "ai-agents",
    "subagents"
  ]
}
```

#### Verifica
```bash
mkdir -p .claude-plugin
# Crea il file con Write tool
cat .claude-plugin/plugin.json  # Verifica contenuto
```

### Task T-00b: Crea directory agents/

```bash
mkdir -p agents
mkdir -p commands
mkdir -p hooks
```

### Task T-15: README per marketplace

Aggiorna README.md con:
- Descrizione accattivante
- Lista 57 agenti organizzati per categoria
- Istruzioni installazione plugin
- Esempi di utilizzo

### Task T-16: Test plugin

```bash
# Test che il plugin si carichi
claude --plugin-dir /path/to/MyConvergio --help

# Verifica agents scoperti
ls -la agents/ | wc -l  # Deve essere 57+
```

### Comandi di Monitoraggio
```bash
# Controlla progresso
grep -c "✅" docs/plans/PluginConversionPlanDec29.md

# Verifica struttura
tree -L 2 -I node_modules
```

---

## CLAUDE 2: AGENT MIGRATOR (Leadership, Technical, Operations, Design)

### Task T-01: Migrate leadership_strategy (7 agents)

#### Obiettivo
Copiare i 7 agenti da `.claude/agents/leadership_strategy/` a `agents/`

#### File sorgente
```bash
ls .claude/agents/leadership_strategy/
```

#### Azioni richieste
```bash
# Per OGNI file .md in leadership_strategy:
cp .claude/agents/leadership_strategy/*.md agents/
```

#### Verifica
```bash
ls agents/ | grep -E "ali|satya|domik|antonio|amy|dan|matteo" | wc -l
# Deve essere 7
```

---

### Task T-02: Migrate technical_development (7 agents)

#### File sorgente
`.claude/agents/technical_development/`

#### Azioni
```bash
cp .claude/agents/technical_development/*.md agents/
```

#### Verifica
```bash
ls agents/ | grep -E "baccio|marco|dario|rex|otto|paolo|omri" | wc -l
# Deve essere 7
```

---

### Task T-03: Migrate business_operations (11 agents)

#### File sorgente
`.claude/agents/business_operations/`

#### Azioni
```bash
cp .claude/agents/business_operations/*.md agents/
```

#### Verifica
```bash
ls agents/*.md | wc -l
# Deve aumentare di 11
```

---

### Task T-04: Migrate design_ux (3 agents)

#### File sorgente
`.claude/agents/design_ux/`

#### Azioni
```bash
cp .claude/agents/design_ux/*.md agents/
```

#### Verifica
```bash
ls agents/ | grep -E "jony|sara|stefano" | wc -l
# Deve essere 3
```

---

## CLAUDE 3: AGENT MIGRATOR (Compliance, Specialists, Core, Release)

### Task T-05: Migrate compliance_legal (5 agents)

#### File sorgente
`.claude/agents/compliance_legal/`

#### Azioni
```bash
cp .claude/agents/compliance_legal/*.md agents/
```

#### Verifica
```bash
ls agents/ | grep -E "elena|luca|enzo|sophia|guardian" | wc -l
# Deve essere 5
```

---

### Task T-06: Migrate specialized_experts (13 agents)

#### File sorgente
`.claude/agents/specialized_experts/`

#### Azioni
```bash
cp .claude/agents/specialized_experts/*.md agents/
```

#### Verifica
```bash
ls agents/*.md | wc -l
# Deve aumentare di 13
```

---

### Task T-07: Migrate core_utility (10 files)

#### File sorgente
`.claude/agents/core_utility/`

#### ATTENZIONE
Questa directory contiene anche file non-agente (CONSTITUTION.md, CommonValuesAndPrinciples.md, etc.).
Copia TUTTI i file .md - sono riferimenti importanti per gli agenti.

#### Azioni
```bash
cp .claude/agents/core_utility/*.md agents/
```

#### Verifica
```bash
ls agents/ | grep -E "marcus|thor|diana|socrates|ava|wanda|xavier|taskmaster|strategic-planner|po-prompt" | wc -l
```

---

### Task T-08: Migrate release_management (2 agents)

#### File sorgente
`.claude/agents/release_management/`

#### Azioni
```bash
cp .claude/agents/release_management/*.md agents/
```

#### Verifica
```bash
ls agents/ | grep -E "app-release|feature-release" | wc -l
# Deve essere 2
```

---

## CLAUDE 4: COMPONENTS (Skills, Rules, Commands, Hooks)

### Task T-09: Migrate skills (8 directories)

#### Obiettivo
Le skills sono GIÀ nella struttura corretta in `.claude/skills/`.
Devi copiarle in `skills/` al root del plugin.

#### File sorgente
```bash
ls .claude/skills/
# architecture, code-review, debugging, orchestration, performance,
# project-management, release-management, security-audit, strategic-analysis
```

#### Azioni
```bash
cp -r .claude/skills/* skills/
```

#### Verifica
```bash
ls skills/*/SKILL.md | wc -l
# Deve essere 8-9
```

---

### Task T-10: Rules Migration

#### NOTA
Le rules in Claude Code plugin vanno in `.claude/rules/` del progetto utente, NON nel plugin.
Il plugin può includere le rules come riferimento/documentazione ma non le installa automaticamente.

#### Azioni
Documenta nel README che l'utente può copiare le rules da `.claude/rules/` se le vuole.

---

### Task T-11: Crea command status.md

#### File da creare
`commands/status.md`

#### Contenuto
```markdown
---
name: status
description: Show MyConvergio ecosystem status and agent counts
allowed-tools: []
---

# MyConvergio Status

Display the current status of the MyConvergio agent ecosystem.

## Instructions

When the user runs `/myconvergio:status`, provide:

1. **Agent Count Summary**
   - Total agents: 57
   - By category breakdown

2. **Category Breakdown**
   | Category | Count |
   |----------|-------|
   | Leadership & Strategy | 7 |
   | Technical Development | 7 |
   | Business Operations | 11 |
   | Design & UX | 3 |
   | Compliance & Legal | 5 |
   | Specialized Experts | 13 |
   | Core Utility | 9 |
   | Release Management | 2 |

3. **Quick Links**
   - Use `/myconvergio:team` to see all agents
   - Use `/myconvergio:plan` to create execution plans
   - Invoke any agent with `@agent-name`

4. **Version**
   Report current plugin version: 3.0.0
```

---

### Task T-12: Crea command team.md

#### File da creare
`commands/team.md`

#### Contenuto
```markdown
---
name: team
description: List all MyConvergio agents organized by category
allowed-tools: []
argument-hint: "[category]"
---

# MyConvergio Team

List all available agents in the MyConvergio ecosystem.

## Instructions

When the user runs `/myconvergio:team`:

1. If no argument, show ALL agents organized by category
2. If category argument provided, filter to that category

## Agent Catalog

### Leadership & Strategy (7)
- **ali-chief-of-staff**: Master orchestrator for complex multi-domain challenges
- **satya-board-of-directors**: Board-level strategic advisor
- **domik-mckinsey**: McKinsey Partner-level strategic decision maker
- **antonio-strategy-expert**: Strategy framework expert (OKR, Lean, Agile)
- **amy-cfo**: Chief Financial Officer for financial strategy
- **dan-engineering-gm**: Engineering General Manager
- **matteo-strategic-business-architect**: Business strategy architect

### Technical Development (7)
- **baccio-tech-architect**: Elite Technology Architect for system design
- **marco-devops-engineer**: DevOps for CI/CD and infrastructure
- **dario-debugger**: Systematic debugging expert
- **rex-code-reviewer**: Code review specialist
- **otto-performance-optimizer**: Performance optimization specialist
- **paolo-best-practices-enforcer**: Coding standards enforcer
- **omri-data-scientist**: Data Scientist for ML and AI

### Business Operations (11)
- **davide-project-manager**: Project Manager (Agile, Scrum, Waterfall)
- **marcello-pm**: Product Manager for strategy and roadmaps
- **oliver-pm**: Senior Product Manager
- **luke-program-manager**: Program Manager for portfolios
- **anna-executive-assistant**: Executive Assistant with task management
- **andrea-customer-success-manager**: Customer Success Manager
- **fabio-sales-business-development**: Sales & Business Development
- **sofia-marketing-strategist**: Marketing Strategist
- **steve-executive-communication-strategist**: Executive Communication
- **enrico-business-process-engineer**: Business Process Engineer
- **dave-change-management-specialist**: Change Management specialist

### Design & UX (3)
- **jony-creative-director**: Creative Director for brand innovation
- **sara-ux-ui-designer**: UX/UI Designer
- **stefano-design-thinking-facilitator**: Design Thinking facilitator

### Compliance & Legal (5)
- **elena-legal-compliance-expert**: Legal & Compliance expert
- **luca-security-expert**: Cybersecurity expert
- **dr-enzo-healthcare-compliance-manager**: Healthcare Compliance (HIPAA, FDA)
- **sophia-govaffairs**: Government Affairs specialist
- **guardian-ai-security-validator**: AI Security validator

### Specialized Experts (13)
- **behice-cultural-coach**: Cultural intelligence expert
- **fiona-market-analyst**: Market Analyst for financial research
- **michael-vc**: Venture Capital analyst
- **angela-da**: Senior Decision Architect
- **ethan-da**: Data Analytics specialist
- **evan-ic6da**: Principal Decision Architect (IC6)
- **ava-analytics-insights-virtuoso**: Analytics virtuoso
- **riccardo-storyteller**: Narrative designer
- **jenny-inclusive-accessibility-champion**: Accessibility champion
- **giulia-hr-talent-acquisition**: HR & Talent Acquisition
- **sam-startupper**: Silicon Valley startup expert
- **wiz-investor-venture-capital**: Venture Capital investor
- **coach-team-coach**: Team Coach

### Core Utility (9)
- **marcus-context-memory-keeper**: Institutional memory guardian
- **thor-quality-assurance-guardian**: Quality watchdog
- **diana-performance-dashboard**: Performance dashboard specialist
- **socrates-first-principles-reasoning**: First principles reasoning master
- **strategic-planner**: Wave-based execution plan creator
- **taskmaster-strategic-task-decomposition-master**: Task decomposition expert
- **po-prompt-optimizer**: Prompt engineering expert
- **wanda-workflow-orchestrator**: Workflow orchestrator
- **xavier-coordination-patterns**: Coordination patterns architect

### Release Management (2)
- **app-release-manager**: Release engineering with quality gates
- **feature-release-manager**: Feature completion and issue closure

## Usage

Invoke any agent with: `@agent-name [your request]`

Example: `@baccio-tech-architect Design a microservices architecture for our e-commerce platform`
```

---

### Task T-13: Crea command plan.md

#### File da creare
`commands/plan.md`

#### Contenuto
```markdown
---
name: plan
description: Create a strategic execution plan using the strategic-planner agent
allowed-tools: ["Task"]
argument-hint: "<objective>"
---

# MyConvergio Plan

Create a comprehensive execution plan for complex tasks.

## Instructions

When the user runs `/myconvergio:plan <objective>`:

1. Invoke the strategic-planner agent using the Task tool:
   ```
   Use the Task tool with subagent_type="strategic-planner" and prompt:
   "Create a comprehensive execution plan for: <user's objective>"
   ```

2. The strategic-planner will create a wave-based plan with:
   - STATUS DASHBOARD with phases
   - Parallel lanes for independent tasks
   - Atomic tasks with verification commands
   - Checkpoint commits every 3-5 tasks

3. Save the plan to `docs/plans/[ProjectName]Plan[Date].md`

4. Ask if user wants to execute in parallel (if running in Kitty)

## Example

User: `/myconvergio:plan Migrate the monolith to microservices`

Result: Creates detailed plan with phases, task assignments, and verification steps.
```

---

### Task T-14: Crea hooks.json

#### File da creare
`hooks/hooks.json`

#### Contenuto
```json
{
  "hooks": []
}
```

#### Nota
Per ora hooks vuoto. Si può aggiungere in futuro:
- SessionStart: suggerire agenti rilevanti per il progetto
- PostToolUse su errori: suggerire dario-debugger

---

## 📊 PROGRESS SUMMARY

| Category | Done | Total | Status |
|----------|:----:|:-----:|--------|
| Phase 1: Setup | 2 | 2 | ✅ |
| Phase 2: Agents | 8 | 8 | ✅ |
| Phase 3: Skills/Rules | 2 | 2 | ✅ |
| Phase 4: Commands/Hooks | 4 | 4 | ✅ |
| Phase 5: Docs/Test | 0 | 3 | ⬜ |
| **TOTAL** | **16** | **19** | **84%** |

---

## VERIFICATION CHECKLIST (Prima del merge)

```bash
# Struttura plugin corretta
ls -la .claude-plugin/plugin.json
ls agents/*.md | wc -l           # Deve essere ~57
ls skills/*/SKILL.md | wc -l     # Deve essere 8-9
ls commands/*.md | wc -l         # Deve essere 3
ls hooks/hooks.json              # Deve esistere

# Test plugin load
claude --plugin-dir /path/to/MyConvergio

# Git status pulito
git status
```

---

## FILE SEPARATION (CRITICAL)

Ogni Claude lavora su file DIVERSI per evitare conflitti git:

| Claude | Directory/Files |
|--------|-----------------|
| CLAUDE 1 | `.claude-plugin/`, `README.md` |
| CLAUDE 2 | `agents/` (da leadership, technical, operations, design) |
| CLAUDE 3 | `agents/` (da compliance, specialists, core, release) |
| CLAUDE 4 | `skills/`, `commands/`, `hooks/` |

**NOTA**: CLAUDE 2 e CLAUDE 3 scrivono entrambi in `agents/` ma file DIVERSI.
Non ci sono conflitti perché copiano file con nomi diversi.

---

**Versione**: 1.0
**Ultimo aggiornamento**: 2025-12-29
