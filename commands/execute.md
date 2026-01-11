# Plan Executor

Automated execution of plan tasks via task-executor subagent.

## Context (pre-computed)
```
Project: `basename "$(pwd)"`
Branch: `git branch --show-current 2>/dev/null || echo "not a git repo"`
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

## Workflow

### Phase 1: Initialize

```bash
# Get plan_id from argument or current context
PLAN_ID={plan_id}

# Verify plan exists and get details
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, name, status, tasks_done, tasks_total FROM plans WHERE id=$PLAN_ID;"

# If status != 'doing', start it
plan-db.sh start $PLAN_ID
```

Output: "Piano {name} (ID: {plan_id}) - IN FLIGHT"

### Phase 2: Load Tasks

```bash
# Get all pending tasks ordered by wave position, then task_id
sqlite3 -json ~/.claude/data/dashboard.db "
  SELECT t.id as db_id, t.task_id, t.title, t.status, t.priority,
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

// 2. Launch task-executor subagent
await Task({
  subagent_type: "task-executor",
  model: task.priority === 'P0' ? 'sonnet' : 'haiku',
  prompt: `
Project: ${project_id}
Plan ID: ${plan_id}
Wave: ${task.wave_id} (db_id: ${task.wave_db_id})
Task: ${task.task_id} (db_id: ${task.db_id})

Title: ${task.title}
Priority: ${task.priority}

Execute this task:
1. Mark as in_progress
2. Do the work
3. Verify against F-xx criteria
4. Mark as done with summary
5. Report completion
`
});

// 3. Verify task completed
const status = await checkTaskStatus(task.db_id);
if (status !== 'done') {
  console.log(`Task ${task.task_id} not completed: ${status}`);
  // Ask user: continue or stop?
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

### Task Failed/Blocked

```
Task ${task_id} failed or blocked.
Status: ${status}
Notes: ${notes}

Options:
1. Skip and continue (mark skipped)
2. Retry task
3. Stop execution

Choose [1/2/3]:
```

### Build Failed

```
Thor validation FAILED after wave ${wave_id}

Errors:
${build_errors}

Options:
1. Fix and retry wave
2. Continue anyway (NOT RECOMMENDED)
3. Stop execution

Choose [1/2/3]:
```

## Output Format

During execution, show progress:

```
=== EXECUTING PLAN: {name} (ID: {plan_id}) ===

[1/8] T1-01: Setup project structure
      Status: DONE (2,345 tokens)

[2/8] T1-02: Implement data models
      Status: DONE (5,678 tokens)

[3/8] T1-03: Create API endpoints
      Status: IN PROGRESS...

--- Wave W1 Complete ---
Thor: PASS | Build: PASS

[4/8] T2-01: Frontend components
      Status: PENDING

...
```

## Completion Report

```
=== PLAN EXECUTION COMPLETE ===

Plan: {name} (ID: {plan_id})
Status: DONE

Tasks: {done}/{total} completed
Waves: {waves_done}/{waves_total} validated
Tokens: {total_tokens} used
Time: {duration}

Thor Validation: PASS
Build Status: PASS

Awaiting user approval to close plan.
```

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
