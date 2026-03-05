#!/usr/bin/env bash
# Launch OpenCode worker for a plan task.
# Usage: opencode-worker.sh <db_task_id> [--model <model>] [--timeout <secs>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${PLAN_DB_FILE:-${DB_FILE:-${CLAUDE_HOME:-$HOME/.claude}/data/dashboard.db}}"

# shellcheck source=scripts/lib/delegate-utils.sh
source "${SCRIPT_DIR}/lib/delegate-utils.sh"
# shellcheck source=scripts/lib/agent-protocol.sh
source "${SCRIPT_DIR}/lib/agent-protocol.sh"

TASK_DB_ID="${1:-}"
shift || true

MODEL="gpt-5"
TIMEOUT=600

while [[ $# -gt 0 ]]; do
case "$1" in
--model)
MODEL="$2"
shift 2
;;
--timeout)
TIMEOUT="$2"
shift 2
;;
*)
shift
;;
esac
done

usage() {
echo "Usage: opencode-worker.sh <db_task_id> [--model <model>] [--timeout <secs>]" >&2
}

if [[ -z "$TASK_DB_ID" ]]; then
usage
exit 1
fi
if [[ ! "$TASK_DB_ID" =~ ^[0-9]+$ ]]; then
echo "ERROR: task id must be numeric" >&2
exit 1
fi
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
echo "ERROR: timeout must be numeric" >&2
exit 1
fi

if ! check_cli_available "opencode"; then
echo "ERROR: opencode CLI auth check failed" >&2
exit 1
fi

TASK_SPEC="$(read_task_spec "$TASK_DB_ID")"
if [[ -z "$TASK_SPEC" || "$TASK_SPEC" == "null" ]]; then
echo "ERROR: task not found: $TASK_DB_ID" >&2
exit 1
fi

STATUS="$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id=$TASK_DB_ID;")"
if [[ "$STATUS" != "pending" && "$STATUS" != "in_progress" ]]; then
echo "ERROR: task status is $STATUS (expected pending/in_progress)" >&2
exit 1
fi

PLAN_ID="$(echo "$TASK_SPEC" | jq -r '.plan_id')"
PROJECT_ID="$(echo "$TASK_SPEC" | jq -r '.project_id')"
WORKTREE_RAW="$(echo "$TASK_SPEC" | jq -r '.worktree_path')"
WORKTREE="${WORKTREE_RAW/#\~/$HOME}"
PROMPT="$(build_task_envelope "$TASK_DB_ID" "$DB_FILE")"
PROMPT_TOKENS="$(printf '%s' "$PROMPT" | python3 -c 'import math,sys;print(max(0,math.ceil(len(sys.stdin.read())/4)))')"

START_TS="$(date +%s)"
EXIT_CODE=1
FINAL_STATUS="$STATUS"

log_and_exit() {
local end_ts duration_ms
end_ts="$(date +%s)"
duration_ms=$(( (end_ts - START_TS) * 1000 ))
log_delegation "$TASK_DB_ID" "$PLAN_ID" "$PROJECT_ID" "opencode" "$MODEL" \
"$PROMPT_TOKENS" "0" "$duration_ms" "$EXIT_CODE" "$FINAL_STATUS" "0" "internal" || true
exit "$EXIT_CODE"
}

recover_on_timeout() {
local stash_msg
stash_msg="timeout-${TASK_DB_ID}-$(date +%s)"
if [[ -d "$WORKTREE" ]]; then
git -C "$WORKTREE" stash push --include-untracked -m "$stash_msg" >/dev/null 2>&1 || true
fi
safe_update_task "$TASK_DB_ID" blocked "OpenCode timeout after ${TIMEOUT}s; git stash created for recovery" || true
}

echo "Launching OpenCode worker for task $TASK_DB_ID (timeout: ${TIMEOUT}s)..."

if timeout "$TIMEOUT" opencode -p "$PROMPT" -q --model "$MODEL"; then
EXIT_CODE=0
else
EXIT_CODE=$?
fi

if verify_work_done "$WORKTREE" >/dev/null 2>&1; then
FINAL_STATUS="$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id=$TASK_DB_ID;")"
if [[ "$FINAL_STATUS" != "done" ]]; then
safe_update_task "$TASK_DB_ID" done "Auto-marked done by opencode-worker after detected file changes." || true
FINAL_STATUS="$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id=$TASK_DB_ID;")"
fi
else
FINAL_STATUS="$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id=$TASK_DB_ID;")"
fi

if [[ "$EXIT_CODE" -eq 124 ]]; then
recover_on_timeout
FINAL_STATUS="$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id=$TASK_DB_ID;")"
fi

log_and_exit
