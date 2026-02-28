#!/usr/bin/env bash
set -euo pipefail
# migrate-v9-cancellation.sh - Add cancelled status to plans, tasks, waves
# Adds: cancelled_at, cancelled_reason columns
# Rebuilds CHECK constraints to include 'cancelled'
# Idempotent: checks columns/constraints exist before modifying
# Version: 1.0.0
set -euo pipefail

DB_FILE="${DB_FILE:-${CLAUDE_HOME:-$HOME/.claude}/data/dashboard.db}"

echo "=== Database Migration v9: Cancellation Support ==="
echo "Database: $DB_FILE"

if [[ ! -f "$DB_FILE" ]]; then
	echo "ERROR: Database not found: $DB_FILE" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------
BACKUP_FILE="$HOME/.claude/data/dashboard.db.bak-v9-$(date +%s)"
echo ""
echo "Creating backup: $BACKUP_FILE"
cp "$DB_FILE" "$BACKUP_FILE"
echo "  [OK] Backup created"

# ---------------------------------------------------------------------------
# Idempotency checks
# ---------------------------------------------------------------------------
echo ""
echo "Checking current schema state..."

# Plans: check columns + CHECK constraint
PLANS_CANCELLED_AT=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('plans') WHERE name='cancelled_at';")
PLANS_CANCELLED_REASON=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('plans') WHERE name='cancelled_reason';")
PLANS_DDL=$(sqlite3 "$DB_FILE" \
	"SELECT sql FROM sqlite_master WHERE type='table' AND name='plans';")
PLANS_HAS_CANCELLED=0
echo "$PLANS_DDL" | grep -q "'cancelled'" && PLANS_HAS_CANCELLED=1

# Tasks: check columns + CHECK constraint
TASKS_CANCELLED_AT=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('tasks') WHERE name='cancelled_at';")
TASKS_CANCELLED_REASON=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('tasks') WHERE name='cancelled_reason';")
TASKS_DDL=$(sqlite3 "$DB_FILE" \
	"SELECT sql FROM sqlite_master WHERE type='table' AND name='tasks';")
TASKS_HAS_CANCELLED=0
echo "$TASKS_DDL" | grep -q "'cancelled'" && TASKS_HAS_CANCELLED=1

# Waves: check columns + CHECK constraint
WAVES_CANCELLED_AT=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('waves') WHERE name='cancelled_at';")
WAVES_CANCELLED_REASON=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('waves') WHERE name='cancelled_reason';")
WAVES_DDL=$(sqlite3 "$DB_FILE" \
	"SELECT sql FROM sqlite_master WHERE type='table' AND name='waves';")
WAVES_HAS_CANCELLED=0
echo "$WAVES_DDL" | grep -q "'cancelled'" && WAVES_HAS_CANCELLED=1

echo "  Plans:  cancelled_at=$([[ $PLANS_CANCELLED_AT -eq 1 ]] && echo EXISTS || echo MISSING)  cancelled_reason=$([[ $PLANS_CANCELLED_REASON -eq 1 ]] && echo EXISTS || echo MISSING)  CHECK=$([[ $PLANS_HAS_CANCELLED -eq 1 ]] && echo YES || echo NO)"
echo "  Tasks:  cancelled_at=$([[ $TASKS_CANCELLED_AT -eq 1 ]] && echo EXISTS || echo MISSING)  cancelled_reason=$([[ $TASKS_CANCELLED_REASON -eq 1 ]] && echo EXISTS || echo MISSING)  CHECK=$([[ $TASKS_HAS_CANCELLED -eq 1 ]] && echo YES || echo NO)"
echo "  Waves:  cancelled_at=$([[ $WAVES_CANCELLED_AT -eq 1 ]] && echo EXISTS || echo MISSING)  cancelled_reason=$([[ $WAVES_CANCELLED_REASON -eq 1 ]] && echo EXISTS || echo MISSING)  CHECK=$([[ $WAVES_HAS_CANCELLED -eq 1 ]] && echo YES || echo NO)"

# If fully migrated, skip
if [[ $PLANS_CANCELLED_AT -eq 1 && $PLANS_CANCELLED_REASON -eq 1 && $PLANS_HAS_CANCELLED -eq 1 &&
	$TASKS_CANCELLED_AT -eq 1 && $TASKS_CANCELLED_REASON -eq 1 && $TASKS_HAS_CANCELLED -eq 1 &&
	$WAVES_CANCELLED_AT -eq 1 && $WAVES_CANCELLED_REASON -eq 1 && $WAVES_HAS_CANCELLED -eq 1 ]]; then
	echo ""
	echo "=== Already fully migrated. Nothing to do. ==="
	exit 0
fi

# ---------------------------------------------------------------------------
# Add missing columns (safe: check before ALTER)
# ---------------------------------------------------------------------------
echo ""
echo "Adding missing columns..."

for table in plans tasks waves; do
	for col in cancelled_at cancelled_reason; do
		exists=$(sqlite3 "$DB_FILE" \
			"SELECT COUNT(*) FROM pragma_table_info('$table') WHERE name='$col';")
		if [[ $exists -eq 0 ]]; then
			local_type="TEXT"
			[[ "$col" == "cancelled_at" ]] && local_type="DATETIME"
			sqlite3 "$DB_FILE" "ALTER TABLE $table ADD COLUMN $col $local_type;"
			echo "  [OK] $table.$col added"
		else
			echo "  [SKIP] $table.$col already exists"
		fi
	done
done

# ---------------------------------------------------------------------------
# Rebuild plans table CHECK constraint to include 'cancelled'
# ---------------------------------------------------------------------------
if [[ $PLANS_HAS_CANCELLED -eq 0 ]]; then
	echo ""
	echo "Rebuilding plans table to add 'cancelled' to CHECK constraint..."

	# Get all column names dynamically
	PLANS_COLS=$(sqlite3 "$DB_FILE" "SELECT group_concat(name, ', ') FROM pragma_table_info('plans');")

	sqlite3 "$DB_FILE" <<'SQL'
PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;

CREATE TABLE plans_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  name TEXT NOT NULL,
  source_file TEXT,
  is_master BOOLEAN DEFAULT 0,
  parent_plan_id INTEGER,
  status TEXT NOT NULL DEFAULT 'todo' CHECK(status IN ('todo', 'doing', 'done', 'cancelled')),
  tasks_total INTEGER DEFAULT 0,
  tasks_done INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  started_at DATETIME,
  completed_at DATETIME,
  validated_at DATETIME,
  validated_by TEXT,
  markdown_dir TEXT,
  archived_at DATETIME,
  archived_path TEXT,
  updated_at DATETIME,
  git_clean_at_closure INTEGER DEFAULT NULL,
  parallel_mode TEXT DEFAULT 'standard',
  markdown_path TEXT,
  worktree_path TEXT,
  execution_host TEXT DEFAULT NULL,
  description TEXT DEFAULT NULL,
  human_summary TEXT DEFAULT NULL,
  lines_added INTEGER DEFAULT NULL,
  lines_removed INTEGER DEFAULT NULL,
  constraints_json TEXT DEFAULT NULL,
  cancelled_at DATETIME,
  cancelled_reason TEXT,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_plan_id) REFERENCES plans(id) ON DELETE SET NULL,
  UNIQUE(project_id, name)
);

INSERT INTO plans_new (id, project_id, name, source_file, is_master, parent_plan_id,
  status, tasks_total, tasks_done, created_at, started_at, completed_at,
  validated_at, validated_by, markdown_dir, archived_at, archived_path,
  updated_at, git_clean_at_closure, parallel_mode, markdown_path, worktree_path,
  execution_host, description, human_summary, lines_added, lines_removed, constraints_json,
  cancelled_at, cancelled_reason)
SELECT id, project_id, name, source_file, is_master, parent_plan_id,
  status, tasks_total, tasks_done, created_at, started_at, completed_at,
  validated_at, validated_by, markdown_dir, archived_at, archived_path,
  updated_at, git_clean_at_closure, parallel_mode, markdown_path, worktree_path,
  execution_host, description, human_summary, lines_added, lines_removed, constraints_json,
  cancelled_at, cancelled_reason
FROM plans;

DROP TABLE plans;
ALTER TABLE plans_new RENAME TO plans;

-- Recreate indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_plans_unique ON plans(project_id, name);
CREATE INDEX IF NOT EXISTS idx_plans_status ON plans(status);

COMMIT;
PRAGMA foreign_keys = ON;
SQL
	echo "  [OK] plans table rebuilt with 'cancelled' in CHECK"
else
	echo ""
	echo "  [SKIP] plans CHECK already includes 'cancelled'"
fi

# ---------------------------------------------------------------------------
# Rebuild tasks table CHECK constraint to include 'cancelled'
# ---------------------------------------------------------------------------
if [[ $TASKS_HAS_CANCELLED -eq 0 ]]; then
	echo ""
	echo "Rebuilding tasks table to add 'cancelled' to CHECK constraint..."

	sqlite3 "$DB_FILE" <<'SQL'
PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;

CREATE TABLE tasks_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id TEXT NOT NULL,
    wave_id TEXT NOT NULL,
    task_id TEXT NOT NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'skipped', 'cancelled')),
    assignee TEXT,
    priority TEXT CHECK(priority IN ('P0', 'P1', 'P2', 'P3')),
    type TEXT CHECK(type IN ('bug', 'feature', 'fix', 'refactor', 'test', 'config', 'documentation', 'chore', 'doc')),
    duration_minutes INTEGER,
    started_at DATETIME,
    completed_at DATETIME,
    tokens INTEGER DEFAULT 0,
    validated_at DATETIME,
    validated_by TEXT,
    markdown_path TEXT,
    executor_session_id TEXT,
    executor_started_at DATETIME,
    executor_last_activity DATETIME,
    executor_status TEXT CHECK(executor_status IN ('idle', 'running', 'paused', 'completed', 'failed')),
    notes TEXT,
    wave_id_fk INTEGER,
    plan_id INTEGER REFERENCES plans(id),
    test_criteria TEXT,
    model TEXT DEFAULT 'haiku',
    description TEXT,
    output_data TEXT DEFAULT NULL,
    executor_agent TEXT DEFAULT NULL,
    executor_host TEXT DEFAULT NULL,
    effort_level INTEGER DEFAULT 1 CHECK(effort_level IN (1, 2, 3)),
    validation_report TEXT,
    cancelled_at DATETIME,
    cancelled_reason TEXT,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

INSERT INTO tasks_new SELECT
    id, project_id, wave_id, task_id, title, status, assignee, priority, type,
    duration_minutes, started_at, completed_at, tokens, validated_at, validated_by,
    markdown_path, executor_session_id, executor_started_at, executor_last_activity,
    executor_status, notes, wave_id_fk, plan_id, test_criteria, model, description,
    output_data, executor_agent, executor_host, effort_level, validation_report,
    cancelled_at, cancelled_reason
FROM tasks;

-- Preserve triggers that reference tasks
DROP TRIGGER IF EXISTS task_done_counter;

DROP TABLE tasks;
ALTER TABLE tasks_new RENAME TO tasks;

-- Recreate indexes
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id, wave_id, task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_wave_fk ON tasks(wave_id_fk);
CREATE INDEX IF NOT EXISTS idx_tasks_plan ON tasks(plan_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);

-- Recreate task_done_counter trigger
CREATE TRIGGER task_done_counter
AFTER UPDATE OF status ON tasks
WHEN NEW.status = 'done' AND OLD.status != 'done'
BEGIN
    UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = NEW.wave_id_fk;
    UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = NEW.plan_id;
END;

COMMIT;
PRAGMA foreign_keys = ON;
SQL
	echo "  [OK] tasks table rebuilt with 'cancelled' in CHECK"
else
	echo ""
	echo "  [SKIP] tasks CHECK already includes 'cancelled'"
fi

# ---------------------------------------------------------------------------
# Rebuild waves table CHECK constraint to include 'cancelled'
# ---------------------------------------------------------------------------
if [[ $WAVES_HAS_CANCELLED -eq 0 ]]; then
	echo ""
	echo "Rebuilding waves table to add 'cancelled' to CHECK constraint..."

	sqlite3 "$DB_FILE" <<'SQL'
PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;

CREATE TABLE waves_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id TEXT NOT NULL,
    wave_id TEXT NOT NULL,
    name TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'merging', 'cancelled')),
    assignee TEXT,
    tasks_done INTEGER DEFAULT 0,
    tasks_total INTEGER DEFAULT 0,
    started_at DATETIME,
    completed_at DATETIME,
    plan_id INTEGER,
    position INTEGER DEFAULT 0,
    planned_start DATETIME,
    planned_end DATETIME,
    depends_on TEXT,
    estimated_hours INTEGER DEFAULT 8,
    markdown_path TEXT,
    precondition TEXT DEFAULT NULL,
    worktree_path TEXT,
    branch_name TEXT,
    pr_number INTEGER,
    pr_url TEXT,
    cancelled_at DATETIME,
    cancelled_reason TEXT,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

INSERT INTO waves_new SELECT
    id, project_id, wave_id, name, status, assignee,
    tasks_done, tasks_total, started_at, completed_at,
    plan_id, position, planned_start, planned_end,
    depends_on, estimated_hours, markdown_path, precondition,
    worktree_path, branch_name, pr_number, pr_url,
    cancelled_at, cancelled_reason
FROM waves;

-- Preserve wave triggers
DROP TRIGGER IF EXISTS wave_auto_complete;

DROP TABLE waves;
ALTER TABLE waves_new RENAME TO waves;

-- Recreate indexes
CREATE INDEX IF NOT EXISTS idx_waves_project ON waves(project_id, wave_id);
CREATE INDEX IF NOT EXISTS idx_waves_plan ON waves(plan_id, position);
CREATE INDEX IF NOT EXISTS idx_waves_markdown ON waves(markdown_path) WHERE markdown_path IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_waves_worktree ON waves(worktree_path) WHERE worktree_path IS NOT NULL;

-- Recreate trigger: set 'merging' instead of 'done' when all tasks complete
CREATE TRIGGER wave_auto_complete
AFTER UPDATE OF tasks_done ON waves
WHEN NEW.tasks_done = NEW.tasks_total AND NEW.tasks_total > 0
     AND NEW.status NOT IN ('done', 'merging', 'cancelled')
BEGIN
    UPDATE waves
    SET status = 'merging',
        completed_at = COALESCE(completed_at, datetime('now'))
    WHERE id = NEW.id;
END;

COMMIT;
PRAGMA foreign_keys = ON;
SQL
	echo "  [OK] waves table rebuilt with 'cancelled' in CHECK"
else
	echo ""
	echo "  [SKIP] waves CHECK already includes 'cancelled'"
fi

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
echo ""
echo "=== Verification ==="

verify_ok=0
verify_fail=0

for table in plans tasks waves; do
	# Check columns
	col_count=$(sqlite3 "$DB_FILE" \
		"SELECT COUNT(*) FROM pragma_table_info('$table') WHERE name IN ('cancelled_at','cancelled_reason');")
	if [[ $col_count -eq 2 ]]; then
		echo "  $table columns: 2/2 [OK]"
		verify_ok=$((verify_ok + 1))
	else
		echo "  $table columns: $col_count/2 [FAIL]" >&2
		verify_fail=$((verify_fail + 1))
	fi

	# Check constraint
	ddl=$(sqlite3 "$DB_FILE" "SELECT sql FROM sqlite_master WHERE type='table' AND name='$table';")
	if echo "$ddl" | grep -q "'cancelled'"; then
		echo "  $table CHECK:   includes 'cancelled' [OK]"
		verify_ok=$((verify_ok + 1))
	else
		echo "  $table CHECK:   MISSING 'cancelled' [FAIL]" >&2
		verify_fail=$((verify_fail + 1))
	fi
done

# Verify data preserved
for table in plans tasks waves; do
	count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table;")
	echo "  $table rows:    $count (data preserved)"
done

# Verify triggers
trigger_count=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name IN ('task_done_counter','wave_auto_complete');")
echo "  Triggers:       $trigger_count/2 present"

if [[ $verify_fail -gt 0 ]]; then
	echo ""
	echo "=== Migration v9 FAILED: $verify_fail checks failed ===" >&2
	exit 1
fi

echo ""
echo "=== Migration v9 Complete ==="
