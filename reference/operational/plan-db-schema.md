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
| status | TEXT | NOT NULL, CHECK(status IN ('todo', 'doing', 'done', 'cancelled')) | 'todo' |
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
| constraints_json | TEXT | - | NULL |
| cancelled_at | DATETIME | - | NULL |
| cancelled_reason | TEXT | - | NULL |

**UNIQUE**: (project_id, name)

### waves
Wave groupings within plans.

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | INTEGER | PRIMARY KEY | AUTO |
| project_id | TEXT | NOT NULL, FK→projects(id) | - |
| wave_id | TEXT | NOT NULL | - |
| name | TEXT | NOT NULL | - |
| status | TEXT | NOT NULL, CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'merging', 'cancelled')) | - |
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
| worktree_path | TEXT | - | NULL |
| branch_name | TEXT | - | NULL |
| pr_number | INTEGER | - | NULL |
| pr_url | TEXT | - | NULL |
| cancelled_at | DATETIME | - | NULL |
| cancelled_reason | TEXT | - | NULL |
| merge_mode | TEXT | - | 'sync' |
| theme | TEXT | - | NULL |

**Trigger**: `wave_auto_complete` - Transitions wave to 'merging' when tasks_done = tasks_total

### tasks
Individual task tracking (references waves via wave_id_fk).

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | INTEGER | PRIMARY KEY | AUTO |
| project_id | TEXT | NOT NULL, FK→projects(id) | - |
| wave_id | TEXT | NOT NULL | - |
| task_id | TEXT | NOT NULL | - |
| title | TEXT | NOT NULL | - |
| status | TEXT | NOT NULL, CHECK(status IN ('pending', 'in_progress', 'submitted', 'done', 'blocked', 'skipped', 'cancelled')) | - |
| assignee | TEXT | - | NULL |
| priority | TEXT | CHECK(priority IN ('P0', 'P1', 'P2', 'P3')) | NULL |
| type | TEXT | CHECK(type IN ('bug', 'feature', 'fix', 'refactor', 'test', 'config', 'documentation', 'chore', 'doc')) | NULL |
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
| cancelled_at | DATETIME | - | NULL |
| cancelled_reason | TEXT | - | NULL |
| privacy_required | BOOLEAN | - | 0 |

**Triggers**:
- `enforce_thor_done` - BLOCKS status→done unless OLD.status='submitted' AND validated_by IN ('thor','thor-quality-assurance-guardian','thor-per-wave','forced-admin')
- `task_done_counter` - Increments waves.tasks_done and plans.tasks_done on status→done
- `task_undone_counter` - Decrements counters on done→other status

## CHECK Constraints (Enums)

### plans.status
```sql
CHECK(status IN ('todo', 'doing', 'done', 'cancelled'))
```

### waves.status
```sql
CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'merging', 'cancelled'))
```

### tasks.status
```sql
CHECK(status IN ('pending', 'in_progress', 'submitted', 'done', 'blocked', 'skipped', 'cancelled'))
```

### tasks.priority
```sql
CHECK(priority IN ('P0', 'P1', 'P2', 'P3'))
```

### tasks.type
```sql
CHECK(type IN ('bug', 'feature', 'fix', 'refactor', 'test', 'config', 'documentation', 'chore', 'doc'))
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

## CLI Command Reference (Authoritative)

### CRUD

| Command | Purpose |
|---------|---------|
| `list <project_id>` | List plans for project |
| `create <project_id> <name> [opts]` | Create plan. Opts: `--source-file`, `--markdown-path`, `--auto-worktree` |
| `start <plan_id>` | Set plan status to 'doing' |
| `add-wave <plan_id> <id> <name> [opts]` | Add wave. Opts: `--depends-on`, `--estimated-hours` |
| `add-task <wave_id> <id> <title> [opts]` | Add task. Opts: `P0-P3`, type, `--description`, `--test-criteria` |
| `update-task <task_id> <status> [notes]` | Update task status. **Blocks done/submitted** — use `plan-db-safe.sh` |
| `update-wave <wave_id> <status>` | Update wave status |
| `update-desc <plan_id> <desc>` | Set plan description (agent-facing) |
| `update-summary <plan_id> <text>` | Set human summary (dashboard) |
| `complete <plan_id>` | Mark plan done |
| `cancel <plan_id> [reason]` | Cancel plan (cascades to tasks/waves) |
| `cancel-wave <wave_db_id> [reason]` | Cancel wave (cascades to tasks) |
| `cancel-task <task_db_id> [reason]` | Cancel single task |
| `get-worktree <plan_id>` | Get worktree path |
| `set-worktree <plan_id> <path>` | Set worktree path |
| `get-wave-worktree <wave_db_id>` | Get wave worktree path |
| `set-wave-worktree <wave_db_id> <path>` | Set wave worktree path |

### Validation

| Command | Purpose |
|---------|---------|
| `check-readiness <plan_id>` | Block if metadata/process gates missing |
| `approve <plan_id> [notes]` | Record user approval (requires review+business+challenger) |
| `evaluate-wave <wave_db_id>` | Check wave preconditions (JSON) |
| `validate <plan_id> [by]` | Thor validates plan (counters, orphans, bulk) |
| `validate-task <task_id> [plan_id] [by]` | Per-task Thor gate |
| `validate-wave <wave_db_id> [by]` | Validate all done tasks in wave |
| `validate-fxx <plan_id>` | Validate F-xx from markdown |
| `drift-check <plan_id>` | Plan staleness vs main (JSON) |
| `conflict-check <plan_id>` | Cross-plan file overlap detection |
| `rebase-plan <plan_id>` | Rebase worktree onto latest main |
| `sync <plan_id>` | Fix out-of-sync counters |

### Cluster

| Command | Purpose |
|---------|---------|
| `claim <plan_id> [--force]` | Claim plan for this host |
| `release <plan_id>` | Release plan from this host |
| `heartbeat` | Write heartbeat for this host |
| `remote-status [project_id]` | Remote host status |
| `cluster-status` | Unified view of all hosts |
| `cluster-tasks` | In-progress tasks across hosts |
| `token-report` | Per-project token/cost by host |
| `autosync [start\|stop\|status]` | Auto-sync daemon |
| `where [plan_id]` | Show execution host |

### Bulk & Display

| Command | Purpose |
|---------|---------|
| `import <plan_id> <spec.json\|yaml>` | Bulk import waves+tasks |
| `render <plan_id>` | Generate markdown from DB |
| `get-context <plan_id>` | Full plan+tasks JSON (1 call) |
| `kanban` / `kanban-json` | Kanban board (text/JSON) |
| `status [project_id]` | Quick status |
| `json <plan_id>` | Plan as JSON |
| `execution-tree <plan_id>` | Execution tree with statuses |

### Knowledge Base

| Command | Purpose |
|---------|---------|
| `kb-write <domain> <title> <content>` | Write to KB. Opts: `--tags`, `--confidence`, `--source-type`, `--source-ref`, `--project-id` |
| `kb-search <query>` | Search KB. Opts: `--domain`, `--limit` |
| `kb-hit <id>` | Record KB hit |
| `skill-earn <name> <domain> <content>` | Earn skill. Opts: `--confidence low\|medium\|high` |
| `skill-list` | List skills. Opts: `--domain`, `--min-confidence` |
| `skill-promote <name>` | Promote to SKILL.md |
| `skill-bump <name>` | Increase confidence |

### Concurrency

| Command | Purpose |
|---------|---------|
| `lock acquire\|release\|check\|list\|cleanup` | File-level locking |
| `stale-check snapshot\|check\|diff\|cleanup` | Stale context detection |
| `wave-overlap check-wave\|check-plan\|check-spec` | Intra-wave overlap |
| `merge-queue enqueue\|process\|status\|cancel` | Sequential merge queue |

### Intelligence

| Command | Purpose |
|---------|---------|
| `add-learning <plan> <cat> <sev> <title>` | Record learning. Opts: `--detail`, `--task-id`, `--actionable` |
| `get-learnings <plan>` | Get learnings. Opts: `--category`, `--severity`, `--actionable` |
| `add-review <plan> <reviewer> <verdict>` | Record review. Opts: `--fxx-score`, `--completeness` |
| `add-assessment <plan>` | Business assessment. Opts: `--effort-days`, `--complexity`, `--value`, `--roi` |
| `add-actuals <plan>` | Record actuals. Opts: `--tokens`, `--cost`, `--ai-minutes`, `--total-tasks` |
| `estimate-tokens <plan> <scope> <scope_id> <tokens>` | Token estimate. Opts: `--cost`, `--model` |
| `calibrate-estimates [model]` | Accuracy stats by model |

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
