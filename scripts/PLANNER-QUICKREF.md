<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Planner Quick Reference

**Single source of truth**: `~/.claude/data/dashboard.db`

## ID Types (CRITICAL)

| Type       | Example | Used For                   |
| ---------- | ------- | -------------------------- |
| plan_id    | 11      | Create plan, add waves     |
| db_wave_id | 41      | Add tasks, update wave     |
| db_task_id | 172     | Update task, executor cmds |
| wave_code  | W1      | Markdown reference only    |
| task_id    | T1-01   | Markdown reference only    |

## Commands (EXACT SYNTAX)

### Create Plan

```bash
plan-db.sh create {project_id} "{PlanName}"
# Returns: plan_id (numeric)
```

### Add Wave

```bash
plan-db.sh add-wave {plan_id} "W1" "Wave Name"
# Returns: db_wave_id (SAVE THIS for add-task)
```

### Add Task

```bash
plan-db.sh add-task {db_wave_id} T1-01 "Task title" P1 feature
# Parameters: db_wave_id (NOT "W1"), task_id, title, priority (P0-P3), type
# Type: feature, bug, chore, doc, test
# Returns: db_task_id
```

### Get Task DB ID

```bash
DB_TASK_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM tasks WHERE wave_id_fk=$DB_WAVE_ID AND task_id='T1-01';")
```

### Update Task Status

```bash
plan-db.sh update-task {db_task_id} in_progress ""
plan-db.sh update-task {db_task_id} done "Summary"
# Status: pending, in_progress, done, blocked, skipped
```

### Update Wave Status

```bash
plan-db.sh update-wave {db_wave_id} done
# Status: pending, in_progress, done, blocked
```

### Validate (Thor)

```bash
# Per-task (after each task completes)
plan-db.sh validate-task {task_id} {plan_id}

# Per-wave (after all tasks in wave validated)
plan-db.sh validate-wave {db_wave_id}

# Bulk (all done tasks in plan)
plan-db.sh validate {plan_id}
```

## Workflow

```bash
# 1. Create plan
PLAN_ID=$(plan-db.sh create "my-project" "MyPlan")

# 2. Create first wave
WAVE_ID=$(plan-db.sh add-wave $PLAN_ID "W1" "Setup Phase")

# 3. Add first task
TASK_ID=$(plan-db.sh add-task $WAVE_ID T1-01 "Analyze requirements" P1 feature)

# 4. Execute
plan-db.sh update-task $TASK_ID in_progress ""
# ... work on task ...
plan-db.sh update-task $TASK_ID done "Completed analysis"

# 5. Validate per-task
plan-db.sh validate-task T1-01 $PLAN_ID

# 6. Validate per-wave (after all tasks validated)
plan-db.sh validate-wave $WAVE_ID

# 7. Validate plan (bulk)
plan-db.sh validate $PLAN_ID
```

## Schema (Key Tables)

```sql
plans(id, project_id, name, is_master, status, tasks_done, tasks_total)
waves(id, project_id, wave_id, plan_id, name, status, tasks_done, tasks_total)
tasks(id, project_id, wave_id_fk, task_id, title, status, priority, type,
      effort_level, tokens, validated_at, validated_by)
```

## Common Queries

### List waves in plan

```bash
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, wave_id, name, status FROM waves WHERE plan_id={plan_id};"
```

### List tasks in wave

```bash
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, task_id, title, status FROM tasks WHERE wave_id_fk={db_wave_id};"
```

### Check plan progress

```bash
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT tasks_done, tasks_total, (tasks_done*100/tasks_total) FROM plans WHERE id={plan_id};"
```

## Common Mistakes

| Mistake              | Wrong                          | Correct                   |
| -------------------- | ------------------------------ | ------------------------- |
| "W1" in add-task     | `add-task W1 T1-01`            | `add-task 41 T1-01`       |
| task_id in update    | `update-task T1-01`            | `update-task 172`         |
| Forget return values | Not saving db_wave_id          | `WAVE_ID=$(add-wave ...)` |
| --flags              | `--type feature --priority P1` | Positional: `feature P1`  |

## Source of Truth

**Database is single source of truth.**

- All plans/waves/tasks MUST be in database
- .md/.json files are reference only
- Dashboard reads from database
- Use plan-db.sh to modify
- Never manually edit database
