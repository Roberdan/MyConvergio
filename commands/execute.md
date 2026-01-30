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
# CRITICAL: Verify and capture worktree FIRST
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
~/.claude/scripts/worktree-check.sh "$WORKTREE_PATH"

# Get plan_id from argument or current context
PLAN_ID={plan_id}

# Verify plan exists and get details
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, name, status, tasks_done, tasks_total FROM plans WHERE id=$PLAN_ID;"

# If status != 'doing', start it
plan-db.sh start $PLAN_ID
```

Output: "Piano {name} (ID: {plan_id}) - IN FLIGHT - Worktree: {WORKTREE_PATH}"

### Phase 2: Load Tasks

```bash
# Get all pending tasks ordered by wave position, then task_id
# INCLUDES model column - planner specifies haiku/sonnet/opus per task
sqlite3 -json ~/.claude/data/dashboard.db "
  SELECT t.id as db_id, t.task_id, t.title, t.status, t.priority,
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
  model: task.model || 'sonnet',  // Use planner-specified model (haiku|sonnet|opus), default sonnet
  description: `Execute task ${task.task_id}`,
  prompt: `
TASK EXECUTION (Isolated Session - Start Fresh)

Project: ${project_id}
Plan ID: ${plan_id}
Wave: ${task.wave_id} (db_id: ${task.wave_db_id})
Task: ${task.task_id} (db_id: ${task.db_id})
**WORKTREE**: ${WORKTREE_PATH}

Title: ${task.title}
Priority: ${task.priority}

Requirements:
1. **VERIFY WORKTREE FIRST**: Run 'cd ${WORKTREE_PATH}' before ANY operation
2. Mark as in_progress via plan-db.sh
3. Execute the work per task title (ALL files relative to WORKTREE)
4. Test and verify against F-xx criteria
5. Track tokens via POST /api/tokens
6. Mark as done with summary via plan-db.sh
7. Report completion

CRITICAL WORKTREE RULES:
- NEVER operate outside ${WORKTREE_PATH}
- ALL file paths must be relative to worktree or absolute within it
- Run 'pwd' and verify before git operations
- If pwd != WORKTREE, cd to it FIRST

CRITICAL: You are a FRESH session. Do NOT reference previous tasks or files from parent context. Read what you need for THIS task only.
`
});

// 3. MANDATORY: Verify task updated in DB
// Run verification script AFTER every task-executor returns
await Bash({
  command: `~/.claude/scripts/verify-task-update.sh ${task.db_id} done`
});
// If verify fails (exit 1), task-executor forgot to update DB
// → Log warning and force update OR retry task

const status = await checkTaskStatus(task.db_id);
if (status !== 'done') {
  console.log(`⚠️ Task ${task.task_id} NOT updated in DB (status: ${status})`);
  console.log(`→ Executor forgot DB update. Forcing update...`);
  // Force update if task actually completed (based on executor report)
  // OR retry the task if unclear
}

// 4. Check if wave completed
const waveComplete = await checkWaveComplete(task.wave_db_id);
if (waveComplete) {
  console.log(`Wave ${task.wave_id} completed - Running Thor validation`);
  await runThorValidation(plan_id);
}
```

### Phase 4: Wave Completion Check

After each task, check if wave is complete:

```bash
# Check wave completion
WAVE_STATUS=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT tasks_done = tasks_total FROM waves WHERE id=$WAVE_DB_ID;")

if [ "$WAVE_STATUS" = "1" ]; then
  echo "Wave complete - Thor validation required"
  plan-db.sh validate $PLAN_ID
  npm run lint && npm run typecheck && npm run build
fi
```

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
# Execute specific plan
/execute 42

# Execute current plan (if set)
/execute

# Check plan status
plan-db.sh status

# Manual task execution (if needed)
plan-db.sh update-task {id} in_progress
plan-db.sh update-task {id} done "Summary" --tokens N
```
