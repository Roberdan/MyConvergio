# Planner Architecture - Source of Truth

**Status**: Database is Single Source of Truth

## Architecture

```
~/.claude/data/dashboard.db
├── projects, plans, waves, tasks
├── token_usage, plan_versions
```

**All plan data flows through database:**
- Planner creates plans in DB (not .md files)
- Executor reads/writes tasks to DB
- Dashboard reads from DB API endpoints
- Thor validates against DB state

## File Roles

| Type | Files | Authority |
|------|-------|-----------|
| **Authoritative** | SQLite DB, plan-db.sh, API | ✓ Use this |
| **Reference only** | .md plan docs | Not authoritative |
| **Deprecated** | plan.json, init-db-v3.sql | Don't use |

## Workflow

### Creating Plans
```bash
# 1. Create plan in database
PLAN_ID=$(~/.claude/scripts/plan-db.sh create "project" "PlanName")

# 2. Add waves
WAVE_ID=$(~/.claude/scripts/plan-db.sh add-wave $PLAN_ID "W1" "Phase 1")

# 3. Add tasks
TASK_ID=$(~/.claude/scripts/plan-db.sh add-task $WAVE_ID T1-01 "Task" P1 feature)
```

### Updating Plans
```bash
# Get numeric DB IDs (use FK, not wave_id string!)
WAVE_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM waves WHERE plan_id=$PLAN_ID LIMIT 1;")
TASK_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM tasks WHERE wave_id_fk=$WAVE_ID AND task_id='T1-01';")

# Update via plan-db.sh
plan-db.sh update-task $TASK_ID in_progress ""
plan-db.sh update-task $TASK_ID done "Summary"
```

## Database Schema

### plans
```sql
id INTEGER PRIMARY KEY, project_id TEXT, name TEXT
is_master BOOLEAN, status TEXT, tasks_done INTEGER, tasks_total INTEGER
```

### waves
```sql
id INTEGER PRIMARY KEY, project_id TEXT, wave_id TEXT
plan_id INTEGER (FK), name TEXT, status TEXT
tasks_done INTEGER, tasks_total INTEGER
```

### tasks
```sql
id INTEGER PRIMARY KEY, project_id TEXT
wave_id TEXT (legacy), wave_id_fk INTEGER (FK - USE THIS!)
plan_id INTEGER (FK), task_id TEXT, title TEXT
status TEXT, priority TEXT, type TEXT
started_at, completed_at, tokens INTEGER
validated_at, validated_by TEXT, notes TEXT, executor_status TEXT
```

## Rules

### ✓ DO
1. Use plan-db.sh for all operations
2. Save numeric DB IDs when creating
3. Use `wave_id_fk` (numeric) for task lookups
4. Create .md docs for human reference only

### ❌ DON'T
1. Create/rely on plan.json
2. Manually edit database (use plan-db.sh)
3. Assume .md files sync to database
4. Forget numeric DB IDs

## Verification

```bash
# Check what dashboard reads:
curl http://localhost:31415/api/plans/claude

# Check plans in database:
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, name, status FROM plans WHERE project_id='claude';"
```

**If database and files disagree: Trust the database.**

## Summary

| Aspect | Location | Authority |
|--------|----------|-----------|
| Plans, Waves, Tasks | SQLite DB | ✓ Authoritative |
| Plan execution state | SQLite DB | ✓ Authoritative |
| Token usage | SQLite DB | ✓ Authoritative |
| Human docs | .md files | Reference only |
| Dashboard source | API → DB | ✓ Read from DB |
