#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

MIGRATION_SCRIPT="$WORKTREE_ROOT/scripts/migrations/007_chat_schema.py"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

if [[ ! -f "$MIGRATION_SCRIPT" ]]; then
  echo "Missing migration script: $MIGRATION_SCRIPT"
  exit 1
fi

HOME="$TMP_HOME" python3 "$MIGRATION_SCRIPT"

DB_PATH="$TMP_HOME/.claude/data/dashboard.db"
if [[ ! -f "$DB_PATH" ]]; then
  echo "Migration did not create DB at $DB_PATH"
  exit 1
fi

for table in chat_sessions chat_messages chat_requirements; do
  if ! sqlite3 "$DB_PATH" ".tables" | tr ' ' '\n' | grep -q "^${table}$"; then
    echo "Missing expected table: $table"
    exit 1
  fi
done

HOME="$TMP_HOME" python3 "$MIGRATION_SCRIPT"

echo "PASS"
