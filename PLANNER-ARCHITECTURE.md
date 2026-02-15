<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Planner Architecture

**Single Source of Truth**: `~/.claude/data/dashboard.db`

## Data Flow

```
dashboard.db → plan-db.sh → Planner/Executor/Thor → Dashboard API
```

All plan data through database. NOT through .md/.json files.

## File Authority

| Type          | Files                      | Authority |
| ------------- | -------------------------- | --------- |
| Authoritative | SQLite DB, plan-db.sh, API | Use this  |
| Reference     | .md plan docs              | Read-only |
| Deprecated    | plan.json, init-db-v3.sql  | Don't use |

## Workflow

### Create Plan

```bash
PLAN_ID=$(plan-db.sh create "project" "PlanName")
WAVE_ID=$(plan-db.sh add-wave $PLAN_ID "W1" "Phase 1")
TASK_ID=$(plan-db.sh add-task $WAVE_ID T1-01 "Task" P1 feature)
```

### Update Plan

```bash
# Get numeric DB IDs (use wave_id_fk, not wave_id string)
WAVE_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM waves WHERE plan_id=$PLAN_ID LIMIT 1;")
TASK_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM tasks WHERE wave_id_fk=$WAVE_ID AND task_id='T1-01';")

plan-db.sh update-task $TASK_ID in_progress ""
plan-db.sh update-task $TASK_ID done "Summary"
```

## Schema

### plans

```sql
id INTEGER PRIMARY KEY, project_id TEXT, name TEXT, is_master BOOLEAN
status TEXT, tasks_done INTEGER, tasks_total INTEGER
```

### waves

```sql
id INTEGER PRIMARY KEY, project_id TEXT, wave_id TEXT, plan_id INTEGER (FK)
name TEXT, status TEXT, tasks_done INTEGER, tasks_total INTEGER
```

### tasks

```sql
id INTEGER PRIMARY KEY, project_id TEXT, wave_id TEXT (legacy)
wave_id_fk INTEGER (FK - USE THIS!), plan_id INTEGER (FK)
task_id TEXT, title TEXT, status TEXT, priority TEXT, type TEXT
model TEXT, effort_level INTEGER (1=trivial, 2=standard, 3=complex)
started_at, completed_at, tokens INTEGER, validated_at, validated_by TEXT
notes TEXT, executor_status TEXT, executor_agent TEXT, output_data TEXT
```

## Rules

### DO

- Use plan-db.sh for all operations
- Save numeric DB IDs when creating
- Use `wave_id_fk` (numeric) for task lookups
- Create .md docs for human reference only

### DON'T

- Create/rely on plan.json
- Manually edit database (use plan-db.sh)
- Assume .md files sync to database
- Forget numeric DB IDs

## Verification

```bash
# Dashboard source
curl http://localhost:31415/api/plans/claude

# Database state
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, name, status FROM plans WHERE project_id='claude';"
```

**Database vs files conflict**: Trust database.

## Summary

| Aspect      | Location  | Authority      |
| ----------- | --------- | -------------- |
| Plan data   | SQLite DB | Authoritative  |
| Exec state  | SQLite DB | Authoritative  |
| Token usage | SQLite DB | Authoritative  |
| Human docs  | .md files | Reference only |
| Dashboard   | API → DB  | Read from DB   |
