# Planner + Orchestrator

Plan and execute with parallel Claude instances (max 3).

## CRITICAL RULES (NON-NEGOTIABLE)

1. **Task Executor MANDATORY**: Planner CANNOT execute directly. Use `Task(subagent_type='task-executor')` for EVERY task
2. **F-xx Requirements**: Extract ALL user requirements as F-xx. Nothing done until ALL F-xx verified [x]
3. **User Approval Gate**: BLOCK execution until explicit "si"/"yes"/"procedi"
4. **Thor Enforcement**: Wave done = Thor passed + build passed

## Model Strategy

| Phase | Model | Escalation |
|-------|-------|------------|
| Planning | opus | - |
| Execution | haiku | → sonnet (>3 files, complex) |
| Validation | sonnet | - |

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

### 5. Start Execution (AUTO → IN FLIGHT)
```bash
# MANDATORY: Call start BEFORE executing any task
# This moves plan to "IN FLIGHT" in dashboard
plan-db.sh start {plan_id}
```
Plan status: `todo` → `doing` (visible in Mission Pipeline as IN FLIGHT)

### 6. Execute Tasks
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
