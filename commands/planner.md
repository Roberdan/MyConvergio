# Planner + Orchestrator

Plan and execute with parallel Claude instances (default: 3, max: unlimited with Opus orchestration).

## Context (pre-computed)
```
Project: `basename "$(pwd)"`
Branch: `git branch --show-current 2>/dev/null || echo "not a git repo"`
Git status: `git status --short 2>/dev/null | head -5 || echo "n/a"`
Active plans: `sqlite3 ~/.claude/data/dashboard.db "SELECT id, name, status FROM plans WHERE status IN ('todo','doing') LIMIT 3;" 2>/dev/null || echo "none"`
```

## CRITICAL RULES (NON-NEGOTIABLE)

1. **Task Executor MANDATORY**: Planner CANNOT execute directly. Use `Task(subagent_type='task-executor')` for EVERY task
2. **F-xx Requirements**: Extract ALL user requirements as F-xx. Nothing done until ALL F-xx verified [x]
3. **User Approval Gate**: BLOCK execution until explicit "si"/"yes"/"procedi"
4. **Thor Enforcement**: Wave done = Thor passed + build passed

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
~/.claude/scripts/register-project.sh "$(pwd)" --name "Project"
~/.claude/scripts/plan-db.sh create {project_id} "{PlanName}"
```

### 2. Plan File (`~/.claude/plans/{project_id}/{PlanName}-Main.md`)
```markdown
# Piano: {Name}
**Project**: {id} | **Status**: draft

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
```

### 3. Register in DB
```bash
plan-db.sh add-wave {plan_id} "W1" "Phase"  # Returns db_wave_id
plan-db.sh add-task {db_wave_id} T1-01 "Desc" P1 feature
```

### 4. User Approval (MANDATORY STOP)
Present F-xx list → User says "si"/"yes" → Proceed

### 4.5. Parallelization Mode Selection (MANDATORY)

**AFTER plan approval, BEFORE execution starts**, ask user:

```typescript
await AskUserQuestion({
  questions: [{
    question: "Quale modalità di esecuzione preferisci?",
    header: "Parallelization",
    multiSelect: false,
    options: [
      {
        label: "Standard (3 task paralleli)",
        description: "Bilanciata. Costi moderati. Sonnet coordination. Velocità normale."
      },
      {
        label: "Massima Parallelizzazione (Recommended)",
        description: "Veloce. Costi elevati. Opus coordination. Tutti i task indipendenti in parallelo. 3-5x più veloce."
      }
    ]
  }]
});
```

**Implementation**:
- If user selects "Standard": `PARALLEL_MODE=standard`, `MAX_CONCURRENT=3`
- If user selects "Massima": `PARALLEL_MODE=max`, `MAX_CONCURRENT=unlimited`, **upgrade self to Opus**

Store mode (choose one method):

**Option A: Environment variable (simple)**:
```bash
export PLAN_${PLAN_ID}_PARALLEL_MODE="$PARALLEL_MODE"
export PLAN_${PLAN_ID}_MAX_CONCURRENT="$MAX_CONCURRENT"
```

**Option B: File-based (persistent)**:
```bash
echo "$PARALLEL_MODE" > ~/.claude/data/plan-${PLAN_ID}-mode.txt
```

**Option C: Database (recommended)**:
```bash
sqlite3 ~/.claude/data/dashboard.db \
  "UPDATE plans SET parallel_mode='$PARALLEL_MODE' WHERE id=$PLAN_ID;"
```

### 5. Start Execution (AUTO → IN FLIGHT)
```bash
# MANDATORY: Call start BEFORE executing any task
# This moves plan to "IN FLIGHT" in dashboard
plan-db.sh start {plan_id}
```
Plan status: `todo` → `doing` (visible in Mission Pipeline as IN FLIGHT)

### 6. Execute Tasks

**Use `/execute {plan_id}`** for automated execution of all tasks.

#### Standard Mode Execution
```typescript
// Load pending tasks
const tasks = loadPendingTasks(plan_id);

// Execute in batches of 3
for (let i = 0; i < tasks.length; i += 3) {
  const batch = tasks.slice(i, i + 3);

  // Launch up to 3 task-executors in parallel
  await Promise.all(batch.map(task =>
    Task({
      subagent_type: "task-executor",
      model: task.priority === 'P0' ? 'sonnet' : 'haiku',
      prompt: `...`
    })
  ));

  // Check if wave completed after batch
  if (waveCompleted) runThorValidation();
}
```

#### Max Parallel Mode Execution (Opus Coordinator)
```typescript
// CRITICAL: Coordinator MUST be Opus for this mode
// Upgrade model if not already Opus

// Load ALL pending tasks
const tasks = loadPendingTasks(plan_id);

// Group by wave
const waves = groupTasksByWave(tasks);

for (const wave of waves) {
  // Launch ALL independent tasks in wave simultaneously
  const independentTasks = wave.tasks.filter(t => !hasDependencies(t));

  console.log(`Launching ${independentTasks.length} tasks in parallel...`);

  // NO LIMIT - all tasks run concurrently
  await Promise.all(independentTasks.map(task =>
    Task({
      subagent_type: "task-executor",
      model: task.priority === 'P0' ? 'sonnet' : 'haiku',
      description: `Execute ${task.task_id}`,
      prompt: `...`
    })
  ));

  // Execute dependent tasks sequentially
  const dependentTasks = wave.tasks.filter(t => hasDependencies(t));
  for (const task of dependentTasks) {
    await Task({ subagent_type: "task-executor", ... });
  }

  // Thor validation after wave
  await runThorValidation(plan_id);
}
```

**Token/Cost Comparison**:
- Standard: ~30K tokens/task × 3 parallel = ~90K tokens/batch
- Max Parallel: ~30K tokens/task × N parallel = ~30K×N tokens/wave
- **Opus coordination overhead**: +50K tokens vs Sonnet
- **Time saved**: 3-5x faster (worth the cost for urgent work)

Manual fallback (single task):
```typescript
await Task({
  subagent_type: "task-executor",
  prompt: `Project: {id} | Plan: {plan_id} | Task: T1-01 (db_id: {id})
  F-xx: [acceptance criteria]`
});
```

### 7. Thor Validation (per wave)
```bash
plan-db.sh validate {plan_id}
npm run lint && npm run typecheck && npm run build
```

## Anti-Failure
- Never skip approval gate
- Never fake timestamps (only executor sets them)
- Never mark done without F-xx check
- Never bypass Thor
- Use db_wave_id (numeric) not wave_code ("W1")

## State Transitions
`pending → in_progress → done|blocked|skipped`
Forbidden: `done → pending`, `skipped → done`
