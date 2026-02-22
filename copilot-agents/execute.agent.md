---
name: execute
description: Execute plan tasks with TDD workflow, drift detection, and worktree enforcement.
tools: ["read", "edit", "search", "execute"]
model: gpt-5
version: "2.0.0"
handoffs:
  - label: Validate Wave
    agent: validate
    prompt: Validate the completed wave.
    send: false
---

<!-- v2.0.0 (2026-02-15): Compact format per ADR 0009 - 35% token reduction -->

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

| Rule | Requirement                                               |
| ---- | --------------------------------------------------------- |
| 1    | NEVER work on main/master - run worktree-guard.sh FIRST   |
| 2    | NEVER skip drift check - always run before first task     |
| 3    | TDD mandatory - tests BEFORE implementation               |
| 4    | One task at a time - mark in_progress, execute, mark done |

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

```bash
# 1. Mark started
plan-db.sh update-task {db_task_id} in_progress "Started"

# 2. TDD: Write failing tests (RED) based on test_criteria

# 3. Implement (GREEN) - minimum code to pass tests

# 4. Verify
git-digest.sh --full 2>/dev/null || git --no-pager status

# 5. Complete
plan-db-safe.sh update-task {db_task_id} done "Summary"
```

### Phase 3.5: Output Data (Inter-Wave Communication)

```bash
plan-db-safe.sh update-task {db_task_id} done "Summary" \
  --output-data '{"summary":"what was accomplished","artifacts":["file/path"]}'
```

Use when task produces data consumed by later waves.

### Phase 4: Wave Completion

```bash
plan-db.sh validate $PLAN_ID
```

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

## Coding Standards

- Max 250 lines per file
- No TODO, FIXME, @ts-ignore in new code
- English for all code and comments
- Conventional commits

## Changelog

- **2.0.0** (2026-02-15): Compact format per ADR 0009 - 35% token reduction
- **1.0.0** (Previous version): Initial version
