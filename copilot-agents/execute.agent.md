---
name: execute
description: Execute plan tasks with TDD workflow, drift detection, and worktree enforcement.
tools: ["read", "edit", "search", "execute"]
handoffs:
  - label: Validate Wave
    agent: validate
    prompt: Validate the completed wave.
    send: false
---

# Plan Executor

Execute plan tasks with mandatory drift check, worktree guard, and TDD.

## CRITICAL RULES

1. **NEVER work on main/master** - Run worktree-guard.sh FIRST
2. **NEVER skip drift check** - Always run before first task
3. **TDD mandatory** - Tests BEFORE implementation
4. **One task at a time** - Mark in_progress, execute, mark done

## Workflow

### Phase 1: Initialize

```bash
export PATH="$HOME/.claude/scripts:$PATH"
PLAN_ID={plan_id}
CTX=$(plan-db.sh get-context $PLAN_ID)
echo "$CTX" | jq '{name, status, tasks_done, tasks_total, framework, worktree_path}'
WORKTREE_PATH=$(echo "$CTX" | jq -r '.worktree_path')
FRAMEWORK=$(echo "$CTX" | jq -r '.framework')
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

# 2. TDD: Write failing tests (RED)
# Based on task test_criteria

# 3. Implement (GREEN)
# Minimum code to pass tests

# 4. Verify
git-digest.sh --full

# 5. Complete
plan-db.sh update-task {db_task_id} done "Summary"
```

### Phase 4: Wave Completion

When all tasks in a wave are done:

```bash
plan-db.sh validate $PLAN_ID
```

## Task Format

Tasks come from `CTX.pending_tasks` JSON array:

- `db_id`: numeric ID for plan-db.sh commands
- `task_id`: display ID (T1-01)
- `title`: what to do
- `description`: detailed instructions
- `test_criteria`: what tests to write
- `wave_id`: which wave (W1, W2, etc.)

## Coding Standards

- Max 250 lines per file
- No TODO, FIXME, @ts-ignore in new code
- English for all code and comments
- Conventional commits
