# Plan Executor

Automated execution of plan tasks via task-executor subagent.

## Activation

When message contains `/execute {plan_id}` or `/execute` (uses current plan).

## CRITICAL RULES

1. **NEVER execute without plan_id** - Must have valid plan
2. **NEVER skip start** - Plan must be IN FLIGHT before execution
3. **NEVER skip tasks** - Execute ALL pending tasks in order
4. **NEVER skip Thor** - Validate after each wave completion
5. **WORKTREE ISOLATION** - Pass worktree path to EVERY task-executor

## Workflow

### Phase 1: Initialize (single call)

```bash
export PATH="$HOME/.claude/scripts:$PATH"
PLAN_ID={plan_id}

# ONE call gets everything: plan info, all tasks, framework, expanded paths
CTX=$(plan-db.sh get-context $PLAN_ID)
echo "$CTX" | jq .

# Extract key values
WORKTREE_PATH=$(echo "$CTX" | jq -r '.worktree_path')
PLAN_MARKDOWN_PATH=$(echo "$CTX" | jq -r '.markdown_path')
SOURCE_FILE=$(echo "$CTX" | jq -r '.source_file')
FRAMEWORK=$(echo "$CTX" | jq -r '.framework')
PLAN_STATUS=$(echo "$CTX" | jq -r '.status')

# Switch to worktree
cd "$WORKTREE_PATH" && pwd

# Start plan if needed
if [ "$PLAN_STATUS" != "doing" ]; then
  plan-db.sh start $PLAN_ID
fi

# Readiness gate
plan-db.sh check-readiness $PLAN_ID

# Read plan markdown for context (pass to tasks)
PLAN_CONTENT=""
if [ -n "$PLAN_MARKDOWN_PATH" ] && [ -f "$PLAN_MARKDOWN_PATH" ]; then
  PLAN_CONTENT=$(cat "$PLAN_MARKDOWN_PATH")
fi
```

Output: "Piano {name} (ID: {plan_id}) - IN FLIGHT - Worktree: {WORKTREE_PATH}"

### Phase 2: Tasks Already Loaded

Tasks are in `CTX.pending_tasks` (from get-context). No separate query needed.
Extract with: `echo "$CTX" | jq '.pending_tasks[]'`

### Phase 3: Execute Loop

For each pending task from `CTX.pending_tasks`:

```typescript
// All task data comes from CTX - NO DB re-query by task-executor
await Task({
  subagent_type: "task-executor",
  model: task.model || "sonnet",
  description: `Execute task ${task.task_id}`,
  prompt: `
TASK EXECUTION (Isolated Session)

Project: ${project_id} | Plan: ${plan_id}
Wave: ${task.wave_id} (db_id: ${task.wave_db_id})
Task: ${task.task_id} (db_id: ${task.db_id})
**WORKTREE**: ${WORKTREE_PATH}
**FRAMEWORK**: ${FRAMEWORK}

Title: ${task.title}
Description: ${task.description}
Priority: ${task.priority}
Test Criteria: ${task.test_criteria}

## PLAN CONTEXT
${PLAN_CONTENT}

Requirements:
1. Run 'export PATH="$HOME/.claude/scripts:$PATH"' FIRST
2. cd ${WORKTREE_PATH} && pwd
3. Mark in_progress, execute, test, mark done
4. Provide proof of modification (git diff)

CRITICAL: All task data above is PRE-LOADED. Do NOT query the DB for task details.
`,
});

// Verify task completed
Bash(`~/.claude/scripts/verify-task-update.sh ${task.db_id} done`);
```

**Task retry loop** (max 2 retries):

1. After task-executor returns, run `verify-task-update.sh`
2. If NOT done: re-launch with error context
3. After 2 retries: mark `blocked`, ASK USER via AskUserQuestion

### Phase 4: Wave Completion + Thor

Track wave completion in-memory. After each task, increment counter:

```
wave_done_count[wave_db_id] += 1
if wave_done_count[wave_db_id] == wave_tasks_total:
  # Wave complete - launch Thor
```

When wave completes, launch Thor:

```
Task(
  subagent_type="thor-quality-assurance-guardian",
  model="sonnet",
  description="Thor validates Wave ${wave_id}",
  prompt="THOR VALIDATION SESSION
  FIRST: Run 'export PATH=$HOME/.claude/scripts:$PATH'
  Plan ID: ${PLAN_ID}
  Wave: ${wave_id} (db_id: ${wave_db_id})
  Plan Markdown: ${PLAN_MARKDOWN_PATH}
  Source Prompt: ${SOURCE_FILE}
  WORKTREE: ${WORKTREE_PATH}
  FRAMEWORK: ${FRAMEWORK}
  F-xx Requirements: [extract from plan markdown]

  Validate this wave. Read plan markdown for F-xx and task specs."
)
```

**Thor review loop** (max 3 rounds):

- PASS: `plan-db.sh validate $PLAN_ID` -> next wave
- REJECT: Launch targeted fix via task-executor, re-validate
- Round 3 still REJECT: STOP, ASK USER

### Phase 5: Plan Completion

```bash
plan-db.sh validate $PLAN_ID
plan-db.sh complete $PLAN_ID
echo "Piano completato - In attesa di approvazione utente"
```

## Error Handling

> See [error-handling.md](./execute-modules/error-handling.md)

## Output Format

Progress: `[N/total] task_id: title -> Status: DONE/IN PROGRESS`
Wave complete: `--- Wave WX Complete --- Thor: PASS | Build: PASS`
Final: `=== PLAN COMPLETE === Tasks: done/total | Thor: PASS`

## Quick Reference

```bash
/execute 42                  # Specific plan
plan-db.sh get-context 42    # Full plan context (JSON)
plan-db.sh status            # Quick status
```
