#!/bin/bash
# copilot-worker.sh - Launch Copilot CLI worker for a plan task
# Usage: copilot-worker.sh <db_task_id> [--model <model>] [--timeout <secs>]
# Version: 3.0.0 - submitted status flow, per-task Thor validation, SQLite trigger compatibility
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${HOME}/.claude/data/dashboard.db"
source "${SCRIPT_DIR}/lib/delegate-utils.sh"
source "${SCRIPT_DIR}/lib/agent-protocol.sh"

TASK_ID="${1:-}"
shift || true

# Defaults (gpt-5.3-codex = cheapest adequate for most tasks)
MODEL="gpt-5.3-codex"
TIMEOUT=600
MAX_RETRIES=3
RETRY_DELAYS=(5 15 30) # Exponential backoff: 5s, 15s, 30s

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

if [[ -z "${GH_TOKEN:-}" && -z "${COPILOT_TOKEN:-}" ]] && ! gh auth status &>/dev/null 2>&1; then
	echo '{"error":"No auth: set GH_TOKEN, COPILOT_TOKEN, or run gh auth login"}' >&2
	exit 1
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

# Get context for execution and delegation log
TASK_CTX=$(sqlite3 "$DB_FILE" "
	SELECT json_object(
		'worktree', COALESCE(p.worktree_path,''),
		'plan_id', COALESCE(t.plan_id,0),
		'project_id', COALESCE(p.project_id,''),
		'task_type', COALESCE(t.type,'code'),
		'task_title', COALESCE(t.title,'')
	)
	FROM tasks t
	JOIN plans p ON t.plan_id = p.id
	WHERE t.id = $TASK_ID;
")
WT="$(echo "$TASK_CTX" | jq -r '.worktree // ""')"
WT="${WT/#\~/$HOME}"
PLAN_ID="$(echo "$TASK_CTX" | jq -r '.plan_id // 0')"
PROJECT_ID="$(echo "$TASK_CTX" | jq -r '.project_id // ""')"
TASK_TYPE="$(echo "$TASK_CTX" | jq -r '.task_type // "code"')"
TASK_TITLE="$(echo "$TASK_CTX" | jq -r '.task_title // ""')"

# Generate prompt
PROMPT=$("$SCRIPT_DIR/copilot-task-prompt.sh" "$TASK_ID")
PROMPT_TOKENS="$(_ap_tokens "$PROMPT" 2>/dev/null || echo 0)"

echo "Launching Copilot worker for task $TASK_ID (timeout: ${TIMEOUT}s, max retries: $MAX_RETRIES)..."

# Execute with retry logic for timeout (exit 124)
execute_copilot() {
	local attempt="${1:-1}"
	local exit_code=0
	local start_ts copilot_stdout_file

	start_ts="$(date +%s)"
	copilot_stdout_file="$(mktemp)"

	# Pipe copilot output to tee: file + stderr (visible to user)
	# Only metadata echo goes to stdout (captured by caller)
	timeout "$TIMEOUT" copilot --yolo --add-dir "$WT" \
		--model "$MODEL" -p "$PROMPT" 2>&1 | tee "$copilot_stdout_file" >&2 || true
	exit_code="${PIPESTATUS[0]}"

	echo "$exit_code|$copilot_stdout_file|$(($(date +%s) - start_ts))"
}

# Main execution loop with retry logic
ATTEMPT=1
TOTAL_DURATION=0
FINAL_EXIT_CODE=0
COPILOT_OUTPUT=""

while [[ $ATTEMPT -le $MAX_RETRIES ]]; do
	echo "Attempt $ATTEMPT/$MAX_RETRIES..."

	EXEC_RESULT=$(execute_copilot "$ATTEMPT")
	EXEC_EXIT_CODE="${EXEC_RESULT%%|*}"
	EXEC_STDOUT_FILE="${EXEC_RESULT#*|}"
	EXEC_STDOUT_FILE="${EXEC_STDOUT_FILE%|*}"
	EXEC_DURATION="${EXEC_RESULT##*|}"
	TOTAL_DURATION=$((TOTAL_DURATION + EXEC_DURATION))
	COPILOT_OUTPUT="$(<"$EXEC_STDOUT_FILE")"

	# Exit codes: 0=success, 1=error, 124=timeout, 130=interrupted

	if [[ "$EXEC_EXIT_CODE" -eq 0 ]]; then
		FINAL_EXIT_CODE=0
		rm -f "$EXEC_STDOUT_FILE"
		break
	elif [[ "$EXEC_EXIT_CODE" -eq 124 ]]; then
		rm -f "$EXEC_STDOUT_FILE"
		if [[ $ATTEMPT -lt $MAX_RETRIES ]]; then
			RETRY_DELAY="${RETRY_DELAYS[$((ATTEMPT - 1))]}"
			echo "Timeout (exit 124). Retrying in ${RETRY_DELAY}s..." >&2
			sleep "$RETRY_DELAY"
			((ATTEMPT++))
		else
			echo "Timeout after $MAX_RETRIES attempts. Giving up." >&2
			FINAL_EXIT_CODE=124
			break
		fi
	elif [[ "$EXEC_EXIT_CODE" -eq 130 ]]; then
		echo "Interrupted by user (exit 130)." >&2
		FINAL_EXIT_CODE=130
		rm -f "$EXEC_STDOUT_FILE"
		break
	else
		echo "Copilot failed with exit code $EXEC_EXIT_CODE." >&2
		FINAL_EXIT_CODE="$EXEC_EXIT_CODE"
		rm -f "$EXEC_STDOUT_FILE"
		break
	fi
done

EXIT_CODE="$FINAL_EXIT_CODE"
START_TS="$(($(date +%s) - TOTAL_DURATION))"

# Parse worker output
WORKER_RESULT_JSON="$(echo "$COPILOT_OUTPUT" | parse_worker_result 2>/dev/null || echo '{}')"
TOKENS_USED="$(echo "$WORKER_RESULT_JSON" | jq -r '.tokens_used // 0' 2>/dev/null || echo 0)"
if [[ "$TOKENS_USED" == "0" ]]; then
	TOKENS_USED="$(_ap_tokens "$COPILOT_OUTPUT" 2>/dev/null || echo 0)"
fi

# Process results and update task status based on exit code
FINAL_STATUS=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id=$TASK_ID;")
NOTE=""
THOR_RESULT="UNKNOWN"
STASH_REF=""

if [[ "$EXIT_CODE" -eq 124 ]]; then
	if verify_work_done "$WT" >/dev/null 2>&1; then
		(cd "$WT" && git stash push --include-untracked \
			--message "copilot-worker timeout task ${TASK_ID}") >/dev/null 2>&1 || true
		STASH_REF="$(git -C "$WT" rev-parse --verify --short stash@{0} 2>/dev/null || true)"
	fi
	NOTE="Timeout after $ATTEMPT attempts (${TOTAL_DURATION}s total)"
	[[ -n "$STASH_REF" ]] && NOTE="${NOTE}; stash=${STASH_REF}"
	safe_update_task "$TASK_ID" blocked "$NOTE" --tokens "$TOKENS_USED" || true
	echo "{\"status\":\"timeout\",\"task_id\":${TASK_ID},\"attempts\":${ATTEMPT},\"stash_ref\":\"${STASH_REF}\"}" >&2
	THOR_RESULT="REJECT"
elif [[ "$EXIT_CODE" -eq 130 ]]; then
	NOTE="Interrupted by user"
	safe_update_task "$TASK_ID" blocked "$NOTE" --tokens "$TOKENS_USED" || true
	echo "{\"status\":\"interrupted\",\"task_id\":${TASK_ID}}" >&2
	THOR_RESULT="REJECT"
elif [[ "$EXIT_CODE" -ne 0 ]]; then
	NOTE="Copilot error (exit $EXIT_CODE)"
	safe_update_task "$TASK_ID" blocked "$NOTE" --tokens "$TOKENS_USED" || true
	echo "{\"status\":\"error\",\"task_id\":${TASK_ID},\"exit_code\":${EXIT_CODE}}" >&2
	THOR_RESULT="REJECT"
elif [[ "$FINAL_STATUS" != "done" && "$FINAL_STATUS" != "submitted" ]]; then
	# Check if this is a verification/closure task that doesn't require file changes
	_title_lower="$(echo "$TASK_TITLE" | tr '[:upper:]' '[:lower:]')"
	IS_VERIFY_TASK=false
	if [[ "$TASK_TYPE" == "chore" && "$_title_lower" == create\ pr* ]]; then IS_VERIFY_TASK=true; fi
	if [[ "$TASK_TYPE" == "test" ]] && [[ "$_title_lower" == verify* || "$_title_lower" == consolidate\ and\ verify* || "$_title_lower" == run\ full\ validation* ]]; then IS_VERIFY_TASK=true; fi
	if [[ "$TASK_TYPE" == "doc" || "$TASK_TYPE" == "docs" ]]; then IS_VERIFY_TASK=true; fi

	if WORK_DONE="$(verify_work_done "$WT" 2>/dev/null)"; then
		ARTIFACTS_JSON="$(git -C "$WT" status --porcelain | awk '{print $2}' | jq -Rsc 'split("\n") | map(select(length>0)) | unique')"
		OUTPUT_DATA="$(jq -cn --arg summary 'Auto-completed from detected worktree changes' --argjson artifacts "$ARTIFACTS_JSON" '{summary:$summary,artifacts:$artifacts}')"
		NOTE="Auto-completed: worker changed files but task status was not updated"
		safe_update_task "$TASK_ID" done "$NOTE" --tokens "$TOKENS_USED" --output-data "$OUTPUT_DATA" || true
		# plan-db-safe.sh sets 'submitted' (not done). Thor validation required.
		FINAL_STATUS="submitted"
		THOR_RESULT="PENDING"
		echo '{"status":"submitted","task_id":'$TASK_ID',"copilot_exit":'$EXIT_CODE'}'
	elif [[ "$IS_VERIFY_TASK" == true && "$EXIT_CODE" -eq 0 ]]; then
		NOTE="Auto-completed: verification/closure task with clean exit (no file changes expected)"
		OUTPUT_DATA='{"summary":"Verification task completed without file changes","artifacts":[]}'
		safe_update_task "$TASK_ID" done "$NOTE" --tokens "$TOKENS_USED" --output-data "$OUTPUT_DATA" || true
		FINAL_STATUS="submitted"
		THOR_RESULT="PENDING"
		echo '{"status":"submitted","task_id":'$TASK_ID',"copilot_exit":'$EXIT_CODE'}'
	else
		NOTE="Copilot exited without completing"
		safe_update_task "$TASK_ID" blocked "$NOTE" --tokens "$TOKENS_USED" || true
		echo '{"status":"incomplete","task_id":'$TASK_ID',"copilot_exit":'$EXIT_CODE'}' >&2
		THOR_RESULT="REJECT"
	fi
else
	# Task was marked submitted by the Copilot agent itself (via plan-db-safe.sh)
	# or already done from a previous run
	echo '{"status":"'$FINAL_STATUS'","task_id":'$TASK_ID'}'
	if [[ "$FINAL_STATUS" == "done" ]]; then
		THOR_RESULT="PASS"
	else
		THOR_RESULT="PENDING"
	fi
fi

# Log delegation with proper duration
DURATION_MS="$((TOTAL_DURATION * 1000))"
log_delegation "$TASK_ID" "$PLAN_ID" "$PROJECT_ID" "copilot" "$MODEL" \
	"$PROMPT_TOKENS" "$TOKENS_USED" "$DURATION_MS" "$EXIT_CODE" "$THOR_RESULT" "0" "unknown" || true

# Run Thor validation if task is submitted (awaiting validation)
if [[ "$FINAL_STATUS" == "submitted" || "$THOR_RESULT" == "PENDING" ]]; then
	echo "Running Thor per-task validation for task $TASK_ID in plan $PLAN_ID..."
	if "$SCRIPT_DIR/plan-db.sh" validate-task "$TASK_ID" "$PLAN_ID" thor 2>&1; then
		echo "Thor validation: PASSED (submitted → done)"
		THOR_RESULT="PASS"
		FINAL_STATUS="done"
	else
		echo "Thor validation: FAILED — task stays submitted" >&2
		THOR_RESULT="REJECT"
	fi
elif [[ "$FINAL_STATUS" == "done" && "$THOR_RESULT" == "PASS" ]]; then
	echo "Task already done + validated, skipping Thor."
fi

exit $EXIT_CODE
