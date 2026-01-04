# Planner + Orchestrator

Planning and parallel execution with multiple Claude instances (max 3 - safer).

## Datetime Format (MANDATORY)

All timestamps in plans and outputs MUST use full datetime with timezone:
- **Format**: `DD Mese YYYY, HH:MM TZ`
- **Example**: `3 Gennaio 2026, 16:43 CET`
- **Never**: Just date without time

Apply to: Plan headers, checkpoint logs, Last Updated, Created timestamps.

## File Size Limit (MANDATORY)

Per `rules/file-size-limits.md`: **Max 300 lines per file.**

### Plan Split Strategy

When a plan exceeds 300 lines, split into:

```
docs/plans/
├── ProjectPlan-Main.md       # Tracker only (< 300 lines)
├── ProjectPlan-Phase1.md     # Phase 1 details (< 300 lines)
└── ...
```

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
2. Agents checkpoint progress in plan file
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
- `T-01: Refactor authentication` (executor explores 50 files)

**GOOD** (executor executes without exploration):
- `T-01: Add logout() to src/lib/auth.ts line 45`
- `T-02: Update src/app/api/logout/route.ts`

**Rule**: If executor needs to explore >3 files, task is too vague.

### Required Structure

```markdown
# [ProjectName]Plan[Date] - [Brief Description]

**Created**: DD Mese YYYY, HH:MM CET | **Target**: [Objective] | **Metodo**: VERIFICA BRUTALE

---

## CHECKPOINT LOG

| Timestamp | Agent | Task | Status | Notes |
|-----------|-------|------|--------|-------|
| HH:MM | CLAUDE 2 | T-01 | Done | Completed |
| HH:MM | CLAUDE 3 | T-02 | CRASHED | resume here |

**Last Good State**: [description of what was completed]
**Resume Instructions**: [what to do if resuming after crash]

---

## RUOLI CLAUDE

| Claude | Ruolo | Task | Model |
|--------|-------|------|-------|
| CLAUDE 1 | PLANNER/COORDINATOR | Crea piano, monitora | **opus** |
| CLAUDE 2 | EXECUTOR | [Task IDs semplici] | haiku |
| CLAUDE 3 | EXECUTOR | [Task IDs semplici] | haiku |

**Model Selection**:
- **opus**: Pianificazione, decisioni architetturali, contesto ampio
- **sonnet**: Execution di task complessi (refactor multi-file)
- **haiku**: Execution di task semplici (<10 file, isolati)

---

## REGOLE (TUTTI I CLAUDE)

1. Leggi TUTTO il piano prima di iniziare
2. Per ogni task: implementa, verifica, **AGGIORNA CHECKPOINT LOG**, marca done
3. **Verifica OBBLIGATORIA**: `npm run lint && npm run typecheck && npm run build`
4. NON "FATTO" senza checkpoint aggiornato
5. Se crash/blocco: scrivi stato nel CHECKPOINT LOG prima di morire
6. **CONTINUOUS EXECUTION**: Completa TUTTI i task assegnati senza fermarti

## EXECUTOR RULES (anti-crash)

**Executors read ONLY files in task. No exploration.**
- Task says "update auth.ts" read auth.ts ONLY
- Need context? Grep, don't read whole files
- If task unclear, checkpoint "Task vague", signal CLAUDE 1

---

## FUNCTIONAL REQUIREMENTS (MANDATORY)

Every plan MUST include functional requirements that Thor will verify.

| ID | Requisito Funzionale | Criterio di Accettazione | Verificato |
|----|---------------------|-------------------------|------------|
| F-01 | [Cosa deve FUNZIONARE] | [Come si verifica che funziona] | [ ] |

**Rules:**
- Each feature = at least 1 functional requirement
- Criteria must be TESTABLE (not vague)
- Thor verifies each `[ ]` before approval

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
| [ ] | T-01 | Add logout() after line 45 | CLAUDE 2 | `src/lib/auth.ts` |
| [ ] | T-FINAL | THOR VALIDATION | thor | All |

**Note**: Tasks MUST specify exact file paths. Vague tasks cause crashes.

---
```

**See also**: [planner-reference.md](./planner-reference.md) for Git/PR templates, Dashboard, Agent routing

## STATUS LEGEND

[ ] Not started | [~] In progress | [x] Done | [!] Crashed/Blocked
