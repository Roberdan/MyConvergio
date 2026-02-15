#!/usr/bin/env bash
# ARCHIVED: Migration already applied. Kept for reference only.
# This script should not be run again on existing databases.
# Version: 1.1.0
set -euo pipefail

# migrate-v5-cluster.sh - Add cluster/multi-machine execution tracking
# Adds: host_heartbeats table, plans.description column

DB_PATH="${CLAUDE_DB:-$HOME/.claude/data/dashboard.db}"

echo "=== Database Migration: Cluster Support ==="
echo "Database: $DB_PATH"

if [[ ! -f "$DB_PATH" ]]; then
	echo "ERROR: Database not found at $DB_PATH"
	exit 1
fi

# Check if table exists
table_exists() {
	local table_name="$1"
	local result
	result=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table_name';")
	[[ -n "$result" ]]
}

# Check if column exists in table
column_exists() {
	local table=$1
	local column=$2
	sqlite3 "$DB_PATH" "PRAGMA table_info($table);" | grep -q "^[0-9]*|$column|"
}

echo ""
echo "Creating host_heartbeats table..."
if table_exists "host_heartbeats"; then
	echo "  [SKIP] host_heartbeats table already exists"
else
	echo "  [ADD]  host_heartbeats table"
	sqlite3 "$DB_PATH" <<-SQL
		CREATE TABLE host_heartbeats (
			host TEXT PRIMARY KEY NOT NULL,
			last_seen DATETIME NOT NULL,
			plan_count INTEGER DEFAULT 0,
			os TEXT
		);
	SQL
fi

echo ""
echo "Migrating plans table..."
if column_exists "plans" "description"; then
	echo "  [SKIP] plans.description already exists"
else
	echo "  [ADD]  plans.description"
	sqlite3 "$DB_PATH" "ALTER TABLE plans ADD COLUMN description TEXT DEFAULT NULL;"
fi

echo ""
echo "Migrating token_usage table..."
if column_exists "token_usage" "execution_host"; then
	echo "  [SKIP] token_usage.execution_host already exists"
else
	echo "  [ADD]  token_usage.execution_host"
	sqlite3 "$DB_PATH" "ALTER TABLE token_usage ADD COLUMN execution_host TEXT DEFAULT NULL;"
	# Backfill existing rows with current hostname
	local_host="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
	local_host="${local_host%.local}"
	backfill_count=$(sqlite3 "$DB_PATH" "UPDATE token_usage SET execution_host = '$local_host' WHERE execution_host IS NULL; SELECT changes();")
	echo "  [FILL] Backfilled $backfill_count rows with host: $local_host"
fi

echo ""
echo "=== Verification ==="
echo "host_heartbeats table:"
if table_exists "host_heartbeats"; then
	echo "  [OK] Table exists"
	sqlite3 "$DB_PATH" "PRAGMA table_info(host_heartbeats);"
else
	echo "  WARNING: Table not found"
fi

echo ""
echo "plans.description column:"
sqlite3 "$DB_PATH" "PRAGMA table_info(plans);" | grep "description" || echo "  WARNING: not found"

echo ""
echo "=== Migration Complete ==="
