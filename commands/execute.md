# Plan Executor

Automated execution of plan tasks via task-executor subagent.

## Activation

When message contains `/execute {plan_id}` or `/execute` (uses current plan).

## CRITICAL RULES

1. **NEVER execute without plan_id**
2. **NEVER skip tasks** - Execute ALL pending in order
3. **NEVER skip Thor** - Validate after each wave
4. **WORKTREE ISOLATION** - Pass path to EVERY task-executor

## Workflow

### Phase 1: Initialize (single call)

```bash
export PATH="$HOME/.claude/scripts:$PATH"
PLAN_ID={plan_id}

# ONE call: plan info + all tasks + framework
CTX=$(plan-db.sh get-context $PLAN_ID)
echo "$CTX" | jq '{name, status, tasks_done, tasks_total, framework, worktree_path}'

WORKTREE_PATH=$(echo "$CTX" | jq -r '.worktree_path')
FRAMEWORK=$(echo "$CTX" | jq -r '.framework')
PLAN_STATUS=$(echo "$CTX" | jq -r '.status')

cd "$WORKTREE_PATH" && pwd

[[ "$PLAN_STATUS" != "doing" ]] && plan-db.sh start $PLAN_ID
plan-db.sh check-readiness $PLAN_ID
```

### Phase 2: Tasks from CTX

Tasks are in `CTX.pending_tasks`. No separate query, no file reading needed.

### Phase 3: Execute Loop

For each task, build a **compact per-task prompt** (~100 tokens, NOT the full plan):

```typescript
// Build wave peers list (other tasks in same wave, 1 line each)
const wavePeers = pendingTasks
  .filter((t) => t.wave_db_id === task.wave_db_id && t.db_id !== task.db_id)
  .map((t) => `${t.task_id}: ${t.title}`)
  .join("\n");

await Task({
  subagent_type: "task-executor",
  model: task.model || "sonnet",
  description: `Execute ${task.task_id}`,
  prompt: `TASK ${task.task_id} | Wave: ${task.wave_id} | db_id: ${task.db_id}
WORKTREE: ${WORKTREE_PATH}
FRAMEWORK: ${FRAMEWORK}

Do: ${task.title}
${task.description}
Verify: ${task.test_criteria}

Wave peers:
${wavePeers}

PATH: export PATH="$HOME/.claude/scripts:$PATH"
`,
});

Bash(`~/.claude/scripts/verify-task-update.sh ${task.db_id} done`);
```

**KEY**: No PLAN_CONTENT, no full markdown. Each task gets only its own data + wave peers.

**Task retry** (max 2): re-launch with error context. After 2: mark `blocked`, ASK USER.

### Phase 4: Wave Completion + Thor

Track in-memory. When `wave_done == wave_tasks_total`:

```
Task(
  subagent_type="thor-quality-assurance-guardian",
  model="sonnet",
  description="Thor validates ${wave_id}",
  prompt="THOR VALIDATION
  Plan: ${PLAN_ID} | Wave: ${wave_id} (db_id: ${wave_db_id})
  WORKTREE: ${WORKTREE_PATH} | FRAMEWORK: ${FRAMEWORK}
  Tasks in wave: [list task_ids + titles from CTX]
  Verify criteria: [list test_criteria for each task in wave]
  Run: lint, typecheck, build, tests. Check F-xx. Read files directly."
)
```

Thor loop (max 3): PASS -> `plan-db.sh validate` -> next wave. REJECT -> fix -> re-validate.

### Phase 5: Completion

```bash
plan-db.sh validate $PLAN_ID
plan-db.sh complete $PLAN_ID
```

## Error Handling

> See [error-handling.md](./execute-modules/error-handling.md)

## Output

`[N/total] task_id: title -> DONE` | `--- Wave WX --- Thor: PASS` | `=== COMPLETE ===`
