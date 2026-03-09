#!/usr/bin/env bash
# session-learning-collector.sh — Stop hook
# Collects mechanical signals from session for later optimization.
# Does NOT reason — just extracts patterns for /optimize skill.
# Version: 1.0.0
set -uo pipefail

source ~/.claude/hooks/lib/common.sh 2>/dev/null || true

LEARNINGS_FILE="$HOME/.claude/data/session-learnings.jsonl"
LOG_FILE="$HOME/.claude/logs/learning-collector.log"
mkdir -p "$(dirname "$LEARNINGS_FILE")" "$(dirname "$LOG_FILE")" 2>/dev/null

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG_FILE" 2>/dev/null; }

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
PROJECT=$(basename "$CWD" 2>/dev/null)

[[ -z "$SESSION_ID" ]] && exit 0

{
  TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  SIGNALS="[]"

  # Signal 1: Stale plan tasks (in_progress at session end)
  if check_dashboard; then
    STALE=$(sqlite3 "$DASHBOARD_DB" "
      SELECT json_group_array(json_object('plan_id', plan_id, 'task_id', task_id, 'title', title))
      FROM tasks WHERE status = 'in_progress' AND plan_id IN (
        SELECT id FROM plans WHERE status = 'doing'
      );" 2>/dev/null)
    if [[ -n "$STALE" && "$STALE" != "[]" ]]; then
      SIGNALS=$(echo "$SIGNALS" | jq --argjson s "$STALE" '. + [{"type":"stale_tasks","data":$s}]')
      log "SIGNAL: stale tasks found"
    fi
  fi

  # Signal 2: Stale MEMORY.md checkpoint (plan is done but checkpoint remains)
  if check_dashboard; then
    MEMORY_FILE="$HOME/.claude/projects/-Users-roberdan-GitHub-${PROJECT}/memory/MEMORY.md"
    if [[ -f "$MEMORY_FILE" ]]; then
      CHECKPOINT_PLAN=$(grep -oP 'PLAN_ID:\s*\K\d+' "$MEMORY_FILE" 2>/dev/null | head -1)
      if [[ -n "$CHECKPOINT_PLAN" ]]; then
        PLAN_STATUS=$(sqlite3 "$DASHBOARD_DB" "SELECT status FROM plans WHERE id=$CHECKPOINT_PLAN;" 2>/dev/null)
        if [[ "$PLAN_STATUS" == "done" || "$PLAN_STATUS" == "cancelled" ]]; then
          SIGNALS=$(echo "$SIGNALS" | jq '. + [{"type":"stale_checkpoint","data":{"plan_id":'$CHECKPOINT_PLAN',"status":"'"$PLAN_STATUS"'"}}]')
          log "SIGNAL: stale checkpoint for plan $CHECKPOINT_PLAN (status=$PLAN_STATUS)"
        fi
      fi
    fi
  fi

  # Signal 3: Repeated command failures (same command failed 2+ times)
  if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
    # Extract failed bash commands (exit_code != 0), limit to last 500 entries for speed
    FAILED_CMDS=$(tail -c 5000000 "$TRANSCRIPT" 2>/dev/null | jq -r '
      select(.type == "tool_result" and .content != null)
      | .content
      | if type == "array" then .[0].text // "" else . end
      | select(test("Exit code [1-9]"))
      | split("\n")[0]
    ' 2>/dev/null | sort | uniq -c | sort -rn | awk '$1 >= 2 {$1=""; print substr($0,2)}' | head -5)

    if [[ -n "$FAILED_CMDS" ]]; then
      FAILED_JSON=$(echo "$FAILED_CMDS" | jq -R -s 'split("\n") | map(select(length > 0))')
      SIGNALS=$(echo "$SIGNALS" | jq --argjson f "$FAILED_JSON" '. + [{"type":"repeated_failures","data":$f}]')
      log "SIGNAL: repeated command failures detected"
    fi
  fi

  # Signal 4: Version file mismatch (VERSION.md vs pyproject.toml)
  if [[ -n "$CWD" ]]; then
    V_MD="$CWD/VERSION.md"
    V_PYPROJECT="$CWD/scripts/python/pyproject.toml"
    if [[ -f "$V_MD" && -f "$V_PYPROJECT" ]]; then
      VER_MD=$(tr -d '[:space:]' < "$V_MD")
      VER_PY=$(grep -oP 'version\s*=\s*"\K[^"]+' "$V_PYPROJECT" 2>/dev/null)
      if [[ -n "$VER_MD" && -n "$VER_PY" && "$VER_MD" != "$VER_PY" ]]; then
        SIGNALS=$(echo "$SIGNALS" | jq '. + [{"type":"version_mismatch","data":{"VERSION.md":"'"$VER_MD"'","pyproject.toml":"'"$VER_PY"'"}}]')
        log "SIGNAL: version mismatch VERSION.md=$VER_MD pyproject.toml=$VER_PY"
      fi
    fi
  fi

  # Signal 5: Unmerged worktrees left behind
  if [[ -n "$CWD" ]] && command -v git >/dev/null 2>&1; then
    WORKTREES=$(cd "$CWD" 2>/dev/null && git worktree list --porcelain 2>/dev/null | grep -c "^worktree " || echo 0)
    if [[ "$WORKTREES" -gt 1 ]]; then
      SIGNALS=$(echo "$SIGNALS" | jq '. + [{"type":"stale_worktrees","data":{"count":'$WORKTREES'}}]')
      log "SIGNAL: $WORKTREES worktrees still present"
    fi
  fi

  # Write signals if any were collected
  SIG_COUNT=$(echo "$SIGNALS" | jq 'length')
  if [[ "$SIG_COUNT" -gt 0 ]]; then
    echo "$SIGNALS" | jq -c '{
      timestamp: "'"$TIMESTAMP"'",
      session_id: "'"$SESSION_ID"'",
      project: "'"$PROJECT"'",
      signals: .
    }' >> "$LEARNINGS_FILE"
    log "Collected $SIG_COUNT signals for session $SESSION_ID"
  else
    log "No signals for session $SESSION_ID"
  fi
} &

exit 0
