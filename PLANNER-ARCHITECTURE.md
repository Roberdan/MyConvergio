<!-- v3.0.0 | 15 Feb 2026 | Phase 2 token optimization -->

# Planner Architecture

**DB**: `~/.claude/data/dashboard.db` | **CLI**: `plan-db.sh`

## Data Flow

```
dashboard.db → plan-db.sh → Planner/Executor/Thor → Dashboard API
```

| Type          | Files                      | Authority |
| ------------- | -------------------------- | --------- |
| Authoritative | SQLite DB, plan-db.sh, API | Use this  |
| Reference     | .md plan docs              | Read-only |
| Deprecated    | plan.json, init-db-v3.sql  | Don't use |

## Schema

```sql
-- plans
id INTEGER PK, project_id TEXT, name TEXT, is_master BOOLEAN,
status TEXT, tasks_done INTEGER, tasks_total INTEGER

-- waves
id INTEGER PK, project_id TEXT, wave_id TEXT, plan_id INTEGER FK,
name TEXT, status TEXT, tasks_done INTEGER, tasks_total INTEGER

-- tasks
id INTEGER PK, project_id TEXT, wave_id_fk INTEGER FK (USE THIS!),
plan_id INTEGER FK, task_id TEXT, title TEXT, status TEXT,
priority TEXT, type TEXT, model TEXT,
effort_level INTEGER (1=trivial, 2=standard, 3=complex),
started_at, completed_at, tokens INTEGER,
validated_at, validated_by TEXT, notes TEXT,
executor_status TEXT, executor_agent TEXT, output_data TEXT
```

## Workflow

```bash
PLAN_ID=$(plan-db.sh create "project" "PlanName")
WAVE_ID=$(plan-db.sh add-wave $PLAN_ID "W1" "Phase 1")
TASK_ID=$(plan-db.sh add-task $WAVE_ID T1-01 "Task" P1 feature)

# Use wave_id_fk (numeric), not wave_id string
WAVE_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM waves WHERE plan_id=$PLAN_ID LIMIT 1;")
TASK_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM tasks WHERE wave_id_fk=$WAVE_ID AND task_id='T1-01';")

plan-db-safe.sh update-task $TASK_ID done "Summary"  # auto-validates
```

## Rules

**DO**: Use plan-db.sh for all ops | Save numeric DB IDs | Use `wave_id_fk` for lookups
**DON'T**: Create/rely on plan.json | Manually edit DB | Assume .md syncs to DB

## Verification

```bash
curl http://localhost:31415/api/plans/claude    # Dashboard
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, name, status FROM plans WHERE project_id='claude';"
```

**DB vs files conflict**: Trust database.
