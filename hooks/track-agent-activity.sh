#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: tracks tool activity for brain visualization
# Receives JSON on stdin: {"tool_name": "...", "tool_input": {...}, "tool_result": "..."}
# Exit 0 always (never block)

DB="${PLAN_DB:-$HOME/.claude/data/dashboard.db}"
[[ -f "$DB" ]] || exit 0

HOOK_INPUT=$(cat)
[[ -z "$HOOK_INPUT" ]] && exit 0

TOOL_NAME=$(echo "$HOOK_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
[[ -z "$TOOL_NAME" ]] && exit 0

HOST=$(hostname -s 2>/dev/null || echo "local")
TS=$(date +%s)

case "$TOOL_NAME" in
  task|Task)
    AGENT_TYPE=$(echo "$HOOK_INPUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(d.get('tool_input',{}).get('agent_type','unknown'))" 2>/dev/null || echo "unknown")

    DESC=$(echo "$HOOK_INPUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(d.get('tool_input',{}).get('description','')[:100])" 2>/dev/null || echo "")

    MODEL=$(echo "$HOOK_INPUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(d.get('tool_input',{}).get('model','default'))" 2>/dev/null || echo "default")

    # Generate agent_id from description hash
    AGENT_ID="hook-$(echo "$DESC" | md5 -q 2>/dev/null || echo "$TS")"
    AGENT_ID="${AGENT_ID:0:20}"

    # Find parent session: walk up process tree to find a claude/copilot PID
    PARENT_SESSION=""
    PPID_CHECK=$$
    for _ in 1 2 3 4 5; do
      PPID_CHECK=$(ps -o ppid= -p "$PPID_CHECK" 2>/dev/null | tr -d ' ')
      [[ -z "$PPID_CHECK" || "$PPID_CHECK" == "1" ]] && break
      PARENT_CMD=$(ps -o comm= -p "$PPID_CHECK" 2>/dev/null || echo "")
      if echo "$PARENT_CMD" | grep -qE 'claude|copilot'; then
        PARENT_SESSION="session-$(echo "$PARENT_CMD" | grep -oE 'claude|copilot')-cli-${PPID_CHECK}"
        break
      fi
    done
    SAFE_PARENT="${PARENT_SESSION:+\'${PARENT_SESSION//\'/\'\'}\'}"
    SAFE_PARENT="${SAFE_PARENT:-NULL}"

    # Check if result present (PostToolUse with result vs invocation)
    HAS_RESULT=$(echo "$HOOK_INPUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('yes' if d.get('tool_result') else 'no')" 2>/dev/null || echo "no")

    if [[ "$HAS_RESULT" == "yes" ]]; then
      STATUS=$(echo "$HOOK_INPUT" | python3 -c "
import sys,json
r=json.load(sys.stdin).get('tool_result','').lower()
print('failed' if any(w in r for w in ['fail','error','exception']) else 'completed')" 2>/dev/null || echo "completed")

      DURATION=$(echo "$HOOK_INPUT" | python3 -c "
import sys,json,re
r=json.load(sys.stdin).get('tool_result','')
m=re.search(r'(\d+\.?\d*)\s*s(?:ec|ond)?', r)
print(m.group(1) if m else '0')" 2>/dev/null || echo "0")

      sqlite3 "$DB" "UPDATE agent_activity SET status='${STATUS}', completed_at=datetime('now'), duration_s=${DURATION} WHERE agent_id='${AGENT_ID}' AND status='running';" 2>/dev/null || true
    else
      SAFE_DESC="${DESC//\'/\'\'}"
      sqlite3 "$DB" "INSERT OR IGNORE INTO agent_activity (agent_id, agent_type, description, model, host, status, started_at, parent_session) VALUES ('${AGENT_ID}', '${AGENT_TYPE}', '${SAFE_DESC}', '${MODEL}', '${HOST}', 'running', datetime('now'), ${SAFE_PARENT});" 2>/dev/null || true
    fi
    ;;

  edit|Edit|create|Create)
    FILE_PATH=$(echo "$HOOK_INPUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(d.get('tool_input',{}).get('path',''))" 2>/dev/null || echo "")

    if [[ -n "$FILE_PATH" ]]; then
      FNAME="${FILE_PATH##*/}"
      SAFE_FNAME="${FNAME//\'/\'\'}"
      sqlite3 "$DB" "INSERT OR IGNORE INTO agent_activity (agent_id, agent_type, description, model, host, status, started_at, completed_at, duration_s) VALUES ('edit-${TS}', 'file_edit', '${SAFE_FNAME}', 'direct', '${HOST}', 'completed', datetime('now'), datetime('now'), 0);" 2>/dev/null || true
    fi
    ;;

  bash|Bash)
    # Lightweight pulse — no heavy tracking for shell commands
    sqlite3 "$DB" "INSERT OR REPLACE INTO session_state (key, value) VALUES ('last_bash_at', datetime('now'));" 2>/dev/null || true
    ;;

  grep|Grep|glob|Glob|view|View)
    # Read-only tools — track as exploration pulse
    sqlite3 "$DB" "INSERT OR REPLACE INTO session_state (key, value) VALUES ('last_explore_at', datetime('now'));" 2>/dev/null || true
    ;;
esac

exit 0
