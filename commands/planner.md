# Planner + Orchestrator

Plan and execute with parallel Claude instances.

## Context (pre-computed)
```
Project: `basename "$(pwd)"`
Branch: `git branch --show-current 2>/dev/null || echo "not a git repo"`
Worktree: `git rev-parse --show-toplevel 2>/dev/null || pwd`
Active plans: `sqlite3 ~/.claude/data/dashboard.db "SELECT id, name, status FROM plans WHERE status IN ('todo','doing') LIMIT 3;" 2>/dev/null || echo "none"`
```

## CRITICAL RULES (NON-NEGOTIABLE)

1. **Task Executor MANDATORY**: Use `Task(subagent_type='task-executor')` for EVERY task
2. **F-xx Requirements**: Extract ALL requirements. Nothing done until ALL verified [x]
3. **User Approval Gate**: BLOCK until explicit "si"/"yes"/"procedi"
4. **Thor Enforcement**: Wave done = Thor passed + build passed
5. **Worktree Isolation**: EVERY task prompt MUST include worktree path
6. **Knowledge Codification**: Errors → ADR + ESLint. Thor validates. See [knowledge-codification.md](./planner-modules/knowledge-codification.md)

## Module References

| Topic | Module |
|-------|--------|
| Parallelization modes | [parallelization-modes.md](./planner-modules/parallelization-modes.md) |
| Model strategy | [model-strategy.md](./planner-modules/model-strategy.md) |
| Knowledge codification | [knowledge-codification.md](./planner-modules/knowledge-codification.md) |

## Workflow

### 1. Setup
```bash
export PATH="$HOME/.claude/scripts:$PATH"
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
~/.claude/scripts/worktree-check.sh "$WORKTREE_PATH"
PROMPT_FILE=".copilot-tracking/prompt-{NNN}.md"
PLAN_MD="~/.claude/plans/{project}/{PlanName}-Main.md"
plan-db.sh create {project_id} "{PlanName}" \
  --source-file "$PROMPT_FILE" \
  --markdown-path "$PLAN_MD"
```

### 1.5 Technical Clarification (MANDATORY before plan)

After reading the prompt file, STOP. Identify technical ambiguities. Use AskUserQuestion.

**Always ask:**
1. **Approach**: "Per F-xx propongo [approccio]. Alternative: [B, C]. Preferenze?"
2. **File scope**: "I file coinvolti: [list]. Altri da toccare? Qualcuno da NON toccare?"
3. **Constraints**: "Breaking changes ok? Nuove dipendenze? Vincoli tecnici?"

**Ask if complex:**
- Test strategy (unit vs integration vs e2e)
- Migration/backwards compatibility needs
- Performance requirements

**Rule**: If writing a task description requires GUESSING about implementation → STOP and ASK.
User answers all questions → proceed to plan creation.

### 2. Plan File (`~/.claude/plans/{project}/{PlanName}-Main.md`)
```markdown
# Piano: {Name}
**Project**: {id} | **Status**: draft | **Worktree**: {path}

## USER REQUEST
> [exact words]

## FUNCTIONAL REQUIREMENTS
| ID | Requirement | Wave | Verified |
|----|-------------|------|----------|
| F-01 | [from user] | W1 | [ ] |

## WAVES
| Task | Description | F-xx | Model | Status |
|------|-------------|------|-------|--------|
| T1-01 | [task] | F-01 | sonnet | pending |

## LEARNINGS LOG
| Wave | Issue | Root Cause | Resolution | Preventive Rule |
|------|-------|------------|------------|-----------------|
```

### 3. Register in DB

**MANDATORY**: For EVERY task, extract acceptance criteria from the prompt file and set `--test-criteria`. The `--description` MUST contain what to do, which files to touch, and the F-xx reference.

```bash
plan-db.sh add-wave {plan_id} "W1" "Phase"
plan-db.sh add-task {db_wave_id} T1-01 "Fix i18n loading" P1 feature \
  --model sonnet \
  --description "Change Object.assign to namespace-scoped in src/i18n/request.ts. See F-03." \
  --test-criteria '{"verify":["npm run i18n:check passes","0 ESLint i18n warnings","build succeeds"]}'
```

Rules:
- `--description`: what + which files + F-xx ref (one sentence)
- `--test-criteria`: JSON array of verifiable checks from prompt acceptance criteria
- Missing test_criteria = Thor cannot validate = pipeline broken

### 4. User Approval (MANDATORY STOP)
Present F-xx list → User says "si"/"yes" → Proceed

### 5. Parallelization Mode Selection
> See [parallelization-modes.md](./planner-modules/parallelization-modes.md)

Ask via AskUserQuestion: Standard (3 parallel) vs Max (unlimited, Opus).

### 6. Start Execution
```bash
plan-db.sh start {plan_id}  # MANDATORY: moves to IN FLIGHT
```

### 7. Execute Tasks
Use `/execute {plan_id}` for automated execution.

Manual fallback:
```typescript
await Task({
  subagent_type: "task-executor",
  model: task.model,  // From DB
  prompt: `Project: {id} | Plan: {plan_id} | Task: T1-01
  **WORKTREE**: {absolute_worktree_path}
  F-xx: [acceptance criteria]`
});
```

### 8. Thor Validation (per wave) - MANDATORY

```
Task(
  subagent_type="thor-quality-assurance-guardian",
  model="sonnet",
  description="Thor validates Wave WX",
  prompt="THOR VALIDATION SESSION
  Plan ID: {plan_id}
  Wave: {wave_id}
  Plan Markdown: {PLAN_MD}
  Source Prompt: {PROMPT_FILE}
  WORKTREE: {WORKTREE_PATH}
  F-xx Requirements: [list from plan markdown]

  Validate this wave. Read plan markdown for F-xx and task specs."
)
```

After Thor PASS:
```bash
plan-db.sh validate {plan_id}
npm run ci:summary
```

**Rules**: NEVER skip Thor. NEVER trust executor reports. Thor reads files directly.

### 9. Knowledge Codification (pre-closure)
> See [knowledge-codification.md](./planner-modules/knowledge-codification.md)

Update LEARNINGS LOG → Create ADRs → Create ESLint rules → Thor validates.

## State Transitions
`pending → in_progress → done|blocked|skipped`
Forbidden: `done → pending`, `skipped → done`
