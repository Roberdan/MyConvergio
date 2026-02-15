<!-- v3.0.0 | 15 Feb 2026 | Phase 2 token optimization -->

# Planner Quick Reference

**DB**: `~/.claude/data/dashboard.db` | **CLI**: `plan-db.sh`

## ID Types

| Type       | Example | Used For                   |
| ---------- | ------- | -------------------------- |
| plan_id    | 11      | Create plan, add waves     |
| db_wave_id | 41      | Add tasks, update wave     |
| db_task_id | 172     | Update task, executor cmds |
| wave_code  | W1      | Markdown reference only    |
| task_id    | T1-01   | Markdown reference only    |

## Commands

```bash
# Create
PLAN_ID=$(plan-db.sh create {project_id} "{PlanName}")
WAVE_ID=$(plan-db.sh add-wave $PLAN_ID "W1" "Wave Name")
TASK_ID=$(plan-db.sh add-task $WAVE_ID T1-01 "Title" P1 feature)

# Update
plan-db.sh update-task {db_task_id} in_progress ""
plan-db-safe.sh update-task {db_task_id} done "Summary"  # auto-validates
plan-db.sh update-wave {db_wave_id} done

# Validate (Thor)
plan-db.sh validate-task {task_id} {plan_id}      # per-task
plan-db.sh validate-wave {db_wave_id}              # per-wave
plan-db.sh validate {plan_id}                      # bulk

# Lookup DB IDs
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM tasks WHERE wave_id_fk=$DB_WAVE_ID AND task_id='T1-01';"
```

## Schema (Key Tables)

```sql
plans(id, project_id, name, is_master, status, tasks_done, tasks_total)
waves(id, project_id, wave_id, plan_id, name, status, tasks_done, tasks_total)
tasks(id, project_id, wave_id_fk, task_id, title, status, priority, type,
      effort_level, tokens, validated_at, validated_by)
```

## Common Queries

```bash
# Waves in plan
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, wave_id, name, status FROM waves WHERE plan_id={plan_id};"

# Tasks in wave
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, task_id, title, status FROM tasks WHERE wave_id_fk={db_wave_id};"

# Plan progress
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT tasks_done, tasks_total, (tasks_done*100/tasks_total) FROM plans WHERE id={plan_id};"
```

## Common Mistakes

| Mistake              | Wrong                 | Correct                   |
| -------------------- | --------------------- | ------------------------- |
| "W1" in add-task     | `add-task W1 T1-01`   | `add-task 41 T1-01`       |
| task_id in update    | `update-task T1-01`   | `update-task 172`         |
| Forget return values | Not saving db_wave_id | `WAVE_ID=$(add-wave ...)` |
| --flags              | `--type feature`      | Positional: `P1 feature`  |

**Database is single source of truth.** All plans/waves/tasks MUST be in database. Use plan-db.sh to modify. Never manually edit database.
