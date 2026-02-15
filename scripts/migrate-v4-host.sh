#!/usr/bin/env bash
# ARCHIVED: Migration already applied. Kept for reference only.
# This script should not be run again on existing databases.
# Version: 1.1.0
set -euo pipefail

# migrate-v4-host.sh - Add execution host tracking columns
# Adds: plans.execution_host, tasks.executor_host, plan_versions.changed_host

DB_PATH="${CLAUDE_DB:-$HOME/.claude/data/dashboard.db}"

echo "=== Database Migration: Host Tracking ==="
echo "Database: $DB_PATH"

if [[ ! -f "$DB_PATH" ]]; then
	echo "ERROR: Database not found at $DB_PATH"
	exit 1
fi

# Reuse column_exists pattern from migrate-v4.sh
column_exists() {
	local table=$1
	local column=$2
	sqlite3 "$DB_PATH" "PRAGMA table_info($table);" | grep -q "^[0-9]*|$column|"
}

echo ""
echo "Migrating plans table..."
if column_exists "plans" "execution_host"; then
	echo "  [SKIP] plans.execution_host already exists"
else
	echo "  [ADD]  plans.execution_host"
	sqlite3 "$DB_PATH" "ALTER TABLE plans ADD COLUMN execution_host TEXT DEFAULT NULL;"
fi

echo ""
echo "Migrating tasks table..."
if column_exists "tasks" "executor_host"; then
	echo "  [SKIP] tasks.executor_host already exists"
else
	echo "  [ADD]  tasks.executor_host"
	sqlite3 "$DB_PATH" "ALTER TABLE tasks ADD COLUMN executor_host TEXT DEFAULT NULL;"
fi

echo ""
echo "Migrating plan_versions table..."
if column_exists "plan_versions" "changed_host"; then
	echo "  [SKIP] plan_versions.changed_host already exists"
else
	echo "  [ADD]  plan_versions.changed_host"
	sqlite3 "$DB_PATH" "ALTER TABLE plan_versions ADD COLUMN changed_host TEXT DEFAULT NULL;"
fi

echo ""
echo "=== Verification ==="
echo "plans.execution_host:"
sqlite3 "$DB_PATH" "PRAGMA table_info(plans);" | grep "execution_host" || echo "  WARNING: not found"
echo "tasks.executor_host:"
sqlite3 "$DB_PATH" "PRAGMA table_info(tasks);" | grep "executor_host" || echo "  WARNING: not found"
echo "plan_versions.changed_host:"
sqlite3 "$DB_PATH" "PRAGMA table_info(plan_versions);" | grep "changed_host" || echo "  WARNING: not found"

echo ""
echo "=== Migration Complete ==="
