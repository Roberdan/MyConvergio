#!/bin/bash
# Session End Token Tracker
# Called by Claude Code Stop hook to record token usage

set -u

DB_FILE="$HOME/.claude/data/dashboard.db"
LOG_FILE="$HOME/.claude/logs/token-tracking.log"

# Create log dir if needed
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

have_bin() {
  command -v "$1" >/dev/null 2>&1
}

if ! have_bin jq; then
  log "Missing dependency: jq"
  exit 0
fi
if ! have_bin sqlite3; then
  log "Missing dependency: sqlite3"
  exit 0
fi

# Read hook input from stdin
INPUT=$(cat)

# Parse required fields
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  log "No transcript found: $TRANSCRIPT_PATH"
  exit 0
fi

# Determine project_id from cwd
PROJECT_ID=""
if [[ -n "$CWD" ]]; then
  # Check if it's a registered project
  if [[ -f "$DB_FILE" ]]; then
    PROJECT_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM projects WHERE path LIKE '%${CWD}%' LIMIT 1;" 2>/dev/null || echo "")
  fi
  # Fallback to directory name
  if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID=$(basename "$CWD")
  fi
fi

# Parse transcript for token usage
# Transcript is JSONL format - each line is a JSON object
INPUT_TOKENS=0
OUTPUT_TOKENS=0
MODEL=""
AGENT="claude-code"

while IFS= read -r line; do
  # Skip empty lines
  [[ -z "$line" ]] && continue

  # Look for assistant messages with usage data
  TYPE=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

  if [[ "$TYPE" == "assistant" ]]; then
    # Extract usage if present
    USAGE_IN=$(echo "$line" | jq -r '.message.usage.input_tokens // 0' 2>/dev/null)
    USAGE_OUT=$(echo "$line" | jq -r '.message.usage.output_tokens // 0' 2>/dev/null)
    MSG_MODEL=$(echo "$line" | jq -r '.message.model // empty' 2>/dev/null)

    if [[ "$USAGE_IN" != "0" ]] || [[ "$USAGE_OUT" != "0" ]]; then
      INPUT_TOKENS=$((INPUT_TOKENS + USAGE_IN))
      OUTPUT_TOKENS=$((OUTPUT_TOKENS + USAGE_OUT))
      [[ -n "$MSG_MODEL" ]] && MODEL="$MSG_MODEL"
    fi
  fi
done < "$TRANSCRIPT_PATH"

TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))

# Only record if we have token data
if [[ $TOTAL_TOKENS -eq 0 ]]; then
  log "No tokens in session $SESSION_ID"
  exit 0
fi

# Calculate approximate cost (Claude pricing)
# Opus: $15/1M input, $75/1M output
# Sonnet: $3/1M input, $15/1M output
COST_USD=0
if have_bin bc; then
  if [[ "$MODEL" == *"opus"* ]]; then
    COST_USD=$(echo "scale=4; ($INPUT_TOKENS * 0.000015) + ($OUTPUT_TOKENS * 0.000075)" | bc)
  elif [[ "$MODEL" == *"sonnet"* ]]; then
    COST_USD=$(echo "scale=4; ($INPUT_TOKENS * 0.000003) + ($OUTPUT_TOKENS * 0.000015)" | bc)
  else
    # Default to sonnet pricing
    COST_USD=$(echo "scale=4; ($INPUT_TOKENS * 0.000003) + ($OUTPUT_TOKENS * 0.000015)" | bc)
  fi
else
  log "Missing dependency: bc (cost set to 0)"
fi

# Record to database
if [[ -f "$DB_FILE" ]]; then
  sqlite3 "$DB_FILE" "
    INSERT INTO token_usage (project_id, agent, model, input_tokens, output_tokens, cost_usd)
    VALUES ('$PROJECT_ID', '$AGENT', '${MODEL:-unknown}', $INPUT_TOKENS, $OUTPUT_TOKENS, ${COST_USD:-0});
  " 2>/dev/null || log "DB insert failed"
fi

log "Recorded: $PROJECT_ID | $MODEL | in:$INPUT_TOKENS out:$OUTPUT_TOKENS | \$${COST_USD}"

exit 0
