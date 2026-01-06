# Planner Architecture - Source of Truth

**Last Updated**: 5 January 2026
**Status**: FIXED - System uses Database as Single Source of Truth

---

## Architecture Overview

### Single Source of Truth: SQLite Database

```
~/.claude/data/dashboard.db
├── projects
├── plans
├── waves
├── tasks
├── token_usage
└── plan_versions
```

**ALL** plan data flows through the database:
- Planner creates plans in database (not .md files)
- Executor reads/writes tasks to database
- Dashboard reads from database API endpoints
- Thor validates against database state

---

## File Roles (CLARIFIED)

### ❌ Deprecated/Archived

| File | Role | Status |
|------|------|--------|
| `plan.json` | Snapshot (unused) | **ARCHIVED** - Not used by dashboard |
| `init-db-v3.sql` | Old schema (wrong) | **ARCHIVED** - Don't use |

### ✓ Reference/Documentation Only

| File | Role | Status |
|------|------|--------|
| `~/.claude/plans/DashboardAuditFixPlan.md` | Plan documentation | For human reference, **not authoritative** |
| `~/.claude/plans/registry.json` | Project registry | Read-only fallback for projects list |

### ✓ Authoritative

| File/System | Role | Status |
|-------|------|--------|
| **SQLite database** | **Single source of truth** | **LIVE - Use this** |
| plan-db.sh | CLI to manage database | **USE THIS** |
| dashboard API | Reads from database | **Data flows from DB** |

---

## Workflow (CORRECT)

### Creating a Plan

**DON'T**: Create .md file and hope it syncs
**DO**: Use plan-db.sh to create in database

```bash
# 1. Create in database
PLAN_ID=$(~/.claude/scripts/plan-db.sh create "my-project" "MyPlanName")

# 2. Get plan_id from output
echo $PLAN_ID  # e.g., 11

# 3. Add waves to database
WAVE_ID=$(~/.claude/scripts/plan-db.sh add-wave $PLAN_ID "W1" "Phase 1")

# 4. Add tasks to database
TASK_ID=$(~/.claude/scripts/plan-db.sh add-task $WAVE_ID T1-01 "Do X" P1 feature)

# 5. Optional: Create .md file as documentation (not authoritative)
# - This is HUMAN REFERENCE ONLY
# - Dashboard does NOT read this file
# - Database is what matters
```

### Dashboard Reading Plans

```
Dashboard (HTML/JS)
    ↓
Server API (/api/plans/:project, /api/kanban, etc.)
    ↓
SQLite Database (query)
    ↓
Waves/Tasks data returned to UI
```

**plan.json is NOT in this flow** ❌

### Updating Plans

```bash
# Get numeric DB IDs (use FK, not wave_id string!)
WAVE_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM waves WHERE plan_id=$PLAN_ID LIMIT 1;")

TASK_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM tasks WHERE wave_id_fk=$WAVE_ID AND task_id='T1-01';")

# Update via plan-db.sh (which updates database)
~/.claude/scripts/plan-db.sh update-task $TASK_ID in_progress ""
~/.claude/scripts/plan-db.sh update-task $TASK_ID done "Summary"

# Database is updated automatically ✓
```

---

## Database Schema (Authoritative)

### plans
```sql
id              INTEGER PRIMARY KEY  -- Use for plan_id
project_id      TEXT                 -- e.g., "claude"
name            TEXT                 -- Plan name
is_master       BOOLEAN              -- 0/1
status          TEXT                 -- todo, doing, done, blocked
tasks_done      INTEGER              -- Counter (auto-synced from waves)
tasks_total     INTEGER              -- Counter (auto-synced from waves)
```

### waves
```sql
id              INTEGER PRIMARY KEY  -- Use for db_wave_id (wave_id_fk)
project_id      TEXT
wave_id         TEXT                 -- e.g., "W1-DataIntegration" (descriptive!)
plan_id         INTEGER              -- Reference to plans.id
name            TEXT                 -- Wave name
status          TEXT                 -- pending, in_progress, done, blocked
tasks_done      INTEGER              -- Counter (auto-synced from tasks)
tasks_total     INTEGER              -- Counter (auto-synced from tasks)
```

### tasks
```sql
id              INTEGER PRIMARY KEY  -- Use for db_task_id
project_id      TEXT
wave_id         TEXT                 -- Legacy, for display only
wave_id_fk      INTEGER              -- FK to waves.id (USE THIS for queries!)
plan_id         INTEGER              -- FK to plans.id (USE THIS for queries!)
task_id         TEXT                 -- e.g., "T1-01" (text code)
title           TEXT
status          TEXT                 -- pending, in_progress, done, blocked, skipped
priority        TEXT                 -- P0, P1, P2, P3
type            TEXT                 -- feature, bug, chore, doc, test
started_at      DATETIME
completed_at    DATETIME
tokens          INTEGER
validated_at    DATETIME
validated_by    TEXT
notes           TEXT
executor_status TEXT                 -- idle, running, paused, completed, failed
```

---

## Important Rules

### ✓ DO

1. **Use plan-db.sh for all plan operations**
   ```bash
   plan-db.sh create
   plan-db.sh add-wave
   plan-db.sh add-task
   plan-db.sh update-task
   plan-db.sh update-wave
   plan-db.sh validate
   ```

2. **Save numeric DB IDs when creating**
   ```bash
   PLAN_ID=$(plan-db.sh create ...)
   WAVE_ID=$(plan-db.sh add-wave ...)
   TASK_ID=$(plan-db.sh add-task ...)
   ```

3. **Use database queries to get IDs when needed**
    ```bash
    # Use wave_id_fk (numeric) for task lookups
    TASK_ID=$(sqlite3 ~/.claude/data/dashboard.db \
      "SELECT id FROM tasks WHERE wave_id_fk=$WAVE_ID AND task_id='T1-01';")
    ```

4. **Create .md documentation files for human reference** (optional)
   - Keep them in sync with database manually
   - Dashboard does NOT read these files
   - Only for documentation purposes

### ❌ DON'T

1. **Don't create plan.json or expect it to work**
   - plan.json is NOT used by dashboard
   - It's archived as reference only
   - Database is the source of truth

2. **Don't manually edit database** (unless you know what you're doing)
   - Use plan-db.sh CLI instead
   - It handles timestamps, counters, validations

3. **Don't assume .md files sync to database**
   - They don't sync automatically
   - Database is independent from documentation files
   - Always use plan-db.sh for database operations

4. **Don't forget numeric DB IDs**
   - Markdown codes ("W1", "T1-01") are for reference
   - plan-db.sh and SQL queries use numeric IDs
   - Save DB IDs when creating plans/waves/tasks

---

## Verification

### Check if database is authoritative

```bash
# This is what dashboard reads:
curl http://localhost:31415/api/plans/claude

# This returns data from SQLite, not from plan.json
```

### Check current plans in database

```bash
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, name, status, tasks_done, tasks_total FROM plans WHERE project_id='claude';"
```

### If plan.json and database differ

**Database wins.** Always. Delete/archive plan.json.

---

## Summary

| Aspect | Location | Authority |
|--------|----------|-----------|
| **Plans, Waves, Tasks** | SQLite database | ✓ Authoritative |
| **Plan execution state** | SQLite database | ✓ Authoritative |
| **Token usage tracking** | SQLite database | ✓ Authoritative |
| **Human documentation** | .md files (optional) | Reference only |
| **Dashboard data source** | API → Database | ✓ Read from DB |

**If database and files disagree: Trust the database.**
