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

### P2-3: Execute Tasks

Tasks in `CTX.pending_tasks` (no separate query). Execute each task directly:

**Step 1: Mark started**

```bash
plan-db.sh update-task ${task.db_id} in_progress "Started"
```

**Step 1.5: Model routing (before TDD)**

```bash
MODEL_JSON=$(model-router.sh --task-type ${task.type} --effort ${task.effort_level} --executor-agent ${task.executor_agent} 2>/dev/null || echo '{"model":"","batch_eligible":false}')
MODEL=$(echo "$MODEL_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["model"])' 2>/dev/null || echo "${task.model}")
BATCH_ELIGIBLE=$(echo "$MODEL_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("true" if d.get("batch_eligible") else "false")' 2>/dev/null || echo "false")
```

**Shortcut**: `c model route --type X --effort Y --agent Z` → calls model-router.sh
**Fallback**: if model-router.sh not found, MODEL defaults to `task.model` from DB (backward compat)

**Batch routing** (after MODEL/BATCH_ELIGIBLE set):

```bash
if [[ "$BATCH_ELIGIBLE" == "true" ]] && [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  batch-dispatcher.sh ${task.db_id} ${PLAN_ID} "${task_prompt}"
  # batch-dispatcher.sh handles status update; skip inline execution
else
  # Standard inline execution (existing logic below)
fi
```

**Step 2: TDD + implement (inline)**

Work directly in worktree: edit/create files, write tests, run tests.

**Step 3: Verify**

```bash
cd "$WORKTREE_PATH"
npm run test:unit -- --reporter=dot   # full unit suite
npm run typecheck                      # type safety
# Run task-specific verify commands from test_criteria
```

**Step 4: Submit (proof-of-work)**

```bash
plan-db-safe.sh update-task ${task.db_id} done "Summary" \
  --output-data '{"summary":"...","artifacts":["file1"]}'
# Runs Guard 1 (time), Guard 2 (git-diff), Guard 3 (verify) → sets "submitted"
# If REJECTED: fix the issue, retry
```

**Step 5: Validate (Thor)**

Self-validate: re-read files, check constraints, confirm tests pass.

```bash
plan-db.sh validate-task ${task.db_id} ${PLAN_ID} thor
# SQLite trigger enforces: submitted → done with valid validator
```

**Step 6: Confirm**

```bash
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT status, validated_at FROM tasks WHERE id=${task.db_id};"
# Must show: status=done, validated_at NOT NULL
```

**Background delegation** (parallel low-risk tasks only):

```bash
copilot-worker.sh ${task.db_id} --model gpt-5-mini --timeout 300 &
```

**Failed task handling**: max 3 rounds fix→resubmit→revalidate. After 3 rejections: circuit breaker auto-blocks. Log failures:

```bash
plan-db.sh log-failure $PLAN_ID ${task.task_id} "approach" "reason"
```

### P4a: Per-Task Thor (Self-Validation)

Before calling `validate-task`, verify ALL of:

1. Files exist: `test -f` for each expected artifact
2. Verify commands: run ALL from `test_criteria.verify[]`
3. Tests pass: `npm run test:unit -- {files} --reporter=dot`
4. Constraints: check C-01..C-xx from plan context
5. Line limits: `wc -l` on modified files (max 250)

If ANY fails → fix, re-submit (Step 4), re-validate.

PASS → `plan-db.sh validate-task ${task.db_id} ${PLAN_ID} thor`

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
