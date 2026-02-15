#!/bin/bash
# Launch Copilot CLI worker for a plan task
# Usage: copilot-worker.sh <db_task_id> [--model <model>] [--timeout <secs>]
# Requires: copilot CLI installed, GH_TOKEN or COPILOT_TOKEN set

# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${HOME}/.claude/data/dashboard.db"

TASK_ID="${1:-}"
shift || true

# Defaults
MODEL="claude-opus-4.6"
TIMEOUT=600

# Parse optional flags
while [[ $# -gt 0 ]]; do
	case $1 in
	--model)
		MODEL="$2"
		shift 2
		;;
	--timeout)
		TIMEOUT="$2"
		shift 2
		;;
	*) shift ;;
	esac
done

if [[ -z "$TASK_ID" ]]; then
	echo "Usage: copilot-worker.sh <db_task_id> [--model <model>] [--timeout <secs>]" >&2
	exit 1
fi

# Preflight checks
if ! command -v copilot &>/dev/null; then
	echo '{"error":"copilot CLI not installed"}' >&2
	exit 1
fi

# Auth check: copilot uses gh auth or env tokens
if [[ -z "${GH_TOKEN:-}" && -z "${COPILOT_TOKEN:-}" ]]; then
	# Check if gh auth is available as fallback
	if ! gh auth status &>/dev/null 2>&1; then
		echo '{"error":"No auth: set GH_TOKEN, COPILOT_TOKEN, or run gh auth login"}' >&2
		exit 1
	fi
fi

# Verify task exists and is pending
STATUS=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id=$TASK_ID;")
if [[ -z "$STATUS" ]]; then
	echo '{"error":"task not found"}' >&2
	exit 1
fi
if [[ "$STATUS" != "pending" && "$STATUS" != "in_progress" ]]; then
	echo "{\"error\":\"task status is $STATUS, expected pending\"}" >&2
	exit 1
fi

# Get worktree path for --add-dir
WT=$(sqlite3 "$DB_FILE" "
	SELECT COALESCE(p.worktree_path,'')
	FROM tasks t JOIN plans p ON t.plan_id = p.id
	WHERE t.id = $TASK_ID;
")
WT="${WT/#\~/$HOME}"

# Generate prompt
PROMPT=$("$SCRIPT_DIR/copilot-task-prompt.sh" "$TASK_ID")

echo "Launching Copilot worker for task $TASK_ID (timeout: ${TIMEOUT}s)..."

# Launch copilot in non-interactive autonomous mode
EXIT_CODE=0
timeout "$TIMEOUT" copilot \
	--allow-all \
	--add-dir "$WT" \
	--model "$MODEL" \
	-p "$PROMPT" || EXIT_CODE=$?

# Verify task was updated in DB
FINAL_STATUS=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id=$TASK_ID;")

if [[ "$EXIT_CODE" -eq 124 ]]; then
	echo '{"status":"timeout","task_id":'$TASK_ID'}' >&2
	sqlite3 "$DB_FILE" \
		"UPDATE tasks SET status='blocked', notes='Copilot timeout after ${TIMEOUT}s' WHERE id=$TASK_ID;"
elif [[ "$FINAL_STATUS" != "done" ]]; then
	echo '{"status":"incomplete","task_id":'$TASK_ID',"copilot_exit":'$EXIT_CODE'}' >&2
	sqlite3 "$DB_FILE" \
		"UPDATE tasks SET status='blocked', notes='Copilot exited without completing' WHERE id=$TASK_ID;"
else
	echo '{"status":"done","task_id":'$TASK_ID'}'
fi

exit $EXIT_CODE
