#!/bin/bash
# Token Tracking Hook for Claude Code Dashboard
# Records token usage to the dashboard database
#
# Usage:
#   track-tokens.sh <project_id> <agent> <model> <input_tokens> <output_tokens>
#   OR via environment variables: PROJECT_ID, AGENT, MODEL, INPUT_TOKENS, OUTPUT_TOKENS
#
# Can also be called with JSON on stdin:
#   echo '{"project_id":"x","agent":"y","model":"z","input_tokens":100,"output_tokens":50}' | track-tokens.sh

set -e

DB_FILE="$HOME/.claude/data/dashboard.db"
API_URL="${DASHBOARD_API:-http://127.0.0.1:31415/api/tokens}"

# Function to record via direct SQLite
record_sqlite() {
  local project_id="$1"
  local plan_id="${2:-NULL}"
  local wave_id="${3:-}"
  local task_id="${4:-}"
  local agent="$5"
  local model="$6"
  local input_tokens="$7"
  local output_tokens="$8"
  local cost_usd="${9:-0}"

  if [[ ! -f "$DB_FILE" ]]; then
    echo "Error: Database not found at $DB_FILE" >&2
    exit 1
  fi

  sqlite3 "$DB_FILE" "
    INSERT INTO token_usage (project_id, plan_id, wave_id, task_id, agent, model, input_tokens, output_tokens, cost_usd)
    VALUES ('$project_id', $plan_id, '$wave_id', '$task_id', '$agent', '$model', $input_tokens, $output_tokens, $cost_usd);
  "

  echo "Recorded: $input_tokens + $output_tokens tokens for $agent on $project_id"
}

# Function to record via API
record_api() {
  local json="$1"

  curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "$json" > /dev/null

  echo "Recorded tokens via API"
}

# Parse input
if [[ $# -ge 5 ]]; then
  # Arguments provided
  record_sqlite "$1" "NULL" "" "" "$2" "$3" "$4" "$5" "${6:-0}"
elif [[ -n "$PROJECT_ID" ]] && [[ -n "$AGENT" ]] && [[ -n "$MODEL" ]] && [[ -n "$INPUT_TOKENS" ]] && [[ -n "$OUTPUT_TOKENS" ]]; then
  # Environment variables
  record_sqlite "$PROJECT_ID" "${PLAN_ID:-NULL}" "${WAVE_ID:-}" "${TASK_ID:-}" "$AGENT" "$MODEL" "$INPUT_TOKENS" "$OUTPUT_TOKENS" "${COST_USD:-0}"
elif [[ ! -t 0 ]]; then
  # Read JSON from stdin
  json=$(cat)
  if [[ -n "$json" ]]; then
    record_api "$json"
  else
    echo "Error: Empty input" >&2
    exit 1
  fi
else
  echo "Usage: $0 <project_id> <agent> <model> <input_tokens> <output_tokens> [cost_usd]"
  echo "  OR set env vars: PROJECT_ID, AGENT, MODEL, INPUT_TOKENS, OUTPUT_TOKENS"
  echo "  OR pipe JSON: {\"project_id\":\"x\",\"agent\":\"y\",\"model\":\"z\",\"input_tokens\":N,\"output_tokens\":M}"
  exit 1
fi
