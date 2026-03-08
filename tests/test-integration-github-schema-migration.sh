#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

MIGRATION_SCRIPT="$WORKTREE_ROOT/scripts/migrations/008_github_schema.py"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

if [[ ! -f "$MIGRATION_SCRIPT" ]]; then
  echo "Missing migration script: $MIGRATION_SCRIPT"
  exit 1
fi

DB_PATH="$TMP_HOME/.claude/data/dashboard.db"
mkdir -p "$(dirname "$DB_PATH")"
sqlite3 "$DB_PATH" "
CREATE TABLE plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT
);
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id TEXT
);
"

HOME="$TMP_HOME" python3 "$MIGRATION_SCRIPT"

if [[ ! -f "$DB_PATH" ]]; then
  echo "Migration did not create DB at $DB_PATH"
  exit 1
fi

for col in commit_sha lines_added lines_removed files_changed; do
  has_col=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pragma_table_info('tasks') WHERE name='${col}';")
  if [[ "$has_col" != "1" ]]; then
    echo "Missing tasks column: $col"
    exit 1
  fi
done

has_issue_col=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pragma_table_info('plans') WHERE name='github_issue';")
if [[ "$has_issue_col" != "1" ]]; then
  echo "Missing plans column: github_issue"
  exit 1
fi

for table in plan_commits github_events; do
  has_table=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='${table}';")
  if [[ "$has_table" != "1" ]]; then
    echo "Missing expected table: $table"
    exit 1
  fi
done

HOME="$TMP_HOME" python3 "$MIGRATION_SCRIPT"

echo "PASS"
