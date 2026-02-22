#!/usr/bin/env bash
# migrate-v8-wave-worktree.sh - Wave worktree tracking and merging status
# Adds: worktree_path, branch_name, pr_number, pr_url columns to waves
# Rebuilds waves table CHECK constraint to include 'merging' status
# Updates wave_auto_complete trigger to set 'merging' instead of 'done'
# Idempotent: checks columns exist, checks 'merging' already in constraint
# Version: 1.0.0
set -euo pipefail

DB_FILE="${DB_FILE:-${CLAUDE_HOME:-$HOME/.claude}/data/dashboard.db}"

echo "=== Database Migration v8: Wave Worktree Support ==="
echo "Database: $DB_FILE"

if [[ ! -f "$DB_FILE" ]]; then
	echo "ERROR: Database not found: $DB_FILE" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Backup before modifications
# ---------------------------------------------------------------------------
BACKUP_FILE="$HOME/.claude/data/dashboard.db.bak-v8-$(date +%s)"
echo ""
echo "Creating backup: $BACKUP_FILE"
cp "$DB_FILE" "$BACKUP_FILE"
echo "  [OK] Backup created"

# ---------------------------------------------------------------------------
# Idempotency checks
# ---------------------------------------------------------------------------
echo ""
echo "Checking current schema state..."

# Check if columns already exist
WORKTREE_COL=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('waves') WHERE name='worktree_path';")
BRANCH_COL=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('waves') WHERE name='branch_name';")
PR_NUM_COL=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('waves') WHERE name='pr_number';")
PR_URL_COL=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('waves') WHERE name='pr_url';")

# Check if 'merging' is already in the CHECK constraint
WAVES_DDL=$(sqlite3 "$DB_FILE" \
	"SELECT sql FROM sqlite_master WHERE type='table' AND name='waves';")
MERGING_IN_CHECK=0
if echo "$WAVES_DDL" | grep -q "'merging'"; then
	MERGING_IN_CHECK=1
fi

# Check if worktree index already exists
WORKTREE_IDX=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_waves_worktree';")

echo "  Column worktree_path: $([[ $WORKTREE_COL -eq 1 ]] && echo EXISTS || echo MISSING)"
echo "  Column branch_name:   $([[ $BRANCH_COL -eq 1 ]] && echo EXISTS || echo MISSING)"
echo "  Column pr_number:     $([[ $PR_NUM_COL -eq 1 ]] && echo EXISTS || echo MISSING)"
echo "  Column pr_url:        $([[ $PR_URL_COL -eq 1 ]] && echo EXISTS || echo MISSING)"
echo "  'merging' in CHECK:   $([[ $MERGING_IN_CHECK -eq 1 ]] && echo YES || echo NO)"
echo "  idx_waves_worktree:   $([[ $WORKTREE_IDX -eq 1 ]] && echo EXISTS || echo MISSING)"

# If fully migrated, skip
if [[ $WORKTREE_COL -eq 1 && $BRANCH_COL -eq 1 && $PR_NUM_COL -eq 1 &&
	$PR_URL_COL -eq 1 && $MERGING_IN_CHECK -eq 1 && $WORKTREE_IDX -eq 1 ]]; then
	echo ""
	echo "=== Already fully migrated. Nothing to do. ==="
	exit 0
fi

# ---------------------------------------------------------------------------
# Add missing columns (safe: ALTER TABLE IF NOT EXISTS equivalent via check)
# ---------------------------------------------------------------------------
echo ""
echo "Adding missing columns to waves..."

if [[ $WORKTREE_COL -eq 0 ]]; then
	sqlite3 "$DB_FILE" "ALTER TABLE waves ADD COLUMN worktree_path TEXT;"
	echo "  [OK] Added worktree_path"
else
	echo "  [SKIP] worktree_path already exists"
fi

if [[ $BRANCH_COL -eq 0 ]]; then
	sqlite3 "$DB_FILE" "ALTER TABLE waves ADD COLUMN branch_name TEXT;"
	echo "  [OK] Added branch_name"
else
	echo "  [SKIP] branch_name already exists"
fi

if [[ $PR_NUM_COL -eq 0 ]]; then
	sqlite3 "$DB_FILE" "ALTER TABLE waves ADD COLUMN pr_number INTEGER;"
	echo "  [OK] Added pr_number"
else
	echo "  [SKIP] pr_number already exists"
fi

if [[ $PR_URL_COL -eq 0 ]]; then
	sqlite3 "$DB_FILE" "ALTER TABLE waves ADD COLUMN pr_url TEXT;"
	echo "  [OK] Added pr_url"
else
	echo "  [SKIP] pr_url already exists"
fi

# ---------------------------------------------------------------------------
# Rebuild waves table to update CHECK constraint (include 'merging')
# Only needed if 'merging' not already in the constraint
# ---------------------------------------------------------------------------
if [[ $MERGING_IN_CHECK -eq 0 ]]; then
	echo ""
	echo "Rebuilding waves table to add 'merging' to CHECK constraint..."

	sqlite3 "$DB_FILE" <<'SQL'
PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;

-- Create new waves table with updated CHECK constraint
CREATE TABLE waves_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id TEXT NOT NULL,
    wave_id TEXT NOT NULL,
    name TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'merging')),
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
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Copy all existing data
INSERT INTO waves_new SELECT
    id, project_id, wave_id, name, status, assignee,
    tasks_done, tasks_total, started_at, completed_at,
    plan_id, position, planned_start, planned_end,
    depends_on, estimated_hours, markdown_path, precondition,
    worktree_path, branch_name, pr_number, pr_url
FROM waves;

-- Drop original and rename
DROP TABLE waves;
ALTER TABLE waves_new RENAME TO waves;

-- Recreate existing indexes
CREATE INDEX IF NOT EXISTS idx_waves_project ON waves(project_id, wave_id);
CREATE INDEX IF NOT EXISTS idx_waves_plan ON waves(plan_id, position);
CREATE INDEX IF NOT EXISTS idx_waves_markdown ON waves(markdown_path) WHERE markdown_path IS NOT NULL;

-- Drop old trigger (may still reference old table)
DROP TRIGGER IF EXISTS wave_auto_complete;

-- Recreate trigger: set 'merging' instead of 'done' when all tasks complete
CREATE TRIGGER wave_auto_complete
AFTER UPDATE OF tasks_done ON waves
WHEN NEW.tasks_done = NEW.tasks_total AND NEW.tasks_total > 0
     AND NEW.status NOT IN ('done', 'merging')
BEGIN
    UPDATE waves
    SET status = 'merging',
        completed_at = COALESCE(completed_at, datetime('now'))
    WHERE id = NEW.id;
END;

COMMIT;
PRAGMA foreign_keys = ON;
SQL
	echo "  [OK] waves table rebuilt with 'merging' in CHECK constraint"
	echo "  [OK] trigger wave_auto_complete recreated (sets 'merging')"
else
	echo ""
	echo "'merging' already in CHECK constraint — rebuilding trigger only if needed..."
	sqlite3 "$DB_FILE" <<'SQL'
DROP TRIGGER IF EXISTS wave_auto_complete;
CREATE TRIGGER wave_auto_complete
AFTER UPDATE OF tasks_done ON waves
WHEN NEW.tasks_done = NEW.tasks_total AND NEW.tasks_total > 0
     AND NEW.status NOT IN ('done', 'merging')
BEGIN
    UPDATE waves
    SET status = 'merging',
        completed_at = COALESCE(completed_at, datetime('now'))
    WHERE id = NEW.id;
END;
SQL
	echo "  [OK] trigger wave_auto_complete ensured"
fi

# ---------------------------------------------------------------------------
# Create worktree index (idempotent via IF NOT EXISTS)
# ---------------------------------------------------------------------------
echo ""
echo "Creating index idx_waves_worktree..."
sqlite3 "$DB_FILE" \
	"CREATE INDEX IF NOT EXISTS idx_waves_worktree ON waves(worktree_path) WHERE worktree_path IS NOT NULL;"
echo "  [OK] idx_waves_worktree"

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
echo ""
echo "=== Verification ==="

COL_COUNT=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM pragma_table_info('waves') WHERE name IN ('worktree_path','branch_name','pr_number','pr_url');")
echo "New columns present: $COL_COUNT/4"

FINAL_DDL=$(sqlite3 "$DB_FILE" \
	"SELECT sql FROM sqlite_master WHERE type='table' AND name='waves';")
if echo "$FINAL_DDL" | grep -q "'merging'"; then
	echo "CHECK constraint:    includes 'merging' [OK]"
else
	echo "CHECK constraint:    MISSING 'merging' [FAIL]" >&2
	exit 1
fi

TRIGGER_DEF=$(sqlite3 "$DB_FILE" \
	"SELECT sql FROM sqlite_master WHERE type='trigger' AND name='wave_auto_complete';")
if echo "$TRIGGER_DEF" | grep -q "'merging'"; then
	echo "Trigger:             wave_auto_complete sets 'merging' [OK]"
else
	echo "Trigger:             wave_auto_complete does NOT set 'merging' [FAIL]" >&2
	exit 1
fi

IDX=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_waves_worktree';")
echo "Index idx_waves_worktree: $([[ $IDX -eq 1 ]] && echo PRESENT || echo MISSING)"

EXISTING_INDEXES=$(sqlite3 "$DB_FILE" \
	"SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='waves' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
echo "All waves indexes: $(echo "$EXISTING_INDEXES" | tr '\n' ' ')"

WAVE_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM waves;")
echo "Total waves in DB:  $WAVE_COUNT (data preserved)"

echo ""
echo "=== Migration v8 Complete ==="
