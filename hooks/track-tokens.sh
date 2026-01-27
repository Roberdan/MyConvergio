#!/bin/bash
# Token Tracking Hook - Optimized with async writes
# Records token usage to the dashboard database
#
# Usage:
#   track-tokens.sh <project_id> <agent> <model> <input_tokens> <output_tokens>
#   OR via environment variables
#   OR via JSON stdin

source ~/.claude/hooks/lib/common.sh 2>/dev/null || true

DB_FILE="$HOME/.claude/data/dashboard.db"
API_URL="${DASHBOARD_API:-http://127.0.0.1:31415/api/tokens}"

# Async SQLite write (non-blocking)
record_sqlite_async() {
  local project_id="$1" plan_id="${2:-NULL}" wave_id="${3:-}" task_id="${4:-}"
  local agent="$5" model="$6" input_tokens="$7" output_tokens="$8" cost_usd="${9:-0}"

  [[ ! -f "$DB_FILE" ]] && return 1

  # Background write - doesn't block hook
  {
    sqlite3 "$DB_FILE" "
      INSERT INTO token_usage (project_id, plan_id, wave_id, task_id, agent, model, input_tokens, output_tokens, cost_usd)
      VALUES ('$project_id', $plan_id, '$wave_id', '$task_id', '$agent', '$model', $input_tokens, $output_tokens, $cost_usd);
    " 2>/dev/null
  } &

  echo "Recorded: $input_tokens + $output_tokens tokens ($agent)"
}

# Async API write
record_api_async() {
  local json="$1"
  { curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "$json" >/dev/null 2>&1; } &
  echo "Recorded tokens via API"
}

# Parse input
if [[ $# -ge 5 ]]; then
  record_sqlite_async "$1" "NULL" "" "" "$2" "$3" "$4" "$5" "${6:-0}"
elif [[ -n "${PROJECT_ID:-}" ]] && [[ -n "${AGENT:-}" ]] && [[ -n "${MODEL:-}" ]]; then
  record_sqlite_async "$PROJECT_ID" "${PLAN_ID:-NULL}" "${WAVE_ID:-}" "${TASK_ID:-}" \
    "$AGENT" "$MODEL" "${INPUT_TOKENS:-0}" "${OUTPUT_TOKENS:-0}" "${COST_USD:-0}"
elif [[ ! -t 0 ]]; then
  json=$(cat)
  [[ -n "$json" ]] && record_api_async "$json"
fi

exit 0
