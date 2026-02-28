#!/bin/bash
set -euo pipefail
# Migration v6: Add session_id support to file_locks
# Enables session-based locking for non-plan workflows (teams, parallel agents)
# Idempotent: checks column existence before ALTER
# Version: 1.0.0
set -euo pipefail

DB_FILE="${HOME}/.claude/data/dashboard.db"

[[ ! -f "$DB_FILE" ]] && echo '{"error":"DB not found"}' && exit 1

# Check if column already exists
HAS_COL=$(sqlite3 "$DB_FILE" "
    SELECT COUNT(*) FROM pragma_table_info('file_locks')
    WHERE name='session_id';
")

if [[ "$HAS_COL" -eq 0 ]]; then
	sqlite3 "$DB_FILE" <<'SQL'
ALTER TABLE file_locks ADD COLUMN session_id TEXT;
CREATE INDEX IF NOT EXISTS idx_file_locks_session ON file_locks(session_id);
SQL
	echo '{"migrated":"v6-session-locks","added_column":"session_id"}'
else
	echo '{"migrated":"v6-session-locks","status":"already_applied"}'
fi
