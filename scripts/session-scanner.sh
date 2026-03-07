#!/usr/bin/env bash
set -euo pipefail
# session-scanner.sh — Detects active Claude/Copilot CLI sessions
# Writes to agent_activity table for brain visualization as "consciousness nodes"
# Usage: session-scanner.sh [scan|list]

DB="${PLAN_DB:-$HOME/.claude/data/dashboard.db}"
HOST="$(hostname -s 2>/dev/null || echo local)"

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

    sqlite3 "$DB" <<-SQL 2>/dev/null || true
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
  sqlite3 "$DB" "SELECT agent_id FROM agent_activity WHERE agent_id LIKE 'session-%' AND status='running';" 2>/dev/null | while read -r sid; do
    PID="${sid##*-}"
    if ! ps -p "$PID" > /dev/null 2>&1; then
      sqlite3 "$DB" "UPDATE agent_activity SET status='completed', completed_at=datetime('now'), \
        duration_s=CAST((julianday('now')-julianday(started_at))*86400 AS REAL) WHERE agent_id='${sid}';" 2>/dev/null || true
    fi
  done
}

case "${1:-scan}" in
  scan) scan_sessions; cleanup_stale ;;
  list) sqlite3 -json "$DB" "SELECT agent_id, agent_type AS type, description, status, metadata \
    FROM agent_activity WHERE agent_id LIKE 'session-%' AND status='running';" 2>/dev/null || echo '[]' ;;
  *) echo "Usage: session-scanner.sh [scan|list]"; exit 2 ;;
esac
