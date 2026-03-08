#!/usr/bin/env bash
# ARCHIVED: Migration already applied. Kept for reference only.
# This script should not be run again on existing databases.
# Version: 1.1.0
set -euo pipefail

# migrate-v4.sh - Database migration to v4 schema
# Adds: tasks.output_data, tasks.executor_agent, waves.precondition

DB_PATH="${CLAUDE_DB:-$HOME/.claude/data/dashboard.db}"
SCHEMA_VERSION=4

echo "=== Database Migration to v$SCHEMA_VERSION ==="
echo "Database: $DB_PATH"

# Verify database exists
if [[ ! -f "$DB_PATH" ]]; then
	echo "ERROR: Database not found at $DB_PATH"
	exit 1
fi

# Create schema_metadata table if it doesn't exist
echo "Ensuring schema_metadata table exists..."
sqlite3 "$DB_PATH" <<SQL
CREATE TABLE IF NOT EXISTS schema_metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
SQL

# Get current schema version
CURRENT_VERSION=$(sqlite3 "$DB_PATH" "SELECT value FROM schema_metadata WHERE key='version';" 2>/dev/null || echo "0")
echo "Current schema version: $CURRENT_VERSION"

if [[ "$CURRENT_VERSION" -ge "$SCHEMA_VERSION" ]]; then
	echo "Database is already at version $CURRENT_VERSION (target: $SCHEMA_VERSION)"
	echo "No migration needed."
	exit 0
fi

# Function to check if column exists
column_exists() {
	local table=$1
	local column=$2
	sqlite3 "$DB_PATH" "PRAGMA table_info($table);" | grep -q "^[0-9]*|$column|"
}

# Migrate tasks table
echo ""
echo "Migrating tasks table..."

if column_exists "tasks" "output_data"; then
	echo "  [SKIP] tasks.output_data already exists"
else
	echo "  [ADD]  tasks.output_data"
	sqlite3 "$DB_PATH" "ALTER TABLE tasks ADD COLUMN output_data TEXT DEFAULT NULL;"
fi

if column_exists "tasks" "executor_agent"; then
	echo "  [SKIP] tasks.executor_agent already exists"
else
	echo "  [ADD]  tasks.executor_agent"
	sqlite3 "$DB_PATH" "ALTER TABLE tasks ADD COLUMN executor_agent TEXT DEFAULT NULL;"
fi

# Migrate waves table
echo ""
echo "Migrating waves table..."

if column_exists "waves" "precondition"; then
	echo "  [SKIP] waves.precondition already exists"
else
	echo "  [ADD]  waves.precondition"
	sqlite3 "$DB_PATH" "ALTER TABLE waves ADD COLUMN precondition TEXT DEFAULT NULL;"
fi

# Update schema version
echo ""
echo "Updating schema version to $SCHEMA_VERSION..."
sqlite3 "$DB_PATH" <<SQL
INSERT OR REPLACE INTO schema_metadata (key, value, updated_at)
VALUES ('version', '$SCHEMA_VERSION', CURRENT_TIMESTAMP);
SQL

# Verify migration
echo ""
echo "=== Migration Verification ==="
echo "Tasks columns added:"
sqlite3 "$DB_PATH" "PRAGMA table_info(tasks);" | grep -E "(output_data|executor_agent)" || echo "  WARNING: Columns not found"
echo ""
echo "Waves columns added:"
sqlite3 "$DB_PATH" "PRAGMA table_info(waves);" | grep "precondition" || echo "  WARNING: Column not found"
echo ""
echo "Schema version:"
sqlite3 "$DB_PATH" "SELECT key, value, updated_at FROM schema_metadata WHERE key='version';"

echo ""
echo "=== Migration to v$SCHEMA_VERSION Complete ==="
