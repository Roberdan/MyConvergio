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
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
~/.claude/scripts/worktree-check.sh "$WORKTREE_PATH"
plan-db.sh create {project_id} "{PlanName}"
```

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
```bash
plan-db.sh add-wave {plan_id} "W1" "Phase"
plan-db.sh add-task {db_wave_id} T1-01 "Desc" P1 feature --model sonnet
```

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

```typescript
Task({
  subagent_type: "thor-quality-assurance-guardian",
  prompt: `Validate Wave {wave} for Plan {plan_id}.
  F-xx requirements: [list]
  VERIFY: code exists, git diff shows changes, no regressions`
});

// Only after Thor passes:
npm run lint && npm run typecheck && npm run build
plan-db.sh validate {plan_id}
```

**Rules**: NEVER skip Thor. NEVER trust executor reports. Thor reads files directly.

### 9. Knowledge Codification (pre-closure)
> See [knowledge-codification.md](./planner-modules/knowledge-codification.md)

Update LEARNINGS LOG → Create ADRs → Create ESLint rules → Thor validates.

## State Transitions
`pending → in_progress → done|blocked|skipped`
Forbidden: `done → pending`, `skipped → done`
