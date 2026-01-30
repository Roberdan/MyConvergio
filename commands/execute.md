# Plan Executor

Automated execution of plan tasks via task-executor subagent.

## Context (pre-computed)
```
Project: `basename "$(pwd)"`
Branch: `git branch --show-current 2>/dev/null || echo "not a git repo"`
Worktree: `git rev-parse --show-toplevel 2>/dev/null || pwd`
Uncommitted: `git status --short 2>/dev/null | wc -l | tr -d ' '` files
Active plans: `sqlite3 ~/.claude/data/dashboard.db "SELECT id, name, status, tasks_done||'/'||tasks_total as progress FROM plans WHERE status IN ('todo','doing') ORDER BY updated_at DESC LIMIT 3;" 2>/dev/null || echo "none"`
```

## Activation
When message contains `/execute {plan_id}` or `/execute` (uses current plan).

## CRITICAL RULES

1. **NEVER execute without plan_id** - Must have valid plan
2. **NEVER skip start** - Plan must be IN FLIGHT before execution
3. **NEVER skip tasks** - Execute ALL pending tasks in order
4. **NEVER skip Thor** - Validate after each wave completion
5. **WORKTREE ISOLATION** - Verify worktree BEFORE execution, pass to EVERY task-executor

## Workflow

### Phase 1: Initialize

```bash
# CRITICAL: Ensure scripts are in PATH for this session
export PATH="$HOME/.claude/scripts:$PATH"

# CRITICAL: Verify and capture worktree FIRST
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
~/.claude/scripts/worktree-check.sh "$WORKTREE_PATH"

# Get plan_id from argument or current context
PLAN_ID={plan_id}

# Verify plan exists and get details + plan markdown path
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, name, status, tasks_done, tasks_total, markdown_path, source_file FROM plans WHERE id=$PLAN_ID;"

# If status != 'doing', start it
plan-db.sh start $PLAN_ID

# CRITICAL: Read plan markdown + source prompt paths
PLAN_MARKDOWN_PATH=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT markdown_path FROM plans WHERE id=$PLAN_ID;")
SOURCE_FILE=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT source_file FROM plans WHERE id=$PLAN_ID;")
if [ -n "$PLAN_MARKDOWN_PATH" ] && [ -f "$PLAN_MARKDOWN_PATH" ]; then
  PLAN_CONTENT=$(cat "$PLAN_MARKDOWN_PATH")
else
  echo "WARNING: No plan markdown found. Executor will work with task titles only."
  PLAN_CONTENT=""
fi
```

```bash
# MANDATORY: Readiness gate (BLOCKS if metadata missing)
plan-db.sh check-readiness $PLAN_ID
# If exit 1: STOP. Fix missing metadata before proceeding.
```

Output: "Piano {name} (ID: {plan_id}) - IN FLIGHT - Worktree: {WORKTREE_PATH}"

### Phase 2: Load Tasks

```bash
# Get all pending tasks ordered by wave position, then task_id
# INCLUDES model, description, test_criteria columns
sqlite3 -json ~/.claude/data/dashboard.db "
  SELECT t.id as db_id, t.task_id, t.title, t.description,
         t.status, t.priority, t.test_criteria,
         t.model,  -- haiku|sonnet|opus (from planner)
         w.id as wave_db_id, w.wave_id, w.name as wave_name
  FROM tasks t
  JOIN waves w ON t.wave_id_fk = w.id
  WHERE t.plan_id = $PLAN_ID AND t.status = 'pending'
  ORDER BY w.position, t.task_id;
"
```

Output: List of tasks to execute

### Phase 3: Execute Loop

For each pending task:

```typescript
// 1. Announce task
console.log(`Executing: ${task.task_id} - ${task.title}`);

// 2. Launch task-executor subagent (ISOLATED SESSION)
// Model comes from planner (stored in DB) - NOT derived from priority
await Task({
  subagent_type: "task-executor",
  model: task.model || 'sonnet',
  description: `Execute task ${task.task_id}`,
  prompt: `
TASK EXECUTION (Isolated Session - Start Fresh)

Project: ${project_id}
Plan ID: ${plan_id}
Wave: ${task.wave_id} (db_id: ${task.wave_db_id})
Task: ${task.task_id} (db_id: ${task.db_id})
**WORKTREE**: ${WORKTREE_PATH}

Title: ${task.title}
Description: ${task.description || task.title}
Priority: ${task.priority}
Test Criteria: ${task.test_criteria}  // MUST exist - check-readiness enforces this

## PLAN CONTEXT (from planner analysis)
${PLAN_CONTENT}

Requirements:
1. **PATH SETUP**: Run 'export PATH="$HOME/.claude/scripts:$PATH"' FIRST
2. **VERIFY WORKTREE FIRST**: Run 'cd ${WORKTREE_PATH}' before ANY operation
3. **READ THE PLAN CONTEXT ABOVE** - it contains root cause analysis, F-xx requirements, and detailed task specs
4. Mark as in_progress via plan-db.sh
4. Execute the work per task title AND plan context
5. Test and verify against F-xx criteria
6. Track tokens via POST /api/tokens
7. Mark as done with summary via plan-db.sh
8. Report completion

CRITICAL WORKTREE RULES:
- NEVER operate outside ${WORKTREE_PATH}
- ALL file paths must be relative to worktree or absolute within it
- Run 'pwd' and verify before git operations
- If pwd != WORKTREE, cd to it FIRST

CRITICAL: You are a FRESH session. Do NOT reference previous tasks or files from parent context. Read what you need for THIS task only. But DO use the PLAN CONTEXT above for understanding what to do and why.
`
});

// 3. Verify task completed in DB
Bash(`~/.claude/scripts/verify-task-update.sh ${task.db_id} done`);
```

**Task retry loop** (executor owns this):
1. After task-executor returns, run `verify-task-update.sh`
2. If task NOT done: re-launch task-executor with error context (max 2 retries)
3. After 2 retries still failing: mark task `blocked`, log reason, ASK USER via AskUserQuestion
4. User can: retry with different approach, skip task, or stop execution

### Phase 4: Wave Completion + Thor Validation

After each task, check wave completion and launch Thor:

```bash
# 1. Check wave completion
WAVE_STATUS=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT tasks_done = tasks_total FROM waves WHERE id=$WAVE_DB_ID;")
```

If `WAVE_STATUS = 1` (wave complete), launch Thor as subagent:

```
Task(
  subagent_type="thor-quality-assurance-guardian",
  model="sonnet",
  description="Thor validates Wave WX",
  prompt="THOR VALIDATION SESSION
  FIRST: Run 'export PATH=$HOME/.claude/scripts:$PATH' before any command.
  Plan ID: {PLAN_ID}
  Wave: {wave_id} (db_id: {WAVE_DB_ID})
  Plan Markdown: {PLAN_MARKDOWN_PATH}
  Source Prompt: {SOURCE_FILE}
  WORKTREE: {WORKTREE_PATH}
  F-xx Requirements: [extract from plan markdown]

  Validate this wave. Read the plan markdown for F-xx and task specs."
)
```

**Thor review loop** (executor owns this, max 3 rounds):

**Round N - Thor PASS:**
```bash
plan-db.sh validate $PLAN_ID
npm run ci:summary
```
Proceed to next wave.

**Round N - Thor REJECT:**
Thor returns structured rejection (see Thor REJECT format below).
1. Parse rejection: which tasks failed, what evidence Thor wants
2. Launch targeted task-executor for EACH failed item:
   ```
   Task(subagent_type="task-executor", prompt="
     FIX REQUEST from Thor (Round N/3):
     Thor said: {rejection_reason}
     Evidence needed: {what_thor_wants}
     Fix THIS specific issue. Then verify: {test_criteria}")
   ```
3. After fixes, re-launch Thor (same prompt + "Round N+1, previous issues: ...")
4. Thor re-evaluates with fresh file reads

**Round 3 - Thor still REJECT:**
STOP. Present to user via AskUserQuestion:
- Thor's specific objections
- What was attempted in 3 rounds
- Options: override Thor, fix manually, abandon wave

### Phase 5: Plan Completion

When all tasks done:

```bash
# Verify all tasks complete
REMAINING=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT COUNT(*) FROM tasks WHERE plan_id=$PLAN_ID AND status='pending';")

if [ "$REMAINING" = "0" ]; then
  echo "All tasks complete"

  # Final Thor validation
  plan-db.sh validate $PLAN_ID

  # Mark plan complete (requires tasks done + Thor validation)
  plan-db.sh complete $PLAN_ID

  echo "Piano completato - In attesa di approvazione utente"
fi
```

## Error Handling
> See [error-handling.md](./execute-modules/error-handling.md) for failure scenarios and recovery strategies.

## Output Format

Progress: `[N/total] task_id: title → Status: DONE/IN PROGRESS (tokens)`
Wave complete: `--- Wave WX Complete --- Thor: PASS | Build: PASS`

## Completion Report

`=== PLAN COMPLETE === Tasks: done/total | Tokens: N | Thor: PASS | Awaiting user approval`

## Quick Reference

```bash
/execute 42                                       # Specific plan
/execute                                          # Current plan
plan-db.sh status                                 # Check status
plan-db.sh update-task {id} in_progress           # Manual start
plan-db.sh update-task {id} done "Summary" --tokens N  # Manual complete
```
