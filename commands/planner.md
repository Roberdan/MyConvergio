# Planner + Orchestrator

Plan and execute with parallel Claude instances (default: 3, max: unlimited with Opus orchestration).

## Context (pre-computed)
```
Project: `basename "$(pwd)"`
Branch: `git branch --show-current 2>/dev/null || echo "not a git repo"`
Worktree: `git rev-parse --show-toplevel 2>/dev/null || pwd`
Git status: `git status --short 2>/dev/null | head -5 || echo "n/a"`
Active plans: `sqlite3 ~/.claude/data/dashboard.db "SELECT id, name, status FROM plans WHERE status IN ('todo','doing') LIMIT 3;" 2>/dev/null || echo "none"`
```

## CRITICAL RULES (NON-NEGOTIABLE)

1. **Task Executor MANDATORY**: Planner CANNOT execute directly. Use `Task(subagent_type='task-executor')` for EVERY task
2. **F-xx Requirements**: Extract ALL user requirements as F-xx. Nothing done until ALL F-xx verified [x]
3. **User Approval Gate**: BLOCK execution until explicit "si"/"yes"/"procedi"
4. **Thor Enforcement**: Wave done = Thor passed + build passed
5. **Worktree Isolation**: ALWAYS work in the correct worktree. EVERY task prompt MUST include worktree path
6. **Knowledge Codification**: Ogni errore/learning DEVE essere documentato in ADR + codificato in ESLint rules. Thor valida prima della closure

## Parallelization Mode (USER CHOICE)

**MANDATORY**: At plan approval, ASK user via AskUserQuestion:

```
Modalità di esecuzione:
1. Standard (3 task paralleli) - Bilanciata, costi moderati
2. Massima Parallelizzazione - Veloce, costi elevati, Opus orchestration

Quale modalità preferisci?
```

### Mode 1: Standard (Default)
- **Concurrency**: Max 3 task-executor in parallelo
- **Coordinator Model**: Sonnet
- **Task Model**: Haiku (→ Sonnet se complesso)
- **Cost**: $ (moderato)
- **Speed**: ⚡⚡ (normale)

### Mode 2: Massima Parallelizzazione 🚀
- **Concurrency**: Unlimited (tutti i task indipendenti in parallelo)
- **Coordinator Model**: **OPUS** (richiesto per gestire N task)
- **Task Model**: Haiku (→ Sonnet se complesso)
- **Cost**: $$$ (elevato, Opus + N task)
- **Speed**: ⚡⚡⚡⚡ (massima velocità)
- **Use case**: Deadline stretti, piani grandi (10+ task)

**CRITICAL**: Se user sceglie Mode 2, upgrade coordinator a Opus.

## Model Strategy & Optimization

| Phase | Model (Standard) | Model (Max Parallel) | Context |
|-------|------------------|---------------------|---------|
| Planning | opus | opus | Full |
| Coordination | sonnet | **opus** | Full |
| Execution | haiku | haiku | Isolated |
| Validation | sonnet | sonnet | Isolated |

**Escalation Rules**:
- Task > 3 files: haiku → sonnet
- Task complexity alta: haiku → sonnet
- Coordinamento > 3 task paralleli: sonnet → **opus**

### Context Isolation (Token Optimization)
- **task-executor**: FRESH session per task. No parent context inheritance.
- **thor**: FRESH session per validation. Skeptical, reads everything.
- **Benefit**: 50-70% token reduction vs inherited context
- **MCP**: task-executor has WebSearch/WebFetch disabled (uses Read/Grep only)

### Parallelization Strategy (Mode-Dependent)

**Standard Mode**:
- Max 3 concurrent task-executors
- Independent waves can run in parallel (max 3 total)
- Dependent tasks run sequentially
- Thor validates after each wave completes

**Max Parallel Mode**:
- ALL independent tasks launch simultaneously
- Wave-level parallelization (W1, W2 tasks all at once if independent)
- Coordinator (Opus) manages N task-executors
- Thor validates after each wave completes (same as standard)
- **Warning**: High token/cost, but 3-5x faster execution

## Workflow

### 1. Setup
```bash
# CRITICAL: Verify worktree FIRST
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
~/.claude/scripts/worktree-check.sh "$WORKTREE_PATH"

~/.claude/scripts/register-project.sh "$(pwd)" --name "Project"
~/.claude/scripts/plan-db.sh create {project_id} "{PlanName}"
```

### 2. Plan File (`~/.claude/plans/{project_id}/{PlanName}-Main.md`)
```markdown
# Piano: {Name}
**Project**: {id} | **Status**: draft
**Worktree**: {absolute_worktree_path}

## USER REQUEST (verbatim)
> [exact words]

## FUNCTIONAL REQUIREMENTS
| ID | Requirement | Wave | Verified |
|----|-------------|------|----------|
| F-01 | [from user] | W1 | [ ] |

## WAVES
W1 (Phase) → W2 (Phase)

## W1: {Phase}
| Task | Description | F-xx | Model | Status |
|------|-------------|------|-------|--------|
| T1-01 | [task] | F-01 | haiku | pending |

## LEARNINGS LOG (aggiornato durante esecuzione)
| Wave | Issue | Root Cause | Resolution | Preventive Rule |
|------|-------|------------|------------|-----------------|
| W1 | [cosa è andato storto] | [perché] | [come risolto] | [regola ESLint o pattern] |
```

### 3. Register in DB
```bash
plan-db.sh add-wave {plan_id} "W1" "Phase"  # Returns db_wave_id
plan-db.sh add-task {db_wave_id} T1-01 "Desc" P1 feature
```

### 4. User Approval (MANDATORY STOP)
Present F-xx list → User says "si"/"yes" → Proceed

### 4.5. Parallelization Mode Selection (MANDATORY)

**AFTER plan approval, BEFORE execution**: Ask via AskUserQuestion (Standard vs Max Parallel).
- **Standard**: `MAX_CONCURRENT=3`, Sonnet coordination
- **Max**: `MAX_CONCURRENT=unlimited`, **Opus coordination** (upgrade self)

Store mode: `sqlite3 ~/.claude/data/dashboard.db "UPDATE plans SET parallel_mode='$MODE' WHERE id=$PLAN_ID;"`

### 5. Start Execution (AUTO → IN FLIGHT)
```bash
# MANDATORY: Call start BEFORE executing any task
# This moves plan to "IN FLIGHT" in dashboard
plan-db.sh start {plan_id}
```
Plan status: `todo` → `doing` (visible in Mission Pipeline as IN FLIGHT)

### 6. Execute Tasks

**Use `/execute {plan_id}`** for automated execution of all tasks.

**Execution Logic** (pseudocode):
- **Standard**: Batch tasks in groups of 3, run parallel, Thor after wave
- **Max Parallel**: Launch ALL independent tasks at once (Opus coordinator), Thor after wave

**Token/Cost**: Standard ~90K/batch | Max Parallel ~30K×N/wave (+50K Opus overhead)

Manual fallback (single task):
```typescript
await Task({
  subagent_type: "task-executor",
  prompt: `Project: {id} | Plan: {plan_id} | Task: T1-01 (db_id: {id})
  **WORKTREE**: {absolute_worktree_path}
  F-xx: [acceptance criteria]

  CRITICAL: Work ONLY in the specified worktree. Run 'cd {worktree_path}' before ANY file operation.`
});
```

### 7. Thor Validation (per wave) - MANDATORY, NON-SKIPPABLE

**CRITICAL**: Thor validation is MANDATORY after EVERY wave. Never trust task executor reports without verification.

```bash
# Step 1: Launch Thor subagent (MANDATORY)
Task({
  subagent_type: "thor-quality-assurance-guardian",
  prompt: `Validate Wave {wave_code} for Plan {plan_id}.

  F-xx requirements: [list from plan]
  Expected file changes: [list files that should have been modified]

  VERIFY:
  1. Each F-xx has actual code implementation
  2. git diff shows expected changes
  3. Grep for expected patterns in modified files
  4. No regressions introduced`
});

# Step 2: Build validation (ONLY after Thor passes)
npm run lint && npm run typecheck && npm run build

# Step 3: Update DB
plan-db.sh validate {plan_id}
```

**Thor Validation Rules**:
1. **NEVER skip Thor** - even if all task executors report success
2. **NEVER trust executor reports** - always verify actual file contents
3. **Thor reads files directly** - confirms patterns exist in code
4. **Wave blocked until Thor passes** - no exceptions

**If Thor Fails**:
- DO NOT proceed to next wave
- Identify which F-xx failed
- Re-execute failed tasks OR fix manually
- Re-run Thor until PASS

### 8. Knowledge Capture (per wave, DOPO Thor pass)

**MANDATORY**: Dopo ogni wave completata, aggiorna LEARNINGS LOG nel plan file.

```markdown
## LEARNINGS LOG
| Wave | Issue | Root Cause | Resolution | Preventive Rule |
|------|-------|------------|------------|-----------------|
| W1 | Import circolare | A importava B che importava A | Estratto tipo in file condiviso | eslint-plugin-import/no-cycle |
| W1 | Cookie non validato | Usato cookie.value senza check | Aggiunto validateVisitorId() | Grep rule in pre-commit |
```

**Cosa documentare**:
- Errori incontrati durante l'esecuzione
- Falsi positivi/negativi dei test
- Pattern che hanno causato problemi
- Decisioni architetturali non ovvie
- Workaround temporanei (da rimuovere!)

### 9. ADR + ESLint Codification (pre-closure, OBBLIGATORIO)

**CRITICAL**: Prima di chiudere il piano, TUTTI i learnings devono essere codificati.

#### 9.1. Crea/Aggiorna ADR

Per ogni learning significativo, crea ADR in `docs/adr/`:

```markdown
# ADR {NNNN}: {Titolo Learning}

## Status
Accepted

## Context
[Problema riscontrato durante Piano {ID}]

## Decision
[Soluzione adottata]

## Consequences
- [Positivo]: Previene regressione X
- [Negativo]: Richiede Y in più

## Enforcement
- ESLint rule: `{rule-name}`
- Pre-commit check: `{script}`
```

#### 9.2. Crea Regole ESLint

Per ogni learning che può essere automatizzato:

```javascript
// eslint.config.mjs - aggiungere regola
{
  rules: {
    // ADR-0XXX: {descrizione breve}
    "no-restricted-syntax": ["error", {
      selector: "...",
      message: "ADR-0XXX: {messaggio}"
    }]
  }
}
```

**Tipi di regole**:
- `no-restricted-imports`: Import vietati
- `no-restricted-syntax`: Pattern AST vietati
- Custom rule in `eslint-local-rules/`: Logica complessa

#### 9.3. Thor Valida Codification

**MANDATORY**: Thor deve verificare che le regole esistano e funzionino.

```typescript
Task({
  subagent_type: "thor-quality-assurance-guardian",
  prompt: `Validate Knowledge Codification for Plan {plan_id}.

  LEARNINGS from plan:
  [lista dal LEARNINGS LOG]

  VERIFY:
  1. ADR esiste per ogni learning significativo
  2. ESLint rule esiste per ogni learning automatizzabile
  3. ESLint rule FUNZIONA: crea file di test temporaneo con pattern vietato, verifica che lint fallisca
  4. Pre-commit hook include le nuove regole (se applicabile)
  5. CHANGELOG aggiornato con link a ADR

  TEST COMMAND:
  # Per ogni nuova regola, crea test case
  echo "pattern vietato" > /tmp/test-rule.ts
  npm run lint /tmp/test-rule.ts 2>&1 | grep -q "ADR-XXXX" || echo "RULE NOT WORKING"

  FAIL se: ADR mancante, regola non funziona, learning non codificato`
});
```

#### 9.4. Checklist Pre-Closure

| Check | Verified |
|-------|----------|
| Tutti i learnings hanno ADR (se significativi) | [ ] |
| Tutti i learnings automatizzabili hanno ESLint rule | [ ] |
| Ogni regola ESLint ha test case che FALLISCE | [ ] |
| CHANGELOG aggiornato con sezione "Learnings" | [ ] |
| Thor ha validato codification | [ ] |

**BLOCKED se qualsiasi check è [ ]**

## Anti-Failure (STRICT ENFORCEMENT)
- Never skip approval gate
- Never fake timestamps (only executor sets them)
- Never mark done without F-xx check
- **NEVER bypass Thor** - learned from Plan 085 failure where executors lied
- **NEVER trust executor reports** - always verify with Thor + file reads
- Use db_wave_id (numeric) not wave_code ("W1")
- **Wave completion = Thor PASS** - not just executor reports
- **NEVER close plan without Knowledge Codification** - learnings must be in ADR + ESLint
- **NEVER skip ESLint rule testing** - ogni regola deve avere test case che FALLISCE
- **Learnings not codified = plan NOT done** - Thor blocks closure if missing

## State Transitions
`pending → in_progress → done|blocked|skipped`
Forbidden: `done → pending`, `skipped → done`
