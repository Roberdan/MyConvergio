#!/bin/bash
# Launch Copilot CLI worker for a plan task
# Usage: copilot-worker.sh <db_task_id> [--model <model>] [--timeout <secs>]
# Requires: copilot CLI installed, GH_TOKEN or COPILOT_TOKEN set

# Version: 2.1.0
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

# Get context for execution and delegation log
TASK_CTX=$(sqlite3 "$DB_FILE" "
	SELECT json_object(
		'worktree', COALESCE(p.worktree_path,''),
		'plan_id', COALESCE(t.plan_id,0),
		'project_id', COALESCE(p.project_id,'')
	)
	FROM tasks t
	JOIN plans p ON t.plan_id = p.id
	WHERE t.id = $TASK_ID;
")
WT="$(echo "$TASK_CTX" | jq -r '.worktree // ""')"
WT="${WT/#\~/$HOME}"
PLAN_ID="$(echo "$TASK_CTX" | jq -r '.plan_id // 0')"
PROJECT_ID="$(echo "$TASK_CTX" | jq -r '.project_id // ""')"

# Generate prompt
PROMPT=$("$SCRIPT_DIR/copilot-task-prompt.sh" "$TASK_ID")
PROMPT_TOKENS="$(_ap_tokens "$PROMPT" 2>/dev/null || echo 0)"

echo "Launching Copilot worker for task $TASK_ID (timeout: ${TIMEOUT}s)..."

# Launch copilot in non-interactive autonomous mode
EXIT_CODE=0
START_TS="$(date +%s)"
COPILOT_STDOUT_FILE="$(mktemp)"
cleanup() {
	rm -f "$COPILOT_STDOUT_FILE"
}
trap cleanup EXIT

timeout "$TIMEOUT" copilot \
	--allow-all \
	--no-ask-user \
	--add-dir "$WT" \
	--model "$MODEL" \
	-p "$PROMPT" > >(tee "$COPILOT_STDOUT_FILE") || EXIT_CODE=$?

WORKER_RESULT_JSON="$(parse_worker_result "$COPILOT_STDOUT_FILE" 2>/dev/null || echo '{}')"
TOKENS_USED="$(echo "$WORKER_RESULT_JSON" | jq -r '.tokens_used // 0' 2>/dev/null || echo 0)"
if [[ "$TOKENS_USED" == "0" ]]; then
	TOKENS_USED="$(_ap_tokens "$(<"$COPILOT_STDOUT_FILE")" 2>/dev/null || echo 0)"
fi

# Verify task was updated in DB
FINAL_STATUS=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id=$TASK_ID;")
NOTE=""
THOR_RESULT="UNKNOWN"
STASH_REF=""

if [[ "$EXIT_CODE" -eq 124 ]]; then
	if verify_work_done "$WT" >/dev/null 2>&1; then
		(
			cd "$WT"
			git stash push --include-untracked \
				--message "copilot-worker timeout task ${TASK_ID}"
		) >/dev/null 2>&1 || true
		STASH_REF="$(git -C "$WT" rev-parse --verify --short stash@{0} 2>/dev/null || true)"
	fi
	NOTE="Copilot timeout after ${TIMEOUT}s"
	[[ -n "$STASH_REF" ]] && NOTE="${NOTE}; stash=${STASH_REF}"
	safe_update_task "$TASK_ID" blocked "$NOTE" --tokens "$TOKENS_USED" || true
	echo "{\"status\":\"timeout\",\"task_id\":${TASK_ID},\"stash_ref\":\"${STASH_REF}\"}" >&2
	THOR_RESULT="REJECT"
elif [[ "$FINAL_STATUS" != "done" ]]; then
	if WORK_DONE="$(verify_work_done "$WT" 2>/dev/null)"; then
		ARTIFACTS_JSON="$(git -C "$WT" status --porcelain | awk '{print $2}' | jq -Rsc 'split("\n") | map(select(length>0)) | unique')"
		OUTPUT_DATA="$(jq -cn --arg summary 'Auto-completed from detected worktree changes' --argjson artifacts "$ARTIFACTS_JSON" '{summary:$summary,artifacts:$artifacts}')"
		NOTE="Auto-completed: worker changed files but task status was not updated"
		safe_update_task "$TASK_ID" done "$NOTE" --tokens "$TOKENS_USED" --output-data "$OUTPUT_DATA" || true
		FINAL_STATUS="done"
		THOR_RESULT="PASS"
		echo '{"status":"auto_done","task_id":'$TASK_ID',"copilot_exit":'$EXIT_CODE'}'
	else
		NOTE="Copilot exited without completing"
		safe_update_task "$TASK_ID" blocked "$NOTE" --tokens "$TOKENS_USED" || true
		echo '{"status":"incomplete","task_id":'$TASK_ID',"copilot_exit":'$EXIT_CODE'}' >&2
		THOR_RESULT="REJECT"
	fi
else
	echo '{"status":"done","task_id":'$TASK_ID'}'
	THOR_RESULT="PASS"
fi

DURATION_MS="$(( ($(date +%s) - START_TS) * 1000 ))"
log_delegation "$TASK_ID" "$PLAN_ID" "$PROJECT_ID" "copilot" "$MODEL" \
	"$PROMPT_TOKENS" "$TOKENS_USED" "$DURATION_MS" "$EXIT_CODE" "$THOR_RESULT" "0" "unknown" || true

exit $EXIT_CODE
