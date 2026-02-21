---
name: execute
version: "1.0.0"
---

# Plan Executor

Automated execution of plan tasks via task-executor subagent or Copilot CLI worker.

## Activation

When message contains `/execute {plan_id}` or `/execute` (uses current plan).

Override: `/execute {plan_id} --engine copilot` or `--engine claude` skips the prompt.

## Engine Selection

If the user did NOT specify `--engine` in the command, **ask which engine to use**:

```
AskUserQuestion:
  question: "Which execution engine should I use for this plan?"
  header: "Engine"
  options:
    - label: "Claude (Recommended)"
      description: "Task-executor subagent, sonnet model, Anthropic API billing"
    - label: "Copilot"
      description: "GitHub Copilot CLI, Opus 4.6 model, 3x premium requests per task"
```

If `--engine` was provided in the message, use that directly (no prompt).

| Engine    | How                                 | Model                        | Cost                        |
| --------- | ----------------------------------- | ---------------------------- | --------------------------- |
| `claude`  | Task(subagent_type="task-executor") | sonnet (or task override)    | Anthropic API               |
| `copilot` | `copilot-worker.sh` via Bash        | claude-opus-4.6 (3x premium) | GitHub Copilot subscription |

## CRITICAL RULES

1. **NEVER execute without plan_id**
2. **NEVER skip tasks** - Execute ALL pending in order
3. **NEVER skip Thor** - Validate after each wave (always via Claude subagent, regardless of engine)
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

### Phase 1.5: Drift Check (MANDATORY before first task)

```bash
DRIFT_JSON=$(plan-db.sh drift-check $PLAN_ID) || true
DRIFT_LEVEL=$(echo "$DRIFT_JSON" | jq -r '.drift')
BEHIND=$(echo "$DRIFT_JSON" | jq -r '.branch_behind')
OVERLAPS=$(echo "$DRIFT_JSON" | jq -r '.overlap_count')

if [[ "$DRIFT_LEVEL" == "major" ]]; then
  echo "DRIFT: major ($OVERLAPS file overlaps, plan stale)"
  echo "$DRIFT_JSON" | jq '{drift,days_stale,branch_behind,overlapping_files}'
  # AskUserQuestion: "Drift rilevato. Procedi / Riallinea (rebase) / Ripianifica?"
  # If "rebase": plan-db.sh rebase-plan $PLAN_ID
  # If "replan": invoke /planner with drift report as context. STOP execution.
elif [[ "$DRIFT_LEVEL" == "minor" ]]; then
  echo "DRIFT: minor (behind=$BEHIND). Auto-rebasing..."
  plan-db.sh rebase-plan $PLAN_ID || {
    echo "Rebase failed. Ask user."; # AskUserQuestion
  }
fi
```

### Phase 2: Tasks from CTX

Tasks are in `CTX.pending_tasks`. No separate query, no file reading needed.

### Phase 3: Execute Loop

For each task, execute using the selected engine.

#### Engine: `claude` (default)

Build a **compact per-task prompt** (~100 tokens, NOT the full plan):

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
```

#### Engine: `copilot`

Delegate to Copilot CLI via `copilot-worker.sh`:

```bash
# copilot-worker.sh reads task from DB, generates prompt, launches copilot -p
copilot-worker.sh ${task.db_id} --model claude-opus-4.6 --timeout 600
```

**Notes on Copilot engine**:

- `copilot-worker.sh` calls `copilot-task-prompt.sh` internally to build the prompt
- Uses `--allow-all` (handles trust + yolo), `--add-dir` (worktree path)
- Copilot runs in non-interactive `-p` mode: receives prompt, executes, exits
- Same TDD workflow, same plan-db.sh commands, same worktree-guard.sh
- Cost: 3 premium requests per task invocation (Opus 4.6)

#### Post-execution (both engines)

```bash
~/.claude/scripts/verify-task-update.sh ${task.db_id} done
```

**KEY**: No PLAN_CONTENT, no full markdown. Each task gets only its own data + wave peers.

**Task retry** (max 2): re-launch with error context. After 2: mark `blocked`, ASK USER.

### Phase 4: Wave Completion + Thor

Track in-memory. When `wave_done == wave_tasks_total`:

```
Task(
  subagent_type="thor-quality-assurance-guardian",
  model="sonnet",
  max_turns=20,
  description="Thor validates ${wave_id}",
  prompt="THOR VALIDATION
  Plan: ${PLAN_ID} | Wave: ${wave_id} (db_id: ${wave_db_id})
  WORKTREE: ${WORKTREE_PATH} | FRAMEWORK: ${FRAMEWORK}
  Tasks in wave: [list task_ids + titles from CTX]
  Verify criteria: [list test_criteria for each task in wave]
  Run: ci-summary.sh --full (or ci-summary.sh --all if i18n/e2e needed). Check F-xx. Read files directly."
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
