# Planner Quick Reference

**Single source of truth: SQLite database at `~/.claude/data/dashboard.db`**

---

## ID Types (CRITICAL)

| Type | Example | Used For |
|------|---------|----------|
| **plan_id** | `11` | Create plan, add waves, validation |
| **db_wave_id** | `41` | Add tasks, update wave status |
| **db_task_id** | `172` | Update task status, executor commands |
| **wave_code** | `W1` | Reference in markdown, documentation |
| **task_id** | `T1-01` | Reference in markdown, documentation |

---

## Command Syntax (EXACT)

### Create Plan
```bash
~/.claude/scripts/plan-db.sh create {project_id} "{PlanName}"
# Returns: plan_id (numeric, e.g., 11)
```

### Add Wave
```bash
~/.claude/scripts/plan-db.sh add-wave {plan_id} "W1" "Wave Name"
# Returns: db_wave_id (numeric, e.g., 41)
# SAVE THIS - you need it for add-task
```

### Add Task
```bash
~/.claude/scripts/plan-db.sh add-task {db_wave_id} T1-01 "Task title" P1 feature
# Parameters:
#   db_wave_id   = numeric ID from add-wave (NOT "W1")
#   T1-01        = task code (string)
#   "Task title" = description
#   P1           = priority (P0, P1, P2, P3)
#   feature      = type (feature, bug, chore, doc, test)
# Returns: db_task_id (numeric, e.g., 172)
```

### Get Task DB ID
```bash
# Use wave_id_fk (numeric) for task lookups
DB_TASK_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM tasks WHERE wave_id_fk=$DB_WAVE_ID AND task_id='T1-01';")
echo $DB_TASK_ID
```

### Update Task Status
```bash
~/.claude/scripts/plan-db.sh update-task {db_task_id} in_progress ""
~/.claude/scripts/plan-db.sh update-task {db_task_id} done "Summary of work"
# Statuses: pending, in_progress, done, blocked, skipped
```

### Update Wave Status
```bash
~/.claude/scripts/plan-db.sh update-wave {db_wave_id} done
# Statuses: pending, in_progress, done, blocked
```

### Validate Plan (Thor)
```bash
~/.claude/scripts/plan-db.sh validate {plan_id}
# Runs all Thor checks on the plan
```

---

## Workflow Step-by-Step

```bash
# 1. Create plan
PLAN_ID=$(~/.claude/scripts/plan-db.sh create "my-project" "MyPlan")
echo "Plan ID: $PLAN_ID"

# 2. Create first wave
WAVE_ID=$(~/.claude/scripts/plan-db.sh add-wave $PLAN_ID "W1" "Setup Phase")
echo "Wave DB ID: $WAVE_ID"

# 3. Add first task to wave
TASK_ID=$(~/.claude/scripts/plan-db.sh add-task $WAVE_ID T1-01 "Analyze requirements" P1 feature)
echo "Task DB ID: $TASK_ID"

# 4. Mark task as in progress
~/.claude/scripts/plan-db.sh update-task $TASK_ID in_progress ""

# 5. Work on task...
# (implement, test, etc)

# 6. Mark task as done
~/.claude/scripts/plan-db.sh update-task $TASK_ID done "Completed analysis document"

# 7. Mark wave as done (after all tasks done)
~/.claude/scripts/plan-db.sh update-wave $WAVE_ID done

# 8. Validate entire plan
~/.claude/scripts/plan-db.sh validate $PLAN_ID
```

---

## Database Schema (Key Tables)

```sql
-- Plans
plans(id, project_id, name, is_master, status, tasks_done, tasks_total)

-- Waves
waves(id, project_id, wave_id, plan_id, name, status, assignee, tasks_done, tasks_total)

-- Tasks
tasks(id, project_id, wave_id, task_id, title, status, priority, type, started_at, completed_at, tokens, validated_at, validated_by)
```

---

## Common Queries

### List all waves in a plan
```bash
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, wave_id, name, status, tasks_done, tasks_total FROM waves WHERE plan_id={plan_id};"
```

### List all tasks in a wave
```bash
# Use wave_id_fk (numeric FK)
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, task_id, title, status FROM tasks WHERE wave_id_fk={db_wave_id};"
```

### Check plan progress
```bash
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT tasks_done, tasks_total, (tasks_done*100/tasks_total) as percent FROM plans WHERE id={plan_id};"
```

---

## ⚠️ Common Mistakes

| Mistake | Wrong | Correct |
|---------|-------|---------|
| Using "W1" in add-task | `add-task W1 T1-01` | `add-task 41 T1-01` (use db_wave_id) |
| Using task_id in update-task | `update-task T1-01` | `update-task 172` (use db_task_id) |
| Forgetting return values | Not saving db_wave_id | Save output: `WAVE_ID=$(add-wave ...)` |
| Mixing --flags | `--type feature --priority P1` | Positional: `feature P1` |

---

## Source of Truth

**THE DATABASE IS THE SINGLE SOURCE OF TRUTH**

- All plans/waves/tasks MUST be in the database
- plan.json files are for documentation/reference only
- Dashboard reads from database, NOT from .json files
- Always use plan-db.sh to modify plans
- Never manually edit the database unless you know what you're doing
