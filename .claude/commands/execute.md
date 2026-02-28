## <!-- v2.2.0 -->

name: execute
version: "2.2.0"

---

# Plan Executor

Automated task execution with per-task routing: Copilot CLI (default) or Claude task-executor.

## Activation

`/execute {plan_id}` or `/execute` (current) | Override: `--force-engine claude|copilot` (overrides per-task routing)

## Per-Task Engine Routing

Each task has `executor_agent` in DB (set by planner). Executor reads it and routes accordingly.

| executor_agent | Agent/Worker      | Billing        |
| -------------- | ----------------- | -------------- |
| `copilot`      | copilot-worker.sh | GitHub (free)  |
| `claude`       | task-executor     | Anthropic ($$) |

**Default is `copilot`**. See @planner-modules/model-strategy.md for escalation criteria.

## Rules

NEVER execute without plan_id | NEVER skip tasks/Thor | WORKTREE ISOLATION — pass path to EVERY executor

## Workflow

### P1: Initialize

`export PATH="$HOME/.claude/scripts:$PATH" && PLAN_ID={plan_id}` → `CTX=$(plan-db.sh get-context $PLAN_ID)` → Extract: `WORKTREE_PATH`, `FRAMEWORK`, `PLAN_STATUS`, `CONSTRAINTS` → `cd "$WORKTREE_PATH"` → `[[ "$PLAN_STATUS" != "doing" ]] && plan-db.sh start $PLAN_ID` → `plan-db.sh check-readiness $PLAN_ID`

**Extract constraints** (ADR-054): `CONSTRAINTS=$(echo "$CTX" | jq -r '.constraints // [] | .[] | "C-" + .id + ": " + .text' )`. If non-empty, EVERY task prompt MUST include constraints block.

### P1.5: Drift Check

`DRIFT_JSON=$(plan-db.sh drift-check $PLAN_ID)` → Check `DRIFT_LEVEL`: **major** → ASK USER (Proceed/Rebase/Replan) | **minor** → `plan-db.sh rebase-plan $PLAN_ID`

### P1.8: CI Knowledge Lookup

Load CI knowledge from the repo first, fallback to global:

```bash
CI_KNOWLEDGE=""
if [[ -f "${WORKTREE_PATH}/.claude/ci-knowledge.md" ]]; then
  CI_KNOWLEDGE=$(cat "${WORKTREE_PATH}/.claude/ci-knowledge.md")
elif [[ -f "${WORKTREE_PATH}/docs/ci-knowledge.md" ]]; then
  CI_KNOWLEDGE=$(cat "${WORKTREE_PATH}/docs/ci-knowledge.md")
elif [[ -f "$HOME/.claude/data/ci-knowledge/${PROJECT_ID}.md" ]]; then
  CI_KNOWLEDGE=$(cat "$HOME/.claude/data/ci-knowledge/${PROJECT_ID}.md")
fi
```

New repos: add `.claude/ci-knowledge.md` (if `.claude/` is trackable) or `docs/ci-knowledge.md` (if `.claude/` has nested git or is gitignored).

### Model Name Mapping (Claude tasks)

When `executor_agent == "claude"`, map full model IDs to Claude API shorthand:

| Full Model ID (DB)     | Agent Shorthand |
| ---------------------- | --------------- |
| `claude-opus-4.6`      | `opus`          |
| `claude-opus-4.6-fast` | `opus`          |
| `claude-opus-4.5`      | `opus`          |
| `claude-sonnet-4.6`    | `sonnet`        |
| `claude-sonnet-4.5`    | `sonnet`        |
| `claude-sonnet-4`      | `sonnet`        |
| `claude-haiku-4.5`     | `haiku`         |

Unmapped models (GPT, Gemini) pass through as-is. Use: `MODEL_MAP[task.model] || task.model`.

### P2-3: Execute Tasks (Per-Task Routing)

Tasks in `CTX.pending_tasks` (no separate query). Route each task by `executor_agent` (NULL or empty = `copilot`):

**If `executor_agent == "copilot"` (default)**:

```bash
copilot-worker.sh ${task.db_id} --model ${task.model} --timeout 600
```

Uses `--allow-all`, `--add-dir`, `--no-ask-user`, `-p` mode. Model from DB (e.g. `gpt-5.3-codex`, `claude-opus-4.6-fast`).

**If `executor_agent == "claude"`**:

```typescript
const wavePeers = pendingTasks
  .filter((t) => t.wave_db_id === task.wave_db_id && t.db_id !== task.db_id)
  .map((t) => `${t.task_id}: ${t.title}`)
  .join("\n");
const priorOutputs = CTX.completed_tasks_output
  .map((t) => `${t.task_id}: ${t.output_data}`)
  .join("\n");
await Task({
  subagent_type: "task-executor",
  model: MODEL_MAP[task.model] || task.model || "sonnet",
  max_turns: 30,
  description: `Execute ${task.task_id}`,
  prompt: `TASK ${task.task_id} | Wave: ${task.wave_id} | db_id: ${task.db_id}
WORKTREE: ${WORKTREE_PATH} | FRAMEWORK: ${FRAMEWORK}
CONSTRAINTS (MUST NOT VIOLATE): ${CONSTRAINTS || "none"}
Do: ${task.title}
${task.description}
Verify: ${task.test_criteria}
Wave peers: ${wavePeers}
Prior task outputs: ${priorOutputs || "none"}
${CI_KNOWLEDGE ? `CI Knowledge (avoid these patterns):\n${CI_KNOWLEDGE}` : ""}
PATH: export PATH="$HOME/.claude/scripts:$PATH"`,
});
```

**Post-exec (both engines)**: `verify-task-update.sh ${task.db_id} done` | Retry max 2x → **log failure** → mark `blocked`, ASK USER

**Failed Approaches Logging** (HVE Core pattern): Before marking a task `blocked`, log what was tried and why it failed:

```bash
plan-db.sh log-failure $PLAN_ID ${task.task_id} "approach description" "failure reason"
```

Before retrying a failed task, check prior failures: `plan-db.sh get-failures $PROJECT_ID --task-pattern ${task.task_id}`. If same approach failed before, use a different strategy.

### P4a: Per-Task Thor

`Task(subagent_type="thor-quality-assurance-guardian", model="sonnet", max_turns=15, prompt="THOR PER-TASK VALIDATION | Plan: ${PLAN_ID} | Task: ${task_id} | Wave: ${wave_id} | WORKTREE: ${WORKTREE_PATH} | Task do: ${task_description} | Task type: ${task_type} | Task verify: ${test_criteria_json} | Task ref: ${task_ref} | Task files: ${task_files} | Run verify commands. Check Gate 1-4, 8, 9. Read files directly.")`

PASS → `plan-db.sh validate-task ${task_id} ${PLAN_ID}` | REJECT → fix → re-execute (max 3 rounds)

### P4b: Per-Wave Thor

When `wave_done == wave_tasks_total` AND all tasks have `validated_at`:

`Task(subagent_type="thor-quality-assurance-guardian", model="sonnet", max_turns=20, prompt="THOR PER-WAVE VALIDATION | Plan: ${PLAN_ID} | Wave: ${wave_id} (db_id: ${wave_db_id}) | WORKTREE: ${WORKTREE_PATH} | FRAMEWORK: ${FRAMEWORK} | Tasks in wave: [list task_ids + titles from CTX] | Verify criteria: [list test_criteria for each task] | Run ALL 9 gates. Run: ci-summary.sh --full. Check F-xx cross-task. Read files directly.")`

PASS → `plan-db.sh validate-wave ${wave_db_id}` → merge decision | REJECT → fix → re-validate (max 3 rounds)

### P4c: Post-Wave Merge Decision

After Thor per-wave passes, executor reads `merge_mode` from wave DB and acts accordingly:

| merge_mode | Action                                                     | Branch                          |
| ---------- | ---------------------------------------------------------- | ------------------------------- |
| `sync`     | `wave-worktree.sh merge` → PR + CI + squash merge to main  | wave branch deleted after merge |
| `batch`    | Commit to shared theme branch, NO PR, proceed to next wave | same branch continues           |
| `none`     | Commit only, no PR, no merge                               | wave branch stays               |

**Batch flow**: waves in same theme share one worktree/branch. When the last wave in the theme hits `sync`, ALL accumulated changes merge as one PR. Executor tracks theme boundary via `merge_mode` field.

```
W1 (batch) → commit → Thor → W2 (batch) → commit → Thor → W3 (sync) → PR with W1+W2+W3 → CI → merge
```

**Theme branch naming**: `plan/{plan_id}-{theme}` (e.g., `plan/270-security`). First `batch` wave in a theme creates the branch; subsequent `batch` waves reuse it.

**Merge dispatch** (after Thor per-wave PASS):

```bash
MERGE_MODE=$(sqlite3 ~/.claude/data/dashboard.db "SELECT COALESCE(merge_mode,'sync') FROM waves WHERE id=${wave_db_id};")
case "$MERGE_MODE" in
  sync)  wave-worktree.sh merge $PLAN_ID $wave_db_id ;;
  batch) wave-worktree.sh batch $PLAN_ID $wave_db_id ;;
  none)  plan-db.sh validate-wave $wave_db_id ;;
esac
```

### P5: Completion

`plan-db.sh validate $PLAN_ID && plan-db.sh complete $PLAN_ID`

## Error Handling

See: @commands/execute-modules/error-handling.md

## Output Format

`[N/total] task_id: title -> DONE` | `--- Wave WX --- Thor: PASS` | `=== COMPLETE ===`
