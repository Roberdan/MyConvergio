---
name: execute
description: Execute plan tasks with TDD workflow, drift detection, and worktree enforcement.
tools: ["read", "edit", "search", "execute"]
model: gpt-5
version: "3.0.0"
handoffs:
  - label: Validate Wave
    agent: validate
    prompt: Validate the completed wave.
    send: false
---

<!-- v3.0.0 (2026-02-24): Add Thor per-task, F-xx verification, proof of modification, exit checklist -->

# Plan Executor

Execute plan tasks with mandatory drift check, worktree guard, and TDD.
Works with ANY repository - auto-detects project context.

## Model Selection

- Default: `gpt-5` (best code generation)
- Override per-task using `model` field from spec.json

| Task model value       | Copilot CLI model  |
| ---------------------- | ------------------ |
| codex / gpt-5          | gpt-5              |
| opus / claude-opus-4.6 | claude-opus-4.6    |
| opus-1m                | claude-opus-4.6-1m |
| sonnet                 | claude-sonnet-4.5  |
| haiku                  | claude-haiku-4.5   |
| codex-mini             | gpt-5-mini         |

## Critical Rules

| Rule | Requirement                                                           |
| ---- | --------------------------------------------------------------------- |
| 1    | NEVER work on main/master - run worktree-guard.sh FIRST               |
| 2    | NEVER skip drift check - always run before first task                 |
| 3    | TDD mandatory - tests BEFORE implementation                           |
| 4    | One task at a time - mark in_progress, execute, mark done             |
| 5    | **NEVER skip Thor** - run `validate-task` after EVERY task completion |
| 6    | NEVER mark done without proof - git-digest.sh + F-xx verification     |
| 7    | Prefer merge-async for overlapping execution, sync merge as fallback  |

## Workflow

### Phase 1: Initialize

```bash
export PATH="$HOME/.claude/scripts:$PATH"

INIT=$(planner-init.sh 2>/dev/null) || INIT='{"project_id":1}'
PROJECT_ID=$(echo "$INIT" | jq -r '.project_id')
PLAN_ID=$(echo "$INIT" | jq -r '.active_plans[0].id // empty')

[[ -z "$PLAN_ID" ]] && { echo "No active plan for $PROJECT_ID"; plan-db.sh list "$PROJECT_ID"; exit 1; }

CTX=$(plan-db.sh get-context $PLAN_ID)
echo "$CTX" | jq '{name,status,tasks_done,tasks_total,framework,worktree_path}'
WORKTREE_PATH=$(echo "$CTX" | jq -r '.worktree_path')
cd "$WORKTREE_PATH" && pwd
[[ "$(echo "$CTX" | jq -r '.status')" != "doing" ]] && plan-db.sh start $PLAN_ID
plan-db.sh check-readiness $PLAN_ID
```

### Phase 1.5: Drift Check (MANDATORY)

```bash
DRIFT_JSON=$(plan-db.sh drift-check $PLAN_ID) || true
DRIFT_LEVEL=$(echo "$DRIFT_JSON" | jq -r '.drift')
if [[ "$DRIFT_LEVEL" == "major" ]]; then
  echo "$DRIFT_JSON" | jq '{drift,days_stale,branch_behind,overlapping_files}'
  # ASK USER: Proceed / Rebase / Replan
elif [[ "$DRIFT_LEVEL" == "minor" ]]; then
  plan-db.sh rebase-plan $PLAN_ID
fi
```

### Phase 2: Worktree Guard

```bash
worktree-guard.sh "$WORKTREE_PATH"
# If WORKTREE_VIOLATION: STOP. Do NOT proceed.
```

### Phase 3: Execute Each Task

For each task in `CTX.pending_tasks`:

**Step 1: Mark started**

```bash
plan-db.sh update-task {db_task_id} in_progress "Started"
```

**Step 2: TDD (RED)** - Write failing tests based on `test_criteria`. Run tests, confirm RED.

**Step 3: Implement (GREEN)** - Minimum code to pass tests. Run tests after each change.

**Step 3.5: Consumer Audit (MANDATORY)**

For each file in `task.consumers[]` from the spec:

```bash
# Verify new export is imported by each consumer
grep -r 'import.*NewExportName' path/to/consumer.tsx
# If NOT found: fix the consumer NOW or report BLOCKED
```

If task has no `consumers` field, skip. If any consumer does NOT import the new code, update it before proceeding.

**Step 4: F-xx Verification (MANDATORY)**

```markdown
## F-xx VERIFICATION

| F-xx | Requirement | Status   | Evidence       |
| ---- | ----------- | -------- | -------------- |
| F-01 | [req]       | [x] PASS | [how verified] |

VERDICT: PASS
```

**Step 5: Proof of Modification (MANDATORY)**

```bash
git-digest.sh --full 2>/dev/null || git --no-pager status
```

If no files modified: report "BLOCKED: No file modifications detected".

**Step 6: Thor Per-Task Validation (MANDATORY - NEVER SKIP)**

```bash
plan-db.sh validate-task {db_task_id} $PLAN_ID
# If REJECTED: fix issues, re-run validate-task. Max 3 rounds.
# Do NOT proceed to Step 7 without Thor PASS.
```

**Step 7: Complete (ONLY after Thor PASS)**

```bash
plan-db-safe.sh update-task {db_task_id} done "Summary"
```

**Step 8: Exit Checklist**

```bash
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT task_id, status FROM tasks WHERE id={db_task_id};"
# Must show: done. If NOT done, run plan-db-safe.sh NOW.
```

### Phase 3.5: Output Data (Inter-Wave Communication)

```bash
plan-db-safe.sh update-task {db_task_id} done "Summary" \
  --output-data '{"summary":"what was accomplished","artifacts":["file/path"]}'
```

Use when task produces data consumed by later waves.

### Phase 4: Wave Completion (Thor Per-Wave - MANDATORY)

After ALL tasks in wave are Thor-validated (Step 6 passed for each):

```bash
# Get wave DB ID
WAVE_DB_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT w.id FROM waves w WHERE w.plan_id = $PLAN_ID AND w.wave_id = '{wave_id}';")

# Thor per-wave validation - ALL 9 gates
plan-db.sh validate-wave $WAVE_DB_ID
# If REJECTED: fix, re-validate. Max 3 rounds.
```

**NEVER proceed to next wave without per-wave Thor PASS.**

### Phase 4.5: Overlapping Wave Protocol (PREFERRED)

Instead of blocking on PR merge, use async flow to start next wave immediately:

```bash
# After all tasks in wave are Thor-validated:
wave-worktree.sh merge-async $PLAN_ID $WAVE_DB_ID
# Returns immediately with PR number — does NOT wait for CI/review

# Create next wave worktree from current branch tip (not main)
wave-worktree.sh create $PLAN_ID $NEXT_WAVE_DB_ID
# Start next wave tasks immediately

# Before closing next wave, sync with previous PR:
wave-worktree.sh pr-sync $PLAN_ID $NEXT_WAVE_DB_ID
# Verifies previous PR merged, rebases current wave, extracts feedback
```

**Fallback**: If merge-async is not suitable (single-wave plan, final wave), use `merge` (sync).
**Conflict handling**: If pr-sync rebase fails, STOP and resolve manually.
**Feedback propagation**: PR review comments are injected into next wave task prompts automatically.

## Task Format

Tasks from `CTX.pending_tasks` JSON:

| Field         | Description                  |
| ------------- | ---------------------------- |
| db_id         | numeric ID for plan-db.sh    |
| task_id       | display ID (T1-01)           |
| title         | what to do                   |
| description   | detailed instructions        |
| test_criteria | what tests to write          |
| wave_id       | which wave                   |
| model         | which AI model (see routing) |

## CI Batch Fix (NON-NEGOTIABLE)

Wait for FULL CI before pushing fixes. Collect ALL failures. Fix ALL in one commit. Push once. Max 3 rounds. Pushing after fixing only 1 error while CI has more = REJECTED.

## Zero Technical Debt (NON-NEGOTIABLE)

Resolve ALL issues, not just high-priority. Every CI error, lint warning, type error, test failure MUST be resolved before done. Accumulated debt = VIOLATION.

## Coding Standards

Max 250 lines/file. No TODO/FIXME/@ts-ignore. English. Conventional commits.

## Changelog

- **3.1.0** (2026-02-27): Add Phase 4.5 Overlapping Wave Protocol (merge-async, pr-sync, feedback injection)
- **3.0.0** (2026-02-24): Thor per-task, F-xx verification, proof of modification, exit checklist
- **2.0.0** (2026-02-15): Compact format per ADR 0009
