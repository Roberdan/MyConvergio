#!/bin/bash
set -euo pipefail
# ARCHIVED: Migration already applied. Kept for reference only.
# This script should not be run again on existing databases.
#
# Migration: Fix tasks.wave_id to be a proper FK to waves.id
# Before: tasks.wave_id was TEXT ("W1"), forcing joins on (project_id, wave_id)
# After: tasks.wave_id_fk is INTEGER FK to waves.id, proper relational structure

# Version: 1.1.0
set -euo pipefail

DB_FILE="${HOME}/.claude/data/dashboard.db"

if [[ ! -f "$DB_FILE" ]]; then
	echo "ERROR: Database not found at $DB_FILE"
	exit 1
fi

echo "Starting migration: wave_id TEXT → wave_id_fk INTEGER FK..."
echo ""

# Backup before migration
BACKUP_FILE="${DB_FILE}.backup.$(date +%s)"
cp "$DB_FILE" "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

# Check if wave_id_fk already exists
COLUMN_EXISTS=$(sqlite3 "$DB_FILE" "PRAGMA table_info(tasks);" | grep -c "wave_id_fk" || true)
if [[ $COLUMN_EXISTS -gt 0 ]]; then
	echo "✓ Migration already applied (wave_id_fk column exists)"
	exit 0
fi

echo "Step 1: Adding wave_id_fk column..."
sqlite3 "$DB_FILE" "
    ALTER TABLE tasks ADD COLUMN wave_id_fk INTEGER;
"
echo "✓ Column added"
echo ""

echo "Step 2: Populating wave_id_fk from existing (project_id, wave_id) joins..."
sqlite3 "$DB_FILE" "
    UPDATE tasks
    SET wave_id_fk = (
        SELECT w.id FROM waves w
        WHERE w.project_id = tasks.project_id
        AND w.wave_id = tasks.wave_id
        LIMIT 1
    )
    WHERE wave_id_fk IS NULL;
"
UPDATED=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk IS NOT NULL;")
echo "✓ Updated $UPDATED rows with wave_id_fk"
echo ""

# Check for orphaned tasks (wave_id_fk is NULL)
ORPHANED=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk IS NULL;")
if [[ $ORPHANED -gt 0 ]]; then
	echo "⚠ WARNING: $ORPHANED orphaned tasks found (no matching wave)"
	sqlite3 "$DB_FILE" "
        SELECT t.id, t.task_id, t.wave_id, t.project_id
        FROM tasks t
        WHERE t.wave_id_fk IS NULL
        LIMIT 10;
    "
	echo ""
	echo "These tasks reference non-existent waves. Continuing anyway..."
	echo ""
fi

echo "Step 3: Adding FK constraint..."
sqlite3 "$DB_FILE" "
    CREATE TABLE tasks_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id TEXT NOT NULL,
        wave_id TEXT NOT NULL,
        wave_id_fk INTEGER,
        task_id TEXT NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'skipped')),
        assignee TEXT,
        priority TEXT CHECK(priority IN ('P0', 'P1', 'P2', 'P3')),
        type TEXT CHECK(type IN ('bug', 'feature', 'chore', 'doc', 'test')),
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
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (wave_id_fk) REFERENCES waves(id) ON DELETE CASCADE
    );

    INSERT INTO tasks_new SELECT * FROM tasks;
    DROP TABLE tasks;
    ALTER TABLE tasks_new RENAME TO tasks;
"
echo "✓ FK constraint added"
echo ""

echo "Step 4: Recreating indexes..."
sqlite3 "$DB_FILE" "
    CREATE INDEX idx_tasks_project ON tasks(project_id, wave_id, task_id);
    CREATE INDEX idx_tasks_wave_fk ON tasks(wave_id_fk);
    CREATE INDEX idx_tasks_markdown ON tasks(markdown_path) WHERE markdown_path IS NOT NULL;
    CREATE INDEX idx_tasks_executor ON tasks(executor_session_id) WHERE executor_session_id IS NOT NULL;
    CREATE INDEX idx_tasks_executor_active ON tasks(executor_status) WHERE executor_status IN ('running', 'paused');
"
echo "✓ Indexes recreated"
echo ""

echo "Step 5: Validating migration..."
TOTAL_TASKS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks;")
WITH_FK=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk IS NOT NULL;")
FK_INTEGRITY=$(sqlite3 "$DB_FILE" "
    SELECT COUNT(*) FROM tasks t
    WHERE t.wave_id_fk IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM waves w WHERE w.id = t.wave_id_fk);
" || echo "0")

echo "Total tasks: $TOTAL_TASKS"
echo "Tasks with wave_id_fk: $WITH_FK"
echo "FK integrity violations: $FK_INTEGRITY"

if [[ $FK_INTEGRITY -gt 0 ]]; then
	echo ""
	echo "⚠ WARNING: $FK_INTEGRITY tasks have invalid FK references"
	echo "These will cause constraint violations. Run maintenance to clean up."
else
	echo "✓ FK integrity validated"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Migration complete! Database structure updated:"
echo ""
echo "BEFORE:"
echo "  tasks.wave_id TEXT ('W1')"
echo "  Join: waves w WHERE w.project_id = tasks.project_id AND w.wave_id = tasks.wave_id"
echo ""
echo "AFTER:"
echo "  tasks.wave_id TEXT ('W1') - kept for compatibility"
echo "  tasks.wave_id_fk INTEGER FK → waves.id - proper FK"
echo "  Use wave_id_fk for all new queries!"
echo ""
echo "BACKUP: $BACKUP_FILE"
echo "═══════════════════════════════════════════════════════════════"
