#!/usr/bin/env bash
set -euo pipefail

# PreCompact hook: save state before context window compaction
# Records compaction event — brain visualization shows "memory consolidation"
# Exit 0 always (never block)

DB="${PLAN_DB:-$HOME/.claude/data/dashboard.db}"
[[ -f "$DB" ]] || exit 0

HOST=$(hostname -s 2>/dev/null || echo "local")
TS=$(date +%s)

# Record compaction event (hippocampus region in brain viz)
sqlite3 "$DB" "INSERT INTO agent_activity (agent_id, agent_type, description, model, host, status, started_at, completed_at, duration_s) VALUES ('compact-${TS}', 'compaction', 'Context compaction', 'system', '${HOST}', 'completed', datetime('now'), datetime('now'), 0);" 2>/dev/null || true

# Snapshot counts for post-compaction comparison
RUNNING=$(sqlite3 "$DB" "SELECT COUNT(*) FROM agent_activity WHERE status='running';" 2>/dev/null || echo "0")
sqlite3 "$DB" "INSERT OR REPLACE INTO session_state (key, value) VALUES ('pre_compact_running', '${RUNNING}');" 2>/dev/null || true
sqlite3 "$DB" "INSERT OR REPLACE INTO session_state (key, value) VALUES ('last_compaction_at', datetime('now'));" 2>/dev/null || true

exit 0
