# Plan Database Schema Reference

**Database Location**: `$HOME/.claude/data/dashboard.db`

This document provides the authoritative schema for the planning system database to prevent DB-access hallucinations.

## Core Tables

### plans
Primary plan tracking table.

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | INTEGER | PRIMARY KEY | AUTO |
| project_id | TEXT | NOT NULL, FK→projects(id) | - |
| name | TEXT | NOT NULL | - |
| source_file | TEXT | - | NULL |
| is_master | BOOLEAN | - | 0 |
| parent_plan_id | INTEGER | FK→plans(id) | NULL |
| status | TEXT | NOT NULL, CHECK(status IN ('todo', 'doing', 'done')) | 'todo' |
| tasks_total | INTEGER | - | 0 |
| tasks_done | INTEGER | - | 0 |
| created_at | DATETIME | - | CURRENT_TIMESTAMP |
| started_at | DATETIME | - | NULL |
| completed_at | DATETIME | - | NULL |
| validated_at | DATETIME | - | NULL |
| validated_by | TEXT | - | NULL |
| markdown_dir | TEXT | - | NULL |
| archived_at | DATETIME | - | NULL |
| archived_path | TEXT | - | NULL |
| updated_at | DATETIME | - | NULL |
| git_clean_at_closure | INTEGER | - | NULL |
| parallel_mode | TEXT | - | 'standard' |
| markdown_path | TEXT | - | NULL |
| worktree_path | TEXT | - | NULL |
| execution_host | TEXT | - | NULL |
| description | TEXT | - | NULL |
| human_summary | TEXT | - | NULL |
| lines_added | INTEGER | - | NULL |
| lines_removed | INTEGER | - | NULL |

**UNIQUE**: (project_id, name)

### waves
Wave groupings within plans.

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | INTEGER | PRIMARY KEY | AUTO |
| project_id | TEXT | NOT NULL, FK→projects(id) | - |
| wave_id | TEXT | NOT NULL | - |
| name | TEXT | NOT NULL | - |
| status | TEXT | NOT NULL, CHECK(status IN ('pending', 'in_progress', 'done', 'blocked')) | - |
| assignee | TEXT | - | NULL |
| tasks_done | INTEGER | - | 0 |
| tasks_total | INTEGER | - | 0 |
| started_at | DATETIME | - | NULL |
| completed_at | DATETIME | - | NULL |
| plan_id | INTEGER | FK→plans(id) | NULL |
| position | INTEGER | - | 0 |
| planned_start | DATETIME | - | NULL |
| planned_end | DATETIME | - | NULL |
| depends_on | TEXT | - | NULL |
| estimated_hours | INTEGER | - | 8 |
| markdown_path | TEXT | - | NULL |
| precondition | TEXT | - | NULL |

**Trigger**: `wave_auto_complete` - Auto-completes wave when tasks_done = tasks_total

### tasks
Individual task tracking (references waves via wave_id_fk).

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | INTEGER | PRIMARY KEY | AUTO |
| project_id | TEXT | NOT NULL, FK→projects(id) | - |
| wave_id | TEXT | NOT NULL | - |
| task_id | TEXT | NOT NULL | - |
| title | TEXT | NOT NULL | - |
| status | TEXT | NOT NULL, CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'skipped')) | - |
| assignee | TEXT | - | NULL |
| priority | TEXT | CHECK(priority IN ('P0', 'P1', 'P2', 'P3')) | NULL |
| type | TEXT | CHECK(type IN ('bug', 'feature', 'chore', 'doc', 'test')) | NULL |
| duration_minutes | INTEGER | - | NULL |
| started_at | DATETIME | - | NULL |
| completed_at | DATETIME | - | NULL |
| tokens | INTEGER | - | 0 |
| validated_at | DATETIME | - | NULL |
| validated_by | TEXT | - | NULL |
| markdown_path | TEXT | - | NULL |
| executor_session_id | TEXT | - | NULL |
| executor_started_at | DATETIME | - | NULL |
| executor_last_activity | DATETIME | - | NULL |
| executor_status | TEXT | CHECK(executor_status IN ('idle', 'running', 'paused', 'completed', 'failed')) | NULL |
| notes | TEXT | - | NULL |
| wave_id_fk | INTEGER | FK→waves(id) | NULL |
| plan_id | INTEGER | FK→plans(id) | NULL |
| test_criteria | TEXT | - | NULL |
| model | TEXT | - | 'haiku' |
| description | TEXT | - | NULL |
| output_data | TEXT | - | NULL |
| executor_agent | TEXT | - | NULL |
| executor_host | TEXT | - | NULL |
| effort_level | INTEGER | CHECK(effort_level IN (1, 2, 3)) | 1 |
| validation_report | TEXT | - | NULL |

**Triggers**:
- `task_done_counter` - Increments waves.tasks_done and plans.tasks_done on status→done
- `task_undone_counter` - Decrements counters on done→other status

## CHECK Constraints (Enums)

### plans.status
```sql
CHECK(status IN ('todo', 'doing', 'done'))
```

### waves.status
```sql
CHECK(status IN ('pending', 'in_progress', 'done', 'blocked'))
```

### tasks.status
```sql
CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'skipped'))
```

### tasks.priority
```sql
CHECK(priority IN ('P0', 'P1', 'P2', 'P3'))
```

### tasks.type
```sql
CHECK(type IN ('bug', 'feature', 'chore', 'doc', 'test'))
```

### tasks.executor_status
```sql
CHECK(executor_status IN ('idle', 'running', 'paused', 'completed', 'failed'))
```

### tasks.effort_level
```sql
CHECK(effort_level IN (1, 2, 3))
```

## Foreign Keys

| From | Column | To | On Delete |
|------|--------|-----|-----------|
| plans | project_id | projects(id) | CASCADE |
| plans | parent_plan_id | plans(id) | SET NULL |
| waves | project_id | projects(id) | CASCADE |
| tasks | project_id | projects(id) | CASCADE |
| tasks | plan_id | plans(id) | - |
| tasks | wave_id_fk | waves(id) | - |

**Critical**: tasks.wave_id_fk is the INTEGER FK to waves(id), NOT tasks.wave_id (which is TEXT)

## Common Queries

### Get plan with tasks
```sql
SELECT p.*, COUNT(t.id) as task_count
FROM plans p
LEFT JOIN tasks t ON t.plan_id = p.id
WHERE p.id = ?
GROUP BY p.id;
```

### Get pending tasks for plan
```sql
SELECT t.*
FROM tasks t
JOIN waves w ON t.wave_id_fk = w.id
WHERE t.plan_id = ? AND t.status = 'pending'
ORDER BY w.position, t.id;
```

### Update task status
```sql
UPDATE tasks
SET status = ?, completed_at = datetime('now')
WHERE id = ?;
```

### Get plan context (full hierarchy)
```sql
SELECT p.id, p.name, p.status, p.worktree_path,
       w.id as wave_db_id, w.wave_id, w.name as wave_name,
       t.id as task_db_id, t.task_id, t.title, t.status as task_status
FROM plans p
LEFT JOIN waves w ON w.plan_id = p.id
LEFT JOIN tasks t ON t.wave_id_fk = w.id
WHERE p.id = ?
ORDER BY w.position, t.id;
```

## CLI Command Mapping

| Command | SQL Operation |
|---------|---------------|
| `plan-db.sh list <pid>` | SELECT * FROM plans WHERE project_id = ? |
| `plan-db.sh start <id>` | UPDATE plans SET status='doing', started_at=now() WHERE id=? |
| `plan-db.sh complete <id>` | UPDATE plans SET status='done', completed_at=now() WHERE id=? |
| `plan-db.sh update-task <id> <status>` | UPDATE tasks SET status=? WHERE id=? |
| `plan-db.sh get-worktree <id>` | SELECT worktree_path FROM plans WHERE id=? |
| `plan-db.sh json <id>` | Full plan export with waves/tasks as JSON |
| `plan-db.sh sync <id>` | Recalculate tasks_done/tasks_total counters |

**Important**: Use `plan-db-safe.sh update-task <id> done` for automatic Thor validation

## Indexes

- `idx_plans_project` ON plans(project_id, status)
- `idx_waves_plan` ON waves(plan_id, position)
- `idx_tasks_plan_status` ON tasks(plan_id, status, wave_id_fk)
- `idx_tasks_executor_active` ON tasks(executor_status) WHERE executor_status IN ('running', 'paused')

## Notes

- **wave_id_fk** is the INTEGER foreign key to waves(id) - do not confuse with TEXT wave_id
- Triggers automatically maintain task counters - manual updates may cause drift
- Always use plan-db-safe.sh for marking tasks done to ensure Thor validation
- Database schema version tracked in schema_metadata table
