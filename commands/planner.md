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

**If dashboard shows tasks with**:
- started_at = NULL
- completed_at = NULL
- tokens = 0 or NULL
- PENDING VALIDATION
→ **EXECUTOR WAS NOT USED** → UNACCEPTABLE

**Every task execution = executor invocation. NO EXCEPTIONS.**

---

## CRITICAL: Functional Requirements

**EVERY plan MUST include user's original instructions as Functional Requirements (F-xx)**

Before ANY execution:
1. Extract EVERY user requirement into F-xx entries
2. Define acceptance criteria for EACH requirement
3. Map F-xx to specific tasks
4. User approves F-xx list before execution starts

```markdown
## FUNCTIONAL REQUIREMENTS (from user instructions)
| ID | User Instruction | Acceptance Criteria | Tasks | Verified |
| F-01 | "[exact user words]" | [how to verify it works] | T1-01, T1-02 | [ ] |
| F-02 | "[exact user words]" | [how to verify it works] | T2-01 | [ ] |
```

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
# Returns: plan_id
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
# Parameters: db_wave_id (numeric), task_id (T-code), title, priority, type
# Each task MUST reference which F-xx it satisfies in title/notes
```

**⚠️ CRITICAL**: Use numeric `db_wave_id` from Step 4 output, NOT "W1"

### Step 6: User Approval Gate (MANDATORY STOP)

**⛔ EXECUTION IS BLOCKED UNTIL USER EXPLICITLY APPROVES**

Present to user for approval:
```markdown
## APPROVAL REQUEST

### Functional Requirements Extracted:
| ID | From Your Words | Acceptance Test | Status |
|----|-----------------|-----------------|--------|
| F-01 | "[exact quote]" | [how I'll verify] | Pending |
| F-02 | "[exact quote]" | [how I'll verify] | Pending |

### Execution Plan:
- Wave 1: [name] - [X tasks]
- Wave 2: [name] - [Y tasks]

### Estimated Scope:
- Files to modify: ~N
- Files to create: ~M
- Total tasks: Z

---

**Ho catturato tutto? Manca qualcosa?**
**Posso procedere con l'esecuzione? (sì/no)**
```

**BLOCKING CONDITIONS - CANNOT PROCEED IF:**
- [ ] User hasn't responded "sì" / "yes" / "ok" / "procedi"
- [ ] User says something is missing → add F-xx, re-present
- [ ] User says requirement is wrong → correct, re-present
- [ ] User asks questions → answer, then re-present approval request

**FORBIDDEN ACTIONS BEFORE APPROVAL:**
- ❌ Starting any task execution
- ❌ Creating task entries in database
- ❌ Invoking task-executor
- ❌ Modifying any code
- ❌ Assuming approval from silence

**APPROVAL = GATE OPEN:**
Only after explicit user approval ("sì", "yes", "ok", "procedi", "vai", "esegui"):
1. Record approval timestamp in plan file
2. Proceed to Step 7 (execution)

---

### Step 7: Execute Tasks with Task Executor

**CRITICAL**: Use Task tool with subagent_type='task-executor' for EVERY task.

**Before executing, get numeric task ID:**
```bash
DB_TASK_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM tasks WHERE wave_id='W1' AND task_id='T1-01';")
echo "Numeric task ID: $DB_TASK_ID"
```

**For EACH task in wave:**
```typescript
// For EACH task in wave:
await Task({
  subagent_type: "task-executor",
  prompt: `Execute task from plan:

  Project: {project_id}
  Plan ID: {plan_id}
  Wave: W1 (db_id: {db_wave_id})
  Task: T1-01 (db_id: {db_task_id})

  Task details: [copy from plan file]
  F-xx requirement: [copy acceptance criteria]

  REQUIREMENTS:
  1. Call: ~/.claude/scripts/plan-db.sh update-task {db_task_id} in_progress
  2. Implement solution
  3. Test solution
  4. Call: ~/.claude/scripts/plan-db.sh update-task {db_task_id} done "Summary"
  5. Record token usage
  6. Return completion status with metadata
  `
});
```

**Executor will**:
- Set started_at/completed_at automatically via plan-db.sh
- Track and record token usage
- Report completion status
- Log all work in task notes
- **Verify F-xx criteria before marking done**

**After executor returns:**
1. Check executor's F-xx verification report
2. If F-xx PASS → proceed to next task
3. If F-xx FAIL → DO NOT proceed, fix first

### Step 8: F-xx Validation (After Each Task)

**MANDATORY after each task completes:**
```bash
# Validate F-xx status in plan markdown
~/.claude/scripts/plan-db.sh validate-fxx {plan_id}
```

**If validate-fxx reports pending requirements:**
- Task that should have verified F-xx is NOT actually done
- Go back to executor, complete the verification
- Only proceed when validate-fxx passes

### Step 9: Thor Wave Verification

**AFTER EACH WAVE COMPLETION:**
```bash
# 1. Run Thor verification
~/.claude/scripts/plan-db.sh validate {plan_id}

# 2. Run project build/tests
npm run lint && npm run typecheck && npm run build

# 3. Update wave status ONLY if passes
~/.claude/scripts/plan-db.sh update-wave {wave_id} done
```

**WAVE CANNOT BE MARKED DONE WITHOUT:**
- [ ] All tasks in wave completed
- [ ] Thor validation passed
- [ ] Build/lint/typecheck passed
- [ ] Relevant F-xx manually tested

### Step 10: Final Thor Verification
```bash
~/.claude/scripts/plan-db.sh validate {plan_id}
```

Thor final checklist:
1. **ALL F-xx verified**: Each has [x] with evidence
2. **Database integrity**: Counters synced, no orphans
3. **Build passes**: `npm run lint && npm run typecheck && npm run build`
4. **Tests pass**: `npm run test` or documented skip reason
5. **File sizes**: No file > 300 lines without exception

---

## Thor Enforcement Rules

### Thor MUST be called:
- After EVERY wave completion (not optional)
- Before marking ANY wave as "done"
- Before marking plan as "complete"
- When user asks "è finito?" / "is it done?"

### Thor verification output format:
```
WAVE W1 VERIFICATION
====================
[ ] F-01: User can login → TESTED: works
[ ] F-02: Dashboard loads → TESTED: works
[!] F-03: Export button → NOT TESTED (no test written)

BUILD: npm run build → PASS
LINT: npm run lint → PASS (2 warnings)
TESTS: npm run test → 12/12 passed

VERDICT: BLOCKED - F-03 not verified
```

### Blocked = Cannot Proceed
If Thor reports BLOCKED:
1. Fix the issue
2. Re-run Thor
3. Only proceed when PASS

---

## Plan File Template

```markdown
# {PlanName}

**Created**: DD Mese YYYY, HH:MM CET
**Project**: {project_id} | **Plan ID**: {plan_id}

## USER REQUEST (verbatim)
> [Copy exact user instructions here]

## FUNCTIONAL REQUIREMENTS
| ID | From User | Acceptance Criteria | Tasks | Verified |
|----|-----------|---------------------|-------|----------|
| F-01 | "[user words]" | [test method] | T1-01 | [ ] |

## PHASES
| Wave | Tasks | Thor Check | Status |
| W1 | 12 | Required | [ ] |
| W2 | 14 | Required | [ ] |

## VERIFICATION LOG
| Timestamp | Wave | Thor Result | Notes |
|-----------|------|-------------|-------|
| | W1 | | |
```

---

## Anti-Failure Rules

1. **No phantom verification**: "Thor verified" means Thor agent RAN and PASSED
2. **No skipping F-xx**: Every user requirement tracked and verified
3. **No batch completion**: Mark done ONE task/wave at a time, after verification
4. **No assumptions**: If unsure, test it
5. **No silent failures**: All errors logged and reported

---

## Plan Integrity Rules (NON-NEGOTIABLE)

### Every Task is Mandatory
- NO "optional" tasks in plans
- NO "nice-to-have" items
- NO "if time permits" tasks
- Every task created = task that MUST be executed

### Full Plan Execution
- Plan requested for full execution → 100% completion required
- No unilateral task skipping by agents
- No scope negotiation during execution
- Incomplete plan = FAILED plan

### No "Non-Blocking Missing"
- If planner identifies something missing → it's BLOCKING
- Forbidden: "missing but we can proceed"
- Missing item = new task to add, or blocker to resolve

### Thor Dispute Awareness
When Thor contests a plan or task:
1. Planner can provide evidence (max 3 iterations)
2. After 3 rounds: Thor's decision is final
3. Planner must adjust plan per Thor's verdict
4. No bypassing Thor's authority

## DB Schema Reference
```sql
-- tasks: project_id (TEXT), wave_id (TEXT), task_id (TEXT), status
-- waves: project_id (TEXT), wave_id (TEXT), plan_id (INT), status
-- Tasks does NOT have plan_id! Use project_id + wave_id
```

## Model Strategy (Cost Optimization)

| Phase | Model | Rationale |
|-------|-------|-----------|
| /prompt | parent context | Translate user request |
| /planner | opus | High-quality planning, architecture decisions |
| task-executor | haiku | Simple, well-documented tasks (cost efficient) |
| thor | sonnet | Quality validation requires balanced reasoning |

**Key Principle**: Opus creates detailed, well-documented task specs so haiku can execute efficiently.
