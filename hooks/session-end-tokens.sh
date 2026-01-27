#!/bin/bash
# Session End Token Tracker - Optimized with jq streaming
# Called by Claude Code Stop hook to record token usage

source ~/.claude/hooks/lib/common.sh 2>/dev/null || true

DB_FILE="$HOME/.claude/data/dashboard.db"
LOG_FILE="$HOME/.claude/logs/token-tracking.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG_FILE" 2>/dev/null & }

# Quick dependency check
check_deps jq sqlite3 || exit 0

# Read hook input
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

[[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]] && exit 0

# Get project_id
PROJECT_ID=""
if [[ -n "$CWD" && -f "$DB_FILE" ]]; then
  PROJECT_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM projects WHERE path LIKE '%${CWD}%' LIMIT 1;" 2>/dev/null)
fi
PROJECT_ID="${PROJECT_ID:-$(basename "$CWD")}"

# Stream parse with jq (much faster for large files)
STATS=$(jq -s '
  [.[] | select(.type == "assistant" and .message.usage.input_tokens > 0)]
  | {
      input: (map(.message.usage.input_tokens) | add // 0),
      output: (map(.message.usage.output_tokens) | add // 0),
      model: (.[0].message.model // "unknown")
    }
' "$TRANSCRIPT_PATH" 2>/dev/null)

INPUT_TOKENS=$(echo "$STATS" | jq -r '.input // 0')
OUTPUT_TOKENS=$(echo "$STATS" | jq -r '.output // 0')
MODEL=$(echo "$STATS" | jq -r '.model // "unknown"')

TOTAL=$((INPUT_TOKENS + OUTPUT_TOKENS))
[[ $TOTAL -eq 0 ]] && exit 0

# Calculate cost
COST_USD=0
if have_bin bc; then
  case "$MODEL" in
    *opus*) COST_USD=$(echo "scale=4; ($INPUT_TOKENS * 0.000015) + ($OUTPUT_TOKENS * 0.000075)" | bc) ;;
    *) COST_USD=$(echo "scale=4; ($INPUT_TOKENS * 0.000003) + ($OUTPUT_TOKENS * 0.000015)" | bc) ;;
  esac
fi

# Async DB write
if [[ -f "$DB_FILE" ]]; then
  {
    sqlite3 "$DB_FILE" "
      INSERT INTO token_usage (project_id, agent, model, input_tokens, output_tokens, cost_usd)
      VALUES ('$PROJECT_ID', 'claude-code', '${MODEL}', $INPUT_TOKENS, $OUTPUT_TOKENS, ${COST_USD:-0});
    " 2>/dev/null
  } &
fi

log "$PROJECT_ID | $MODEL | in:$INPUT_TOKENS out:$OUTPUT_TOKENS | \$${COST_USD}"
exit 0
