#!/bin/bash
set -euo pipefail
# ARCHIVED: Migration already applied. Kept for reference only.
# This script should not be run again on existing databases.
#
# Migration: Add proper FK relationships to tasks table
# Fixes: wave_id_fk and plan_id missing from tasks

# Version: 1.1.0
set -euo pipefail

DB_FILE="${HOME}/.claude/data/dashboard.db"

echo "=== Migration: Adding FK to tasks table ==="
echo ""

# Check if wave_id_fk already exists
if sqlite3 "$DB_FILE" "PRAGMA table_info(tasks)" | grep -q "wave_id_fk"; then
	echo "wave_id_fk already exists, checking plan_id..."
else
	echo "Adding wave_id_fk column..."
	sqlite3 "$DB_FILE" "ALTER TABLE tasks ADD COLUMN wave_id_fk INTEGER;"
fi

# Check if plan_id already exists
if sqlite3 "$DB_FILE" "PRAGMA table_info(tasks)" | grep -q "plan_id"; then
	echo "plan_id already exists"
else
	echo "Adding plan_id column..."
	sqlite3 "$DB_FILE" "ALTER TABLE tasks ADD COLUMN plan_id INTEGER REFERENCES plans(id);"
fi

echo ""
echo "Migrating existing tasks..."

# Update wave_id_fk for all tasks based on wave_id match
sqlite3 "$DB_FILE" "
    UPDATE tasks SET wave_id_fk = (
        SELECT w.id FROM waves w
        WHERE w.wave_id = tasks.wave_id AND w.project_id = tasks.project_id
        LIMIT 1
    );
"

# Update plan_id for all tasks based on waves table
sqlite3 "$DB_FILE" "
    UPDATE tasks SET plan_id = (
        SELECT w.plan_id FROM waves w
        WHERE w.id = tasks.wave_id_fk
    );
"

echo ""
echo "Verifying migration..."

# Check for tasks that couldn't be migrated
orphans=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk IS NULL;")
if [ "$orphans" -gt 0 ]; then
	echo -e "${YELLOW}WARNING: $orphans tasks could not be migrated (no matching wave)${NC}"
else
	echo -e "${GREEN}All tasks migrated successfully${NC}"
fi

# Count by plan
echo ""
echo "Tasks per plan:"
sqlite3 -header -column "$DB_FILE" "
    SELECT p.id, p.name, COUNT(t.id) as task_count
    FROM plans p
    LEFT JOIN tasks t ON t.plan_id = p.id
    GROUP BY p.id
    ORDER BY p.id;
"

echo ""
echo "=== Migration Complete ==="
