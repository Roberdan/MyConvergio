# Planner + Orchestrator

Plan and execute with parallel Claude instances (max 3).

## Quick Commands
`mostra stato`/`dashboard` → Launch dashboard | `pianifica X` → Create plan | `esegui piano` → Execute

## CRITICAL: Task Executor is MANDATORY

**ZERO TOLERANCE POLICY**:
- ❌ Planner CANNOT execute tasks directly
- ✅ Planner MUST use Task tool with subagent_type='task-executor'
- ❌ NO task marked "done" without executor
- ❌ NO timestamps/tokens faked by planner

**Every task execution = executor invocation. NO EXCEPTIONS.**

---

## CRITICAL: Functional Requirements

**EVERY plan MUST include user's original instructions as Functional Requirements (F-xx)**

Before ANY execution:
1. Extract EVERY user requirement into F-xx entries
2. Define acceptance criteria for EACH requirement
3. Map F-xx to specific tasks
4. User approves F-xx list before execution starts

**NOTHING IS DONE UNTIL ALL F-xx ARE [x] VERIFIED**

---

## Workflow (MUST FOLLOW)

### Step 1: Register Project (if new)
```bash
~/.claude/scripts/register-project.sh "$(pwd)" --name "Project Name"
```

### Step 2: Create Plan in DB
```bash
~/.claude/scripts/plan-db.sh create {project_id} "{PlanName}"
```

### Step 3: Write Plan with MANDATORY Sections
**Location**: `~/.claude/plans/{project_id}/{PlanName}-Main.md`

**REQUIRED sections:**
1. User's original request (verbatim)
2. Functional Requirements table (F-xx)
3. Phases overview with task counts
4. Verification checkpoints

### Step 4: Register Waves
```bash
~/.claude/scripts/plan-db.sh add-wave {plan_id} "W1" "Phase Name"
# Returns: {db_wave_id} - USE THIS for add-task commands
```

### Step 5: Add Tasks (linked to F-xx)
```bash
~/.claude/scripts/plan-db.sh add-task {db_wave_id} T1-01 "Task description" P1 feature
```

**⚠️ CRITICAL**: Use numeric `db_wave_id` from Step 4 output, NOT "W1"

### Step 6: User Approval Gate (MANDATORY STOP)

**⛔ EXECUTION IS BLOCKED UNTIL USER EXPLICITLY APPROVES**

Present to user:
- F-xx list with acceptance criteria
- Wave/task breakdown
- Estimated scope

**BLOCKING CONDITIONS:**
- User hasn't responded "sì" / "yes" / "ok" / "procedi"
- User says something is missing → add F-xx, re-present
- User asks questions → answer, then re-present

**FORBIDDEN BEFORE APPROVAL:**
- ❌ Starting any task execution
- ❌ Creating task entries in database
- ❌ Invoking task-executor
- ❌ Modifying any code

### Step 7: Execute Tasks with Task Executor

**CRITICAL**: Use Task tool with subagent_type='task-executor' for EVERY task.

```typescript
await Task({
  subagent_type: "task-executor",
  prompt: `Execute task:
  Project: {project_id} | Plan: {plan_id}
  Wave: W1 (db_id: {db_wave_id})
  Task: T1-01 (db_id: {db_task_id})
  F-xx requirement: [acceptance criteria]
  `
});
```

**Executor will**:
- Set started_at/completed_at via plan-db.sh
- Track and record token usage
- Verify F-xx criteria before marking done

### Step 8: F-xx Validation (After Each Task)

```bash
~/.claude/scripts/plan-db.sh validate-fxx {plan_id}
```

If pending requirements → task NOT done, go back to executor.

### Step 9: Thor Wave Verification

**AFTER EACH WAVE COMPLETION:**
```bash
~/.claude/scripts/plan-db.sh validate {plan_id}
npm run lint && npm run typecheck && npm run build
~/.claude/scripts/plan-db.sh update-wave {wave_id} done
```

**WAVE CANNOT BE MARKED DONE WITHOUT:**
- All tasks in wave completed
- Thor validation passed
- Build/lint/typecheck passed

### Step 10: Final Thor Verification

```bash
~/.claude/scripts/plan-db.sh validate {plan_id}
```

Thor final checklist:
1. ALL F-xx verified with evidence
2. Database integrity (counters synced)
3. Build passes
4. File sizes ≤250 lines

---

**See also**: `planner-rules.md` for templates, integrity rules, model strategy
