## <!-- v2.0.0 -->

name: execute
version: "2.0.0"

---

# Plan Executor

Automated task execution via task-executor subagent or Copilot CLI worker.

## Activation

`/execute {plan_id}` or `/execute` (current) | Override: `--engine claude|copilot`

## Engine Selection

| Engine    | Agent/Worker      | Model                    | Billing        |
| --------- | ----------------- | ------------------------ | -------------- |
| `claude`  | task-executor     | gpt-5.3-codex (default)  | Anthropic API  |
| `copilot` | copilot-worker.sh | opus-4.6 (3x premium)    | GitHub Copilot |

## Rules

NEVER execute without plan_id | NEVER skip tasks/Thor | WORKTREE ISOLATION — pass path to EVERY task-executor

## Workflow

### P1: Initialize

`export PATH="$HOME/.claude/scripts:$PATH" && PLAN_ID={plan_id}` → `CTX=$(plan-db.sh get-context $PLAN_ID)` → Extract: `WORKTREE_PATH`, `FRAMEWORK`, `PLAN_STATUS` → `cd "$WORKTREE_PATH"` → `[[ "$PLAN_STATUS" != "doing" ]] && plan-db.sh start $PLAN_ID` → `plan-db.sh check-readiness $PLAN_ID`

### P1.5: Drift Check

`DRIFT_JSON=$(plan-db.sh drift-check $PLAN_ID)` → Check `DRIFT_LEVEL`: **major** → ASK USER (Proceed/Rebase/Replan) | **minor** → `plan-db.sh rebase-plan $PLAN_ID`

### P2-3: Execute Tasks

Tasks in `CTX.pending_tasks` (no separate query).

**Engine: claude** — per-task prompt:

```typescript
const wavePeers = pendingTasks
  .filter((t) => t.wave_db_id === task.wave_db_id && t.db_id !== task.db_id)
  .map((t) => `${t.task_id}: ${t.title}`)
  .join("\n");
await Task({
  subagent_type: "task-executor",
  model: task.model || "sonnet",
  max_turns: 30,
  description: `Execute ${task.task_id}`,
  prompt: `TASK ${task.task_id} | Wave: ${task.wave_id} | db_id: ${task.db_id}
WORKTREE: ${WORKTREE_PATH} | FRAMEWORK: ${FRAMEWORK}
Do: ${task.title}
${task.description}
Verify: ${task.test_criteria}
Wave peers: ${wavePeers}
PATH: export PATH="$HOME/.claude/scripts:$PATH"`,
});
```

**Engine: copilot** — `copilot-worker.sh ${task.db_id} --model claude-opus-4.6 --timeout 600` (uses `--allow-all`, `--add-dir`, `-p` mode, cost: 3 premium/task)

**Post-exec**: `verify-task-update.sh ${task.db_id} done` | Retry max 2x → mark `blocked`, ASK USER

### P4a: Per-Task Thor

`Task(subagent_type="thor-quality-assurance-guardian", model="sonnet", max_turns=15, prompt="THOR PER-TASK VALIDATION | Plan: ${PLAN_ID} | Task: ${task_id} | Wave: ${wave_id} | WORKTREE: ${WORKTREE_PATH} | Task do: ${task_description} | Task type: ${task_type} | Task verify: ${test_criteria_json} | Task ref: ${task_ref} | Task files: ${task_files} | Run verify commands. Check Gate 1-4, 8, 9. Read files directly.")`

PASS → `plan-db.sh validate-task ${task_id} ${PLAN_ID}` | REJECT → fix → re-execute (max 3 rounds)

### P4b: Per-Wave Thor

When `wave_done == wave_tasks_total` AND all tasks have `validated_at`:

`Task(subagent_type="thor-quality-assurance-guardian", model="sonnet", max_turns=20, prompt="THOR PER-WAVE VALIDATION | Plan: ${PLAN_ID} | Wave: ${wave_id} (db_id: ${wave_db_id}) | WORKTREE: ${WORKTREE_PATH} | FRAMEWORK: ${FRAMEWORK} | Tasks in wave: [list task_ids + titles from CTX] | Verify criteria: [list test_criteria for each task] | Run ALL 9 gates. Run: ci-summary.sh --full. Check F-xx cross-task. Read files directly.")`

PASS → `plan-db.sh validate-wave ${wave_db_id}` → next wave | REJECT → fix → re-validate (max 3 rounds)

### P5: Completion

`plan-db.sh validate $PLAN_ID && plan-db.sh complete $PLAN_ID`

## Error Handling

See: @commands/execute-modules/error-handling.md

## Output Format

`[N/total] task_id: title -> DONE` | `--- Wave WX --- Thor: PASS` | `=== COMPLETE ===`
