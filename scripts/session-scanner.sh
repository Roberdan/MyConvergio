#!/usr/bin/env bash
set -euo pipefail
# session-scanner.sh — Detects active Claude/Copilot CLI sessions
# Writes to agent_activity table for brain visualization as "consciousness nodes"
# Usage: session-scanner.sh [scan|list]

DB="${PLAN_DB:-$HOME/.claude/data/dashboard.db}"
HOST="$(hostname -s 2>/dev/null || echo local)"

# CRR tables need crsqlite loaded for trigger functions
CRSQL=""
for p in "$HOME/.claude/lib/crsqlite/crsqlite" "/opt/homebrew/lib/crsqlite/crsqlite" "/usr/local/lib/crsqlite/crsqlite"; do
  [ -f "$p.dylib" ] || [ -f "$p.so" ] || [ -f "$p" ] && { CRSQL="$p"; break; }
done
LOAD_EXT=""
[ -n "$CRSQL" ] && LOAD_EXT=".load $CRSQL"

# macOS system sqlite3 has .load disabled; prefer homebrew
SQLITE3="sqlite3"
[ -x /opt/homebrew/opt/sqlite/bin/sqlite3 ] && SQLITE3="/opt/homebrew/opt/sqlite/bin/sqlite3"

_sql() {
  if [ -n "$CRSQL" ]; then
    "$SQLITE3" -cmd ".load $CRSQL" "$DB" "$@"
  else
    "$SQLITE3" "$DB" "$@"
  fi
}

sanitize() { echo "$1" | tr "'" "_" | cut -c1-200; }

scan_sessions() {
  ps aux 2>/dev/null | grep -E '(claude|copilot)' | grep -v -E 'grep|hook|scanner|plan-db|track|\.sh' | while IFS= read -r line; do
    PID=$(echo "$line" | awk '{print $2}')
    CPU=$(echo "$line" | awk '{print $3}')
    MEM=$(echo "$line" | awk '{print $4}')
    TTY=$(echo "$line" | awk '{print $7}')
    CMD=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')

    # Only match main CLI processes, not node subprocesses or workers
    case "$CMD" in
      *copilot*agent*|*copilot*worker*|*node*copilot*) continue ;;
      *claude*hook*|*claude*plan-db*|*claude*script*) continue ;;
      *claude-core*|*claude-co*) continue ;;
      *"Cursor Helper"*|*extension-host*) continue ;;
    esac

    # Determine type
    TYPE="unknown"
    if echo "$CMD" | grep -qi "copilot"; then TYPE="copilot-cli"
    elif echo "$CMD" | grep -qi "claude"; then TYPE="claude-cli"
    else continue
    fi

    # Get working directory (fail-silent)
    CWD=$(lsof -p "$PID" 2>/dev/null | awk '/cwd/{print $NF}' || echo "unknown")

    SESSION_ID="session-${TYPE}-${PID}"
    SAFE_CMD=$(sanitize "$CMD")
    SAFE_CWD=$(sanitize "$CWD")
    SAFE_TTY=$(sanitize "$TTY")

    _sql <<-SQL 2>/dev/null || true
INSERT INTO agent_activity (agent_id, agent_type, description, model, host, status, region, metadata)
VALUES ('${SESSION_ID}', '${TYPE}', '${SAFE_CMD}', '${TYPE}', '${HOST}', 'running', 'prefrontal',
  '{"pid":${PID},"tty":"${SAFE_TTY}","cpu":${CPU},"mem":${MEM},"cwd":"${SAFE_CWD}"}')
ON CONFLICT(agent_id) DO UPDATE SET
  metadata='{"pid":${PID},"tty":"${SAFE_TTY}","cpu":${CPU},"mem":${MEM},"cwd":"${SAFE_CWD}"}',
  status='running';
SQL
    echo "$SESSION_ID"
  done
}

cleanup_stale() {
  _sql "SELECT agent_id FROM agent_activity WHERE agent_id LIKE 'session-%' AND status='running';" 2>/dev/null | while read -r sid; do
    PID="${sid##*-}"
    if ! ps -p "$PID" > /dev/null 2>&1; then
      _sql "UPDATE agent_activity SET status='completed', completed_at=datetime('now'), \
        duration_s=CAST((julianday('now')-julianday(started_at))*86400 AS REAL) WHERE agent_id='${sid}';" 2>/dev/null || true
    fi
  done
}

case "${1:-scan}" in
  scan) scan_sessions; cleanup_stale ;;
  list)
    if [ -n "$CRSQL" ]; then
      "$SQLITE3" -json -cmd ".load $CRSQL" "$DB" "SELECT agent_id, agent_type AS type, description, status, metadata FROM agent_activity WHERE agent_id LIKE 'session-%' AND status='running';" 2>/dev/null || echo '[]'
    else
      "$SQLITE3" -json "$DB" "SELECT agent_id, agent_type AS type, description, status, metadata FROM agent_activity WHERE agent_id LIKE 'session-%' AND status='running';" 2>/dev/null || echo '[]'
    fi ;;
  *) echo "Usage: session-scanner.sh [scan|list]"; exit 2 ;;
esac
