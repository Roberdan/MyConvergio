#!/usr/bin/env bash
set -euo pipefail

# Stop hook: marks session activity pulse
# Used by brain visualization to show "consciousness" activity
# Exit 0 always (never block)

DB="${PLAN_DB:-$HOME/.claude/data/dashboard.db}"
[[ -f "$DB" ]] || exit 0

# Write a lightweight session pulse
sqlite3 "$DB" "INSERT OR REPLACE INTO session_state (key, value) VALUES ('last_response_at', datetime('now'));" 2>/dev/null || true

# Count completed agents in last 5 min for activity metric
sqlite3 "$DB" "INSERT OR REPLACE INTO session_state (key, value) VALUES ('recent_completions', (SELECT COUNT(*) FROM agent_activity WHERE completed_at > datetime('now', '-5 minutes')));" 2>/dev/null || true

# Mark any running agents as stale if older than 30min
sqlite3 "$DB" "UPDATE agent_activity SET status='stale' WHERE status='running' AND started_at < datetime('now', '-30 minutes');" 2>/dev/null || true

exit 0
