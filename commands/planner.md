# Planner + Orchestrator

Planning and parallel execution with multiple Claude instances (max 3 - safer).

## Datetime Format (MANDATORY)

All timestamps in plans and outputs MUST use full datetime with timezone:
- **Format**: `DD Mese YYYY, HH:MM TZ`
- **Example**: `3 Gennaio 2026, 16:43 CET`
- **Never**: Just date without time

Apply to: Plan headers, checkpoint logs, Last Updated, Created timestamps.

## File Size Limit (MANDATORY)

Per `rules/file-size-limits.md`: **Max 250 lines per file.**

### Plan Split Strategy

When a plan exceeds 250 lines, split into:

```
docs/plans/
├── ProjectPlan-Main.md       # Tracker only (< 250 lines)
├── ProjectPlan-Phase1.md     # Phase 1 details (< 250 lines)
├── ProjectPlan-Phase2.md     # Phase 2 details (< 250 lines)
└── ...
```

**Main file contains**:
- Overview, objectives, global progress
- Phase list with links to phase files
- Checkpoint log (summary)

**Phase files contain**:
- Detailed task breakdown
- Phase-specific checkpoint log
- Implementation details

## PROJECT CONTEXT

Before planning, check `./CLAUDE.md` for project-specific rules:
- `## Project Rules` → Add to plan verification steps
- `## Commands` → Use for verification commands in plan
- If no `./CLAUDE.md`, use global rules only

## WORKFLOW

```
1. Read project context → 2. Gather requirements → 3. Create plan file → 4. Ask "Eseguire?" → 5. Orchestrate
```

## QUICK COMMANDS

| Request | Action |
|---------|--------|
| "mostra stato" / "dashboard" | Launch dashboard for current project |
| "stato progetti" | Show all registered projects |
| "pianifica X" | Create new plan for X |
| "esegui piano" | Execute current plan |

When user says "mostra stato" or "dashboard":
1. Get project_id from current folder: `basename $(pwd)`
2. Launch server: `npx live-server ~/.claude --port=31415 --no-browser &`
3. Open: `open http://127.0.0.1:31415/dashboard/dashboard.html`

## ANTI-CRASH RULES

1. **ALWAYS write plan file BEFORE launching agents**
2. Agents checkpoint progress in plan file (✅/❌)
3. **Use `haiku` for simple tasks** (default - fast, cheap, no context issues)
4. **Max 3 parallel agents** (4 = crash risk)
5. If crash: read plan, resume from last checkpoint

## TOKEN SAFETY

**Prevention**: Read(limit), Grep for searches, Task tool for exploration
**Models**: haiku (<10 files), sonnet (complex), opus (planning)

## PLAN FILE

**Location**: `docs/plans/[ProjectName]Plan[Date].md`

**CRITICAL - Task Atomicity**:
OPUS/Planner responsibility: Tasks MUST be atomic and file-specific.

**BAD** (causes executor crash):
- `T-01: Refactor authentication` ❌ (executor explores 50 files)

**GOOD** (executor executes without exploration):
- `T-01: Add logout() to src/lib/auth.ts line 45` ✅
- `T-02: Update src/app/api/logout/route.ts` ✅

**Rule**: If executor needs to explore >3 files, task is too vague.

### Required Structure

```markdown
# [ProjectName]Plan[Date] - [Brief Description]

**Created**: DD Mese YYYY, HH:MM CET | **Target**: [Objective] | **Metodo**: VERIFICA BRUTALE

---

## CHECKPOINT LOG

| Timestamp | Agent | Task | Status | Notes |
|-----------|-------|------|--------|-------|
| HH:MM | CLAUDE 2 | T-01 | ✅ | Completed |
| HH:MM | CLAUDE 3 | T-02 | ❌ | CRASHED - resume here |

**Last Good State**: [description of what was completed]
**Resume Instructions**: [what to do if resuming after crash]

---

## RUOLI CLAUDE

| Claude | Ruolo | Task | Model |
|--------|-------|------|-------|
| CLAUDE 1 | PLANNER/COORDINATOR | Crea piano, monitora | **opus** (pianificazione complessa) |
| CLAUDE 2 | EXECUTOR | [Task IDs semplici] | haiku |
| CLAUDE 3 | EXECUTOR | [Task IDs semplici] | haiku |

**Model Selection**:
- **opus**: Pianificazione, decisioni architetturali, contesto ampio
- **sonnet**: Execution di task complessi (refactor multi-file)
- **haiku**: Execution di task semplici (<10 file, isolati)

---

## REGOLE (TUTTI I CLAUDE)

1. Leggi TUTTO il piano prima di iniziare
2. Per ogni task: implementa → verifica → **AGGIORNA CHECKPOINT LOG** → marca ✅
3. **Verifica OBBLIGATORIA**: `npm run lint && npm run typecheck && npm run build`
4. NON "FATTO" senza checkpoint aggiornato
5. Se crash/blocco: scrivi stato nel CHECKPOINT LOG prima di morire
6. **CONTINUOUS EXECUTION**: Completa TUTTI i task assegnati senza fermarti

## EXECUTOR RULES (anti-crash)

**Executors read ONLY files in task. No exploration.**
- Task says "update auth.ts" → read auth.ts ONLY
- Need context? Grep, don't read whole files
- If task unclear → checkpoint "Task vague", signal CLAUDE 1

---

## FUNCTIONAL REQUIREMENTS (MANDATORY)

Every plan MUST include functional requirements that Thor will verify.

| ID | Requisito Funzionale | Criterio di Accettazione | Verificato |
|----|---------------------|-------------------------|------------|
| F-01 | [Cosa deve FUNZIONARE] | [Come si verifica che funziona] | [ ] |
| F-02 | ... | ... | [ ] |

**Rules:**
- Each feature = at least 1 functional requirement
- Criteria must be TESTABLE (not vague)
- Thor verifies each `[ ]` before approval

**Example:**
| ID | Requisito | Criterio | Verificato |
|----|-----------|----------|------------|
| F-01 | Logout disconnette utente | Dopo click logout, API /me ritorna 401 | [ ] |
| F-02 | Redirect a login | Dopo logout, URL = /login | [ ] |

---

## DOCUMENTATION

| Type | When | File |
|------|------|------|
| ADR | Arch decision | `docs/adr/NNN-title.md` |
| CHANGELOG | User-facing change | `CHANGELOG.md` |
| README | New feature OR setup change | `README.md` |

Checklist: [ ] ADR [ ] CHANGELOG [ ] README [ ] Code docs

---

## EXECUTION TRACKER

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| ⬜ | T-01 | Add logout() after line 45 | CLAUDE 2 | `src/lib/auth.ts` |
| ⬜ | T-02 | Update route to call logout | CLAUDE 2 | `src/app/api/logout/route.ts` |
| ⬜ | T-FINAL | ✅ THOR VALIDATION | thor | All |

**Note**: Tasks MUST specify exact file paths. Vague tasks cause crashes.

---

## THOR APPROVAL SECTION

**Status**: PENDING
**Validated**: ___ / ___ functional requirements
**Gates Passed**: ___ / ___

- [ ] F-01 verified and working
- [ ] F-02 verified and working
- [ ] Build/lint/typecheck pass
- [ ] Documentation complete

**Thor Signature**: _____________ **Date**: _______

---

## PROGRESS

| Phase | Done/Total |
|-------|------------|
| 1 | 0/N |
| **TOTAL** | 0/N |
```

## CENTRALIZED PLANS (V3)

All plans are stored centrally in `~/.claude/plans/` with multi-project support.

### Structure

```
~/.claude/plans/
├── registry.json              # Project index
└── {project_id}/
    ├── {PlanName}.md          # Plan markdown
    └── current.json           # Active plan state (V2 schema)
```

### Workflow on Plan Creation

When `/planner` executes from any project folder:

1. **Auto-register project**: `~/.claude/scripts/register-project.sh $(pwd)`
   - Detects project_id from folder name
   - Captures git remote, GitHub URL
   - Creates `~/.claude/plans/{project_id}/`

2. **Create plan files**:
   - `~/.claude/plans/{project_id}/{PlanName}.md`
   - `~/.claude/plans/{project_id}/current.json`

3. **Track changes**: `~/.claude/scripts/track-plan-change.sh`
   - Records every modification with type and reason
   - Enables learning/optimization over time

### Plan Change Types

| Type | When Used |
|------|-----------|
| `created` | Initial plan creation |
| `user_edit` | User modifies tasks/scope |
| `scope_add` | New requirements added |
| `scope_remove` | Requirements removed |
| `blocker` | Blocker discovered |
| `task_split` | Task broken into smaller units |
| `completed` | Plan finished |

### Dashboard (V3 Multi-Project)

**URL**: `http://127.0.0.1:31415/dashboard/`

**Start** (from any folder):
```bash
npx live-server ~/.claude --port=31415 --no-browser &
open http://127.0.0.1:31415/dashboard/dashboard.html
```

**Features**:
- Project menu: Switch between registered projects
- History tab: View plan modifications timeline
- Learning stats: Track optimization patterns
- Auto-selects project based on last used

---

## GIT/ORCHESTRATION

**Worktree**: `git worktree add ../proj-C2 feature/plan-phase1`
**Launch**: `~/.claude/scripts/claude-parallel.sh 3`
**Recovery**: `cat docs/plans/*.md | grep "CHECKPOINT"`
**PR**: `git commit -m "feat: X" && gh pr create`

## STATUS LEGEND

⬜ Not started | 🔄 In progress | ✅ Done | ❌ Crashed/Blocked | 🔴 LOCKED | 🟢 UNLOCKED

## AGENT DISCOVERY

Per `rules/agent-discovery.md`: Check MyConvergio specialists first.
1. MyConvergio (`/Users/roberdan/GitHub/MyConvergio/agents/`) = 50+ domain experts
2. Local (`~/.claude/agents/`) = fallback

## EXECUTOR DELEGATION

| Domain | MyConvergio Specialist | Default Fallback |
|--------|------------------------|------------------|
| Marketing | `sofia-marketing-strategist` | - |
| Sales/BD | `fabio-sales-business-development` | - |
| Strategy | `domik-mckinsey-strategic-decision-maker` | - |
| Finance | `amy-cfo` | - |
| Architecture | `baccio-tech-architect` | `baccio-tech-architect` |
| Code review | `rex-code-reviewer` | `rex-code-reviewer` |
| Debugging | `dario-debugger` | `dario-debugger` |
| Performance | `otto-performance-optimizer` | `otto-performance-optimizer` |
| DevOps | `marco-devops-engineer` | `marco-devops-engineer` |
| Security | `luca-security-expert` | - |
| UX/Design | `sara-ux-ui-designer` | - |
| Data Science | `omri-data-scientist` | - |
| QA | `thor-quality-assurance-guardian` | `thor-quality-assurance-guardian` |

### Delegation Rules

1. **MyConvergio first** → 2. Simple=haiku, Complex=specialist → 3. Max 3 parallel → 4. Thor validates
