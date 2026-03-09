#!/usr/bin/env bash
set -euo pipefail
# apply-migrations.sh — Apply dashboard.db migrations from Rust state.rs definitions
# Usage: apply-migrations.sh [DB_PATH]
# Extracts ALTER TABLE statements from state.rs and runs them. Idempotent.

DB="${1:-${HOME}/.claude/data/dashboard.db}"
STATE_RS="${HOME}/.claude/rust/claude-core/src/server/state.rs"

[[ -f "$DB" ]] || { echo "ERROR: DB not found: $DB" >&2; exit 1; }
[[ -f "$STATE_RS" ]] || { echo "ERROR: state.rs not found: $STATE_RS" >&2; exit 1; }

ok=0 skip=0
while IFS= read -r sql; do
  [[ -z "$sql" ]] && continue
  if sqlite3 "$DB" "$sql" 2>/dev/null; then
    ok=$((ok + 1))
  else
    skip=$((skip + 1))
  fi
done < <(grep -oP '"((?:ALTER TABLE|CREATE TABLE IF NOT EXISTS|CREATE INDEX IF NOT EXISTS)[^"]*)"' "$STATE_RS" | sed 's/^"//;s/"$//')

echo "Migrations: $ok applied, $skip skipped (already exist)"
