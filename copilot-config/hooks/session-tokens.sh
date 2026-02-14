#!/usr/bin/env bash
set -euo pipefail

# session-tokens.sh — Copilot CLI sessionEnd hook
# Records token usage to dashboard.db for Copilot CLI sessions.
# Input: JSON via stdin (Copilot hook protocol)

DB_FILE="$HOME/.claude/data/dashboard.db"
LOG_FILE="$HOME/.claude/logs/copilot-token-tracking.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

log() { echo "$(date '+%H:%M:%S') $1" >>"$LOG_FILE" 2>/dev/null & }

# Check dependencies
for cmd in jq sqlite3; do
	command -v "$cmd" >/dev/null 2>&1 || exit 0
done

[ ! -f "$DB_FILE" ] && exit 0

# Read hook input
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# Get project_id from DB
PROJECT_ID=""
if [[ -n "$CWD" ]]; then
	PROJECT_ID=$(sqlite3 "$DB_FILE" \
		"SELECT id FROM projects WHERE path LIKE '%${CWD}%' LIMIT 1;" 2>/dev/null || true)
fi
PROJECT_ID="${PROJECT_ID:-$(basename "${CWD:-unknown}")}"

# Parse transcript if available
INPUT_TOKENS=0
OUTPUT_TOKENS=0
MODEL="claude-opus-4.6"

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
	STATS=$(jq -s '
    [.[] | select(.type == "assistant" and .message.usage.input_tokens > 0)]
    | {
        input: (map(.message.usage.input_tokens) | add // 0),
        output: (map(.message.usage.output_tokens) | add // 0),
        model: (.[0].message.model // "claude-opus-4.6")
      }
  ' "$TRANSCRIPT_PATH" 2>/dev/null || echo '{"input":0,"output":0,"model":"claude-opus-4.6"}')

	INPUT_TOKENS=$(echo "$STATS" | jq -r '.input // 0')
	OUTPUT_TOKENS=$(echo "$STATS" | jq -r '.output // 0')
	MODEL=$(echo "$STATS" | jq -r '.model // "claude-opus-4.6"')
fi

TOTAL=$((INPUT_TOKENS + OUTPUT_TOKENS))
[[ $TOTAL -eq 0 ]] && {
	log "No tokens to record for session $SESSION_ID"
	exit 0
}

# Calculate cost
COST_USD=0
if command -v bc >/dev/null 2>&1; then
	case "$MODEL" in
	*opus*) COST_USD=$(echo "scale=4; ($INPUT_TOKENS * 0.000015) + ($OUTPUT_TOKENS * 0.000075)" | bc) ;;
	*) COST_USD=$(echo "scale=4; ($INPUT_TOKENS * 0.000003) + ($OUTPUT_TOKENS * 0.000015)" | bc) ;;
	esac
fi

# Async DB write
{
	EXEC_HOST="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
	EXEC_HOST="${EXEC_HOST%.local}"
	sqlite3 "$DB_FILE" "
    INSERT INTO token_usage (project_id, agent, model, input_tokens, output_tokens, cost_usd, execution_host)
    VALUES ('$PROJECT_ID', 'copilot-cli', '${MODEL}', $INPUT_TOKENS, $OUTPUT_TOKENS, ${COST_USD:-0}, '$EXEC_HOST');
  " 2>/dev/null
} &

log "$PROJECT_ID | copilot-cli | $MODEL | in:$INPUT_TOKENS out:$OUTPUT_TOKENS | \$${COST_USD}"
exit 0
