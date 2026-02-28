#!/bin/bash
set -euo pipefail
# Unified worker launcher for Kitty tabs
# Usage: worker-launch.sh <type> <tab_name> <task_db_id> --cwd <worktree>
# Types: claude, copilot

# Version: 1.1.0
set -euo pipefail

TYPE="${1:?Usage: worker-launch.sh <claude|copilot> <tab_name> <task_db_id> --cwd <dir>}"
TAB_NAME="${2:?tab_name required}"
TASK_DB_ID="${3:?task_db_id required}"
shift 3

CWD="$(pwd)"
MODEL=""
while [[ $# -gt 0 ]]; do
	case $1 in
	--cwd)
		CWD="$2"
		shift 2
		;;
	--model)
		MODEL="$2"
		shift 2
		;;
	*) shift ;;
	esac
done

# Verify Kitty
if [[ -z "${KITTY_PID:-}" ]]; then
	echo "ERROR: Must run from inside Kitty terminal" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Generate prompt for the task
PROMPT=$("$SCRIPT_DIR/copilot-task-prompt.sh" "$TASK_DB_ID")

case "$TYPE" in
claude)
	# Resolve Claude command
	CLAUDE_CMD="claude --dangerously-skip-permissions"
	command -v wildClaude &>/dev/null && CLAUDE_CMD="wildClaude"

	kitty @ launch --type=tab --title="$TAB_NAME" --cwd="$CWD" \
		--keep-focus zsh -ic "$CLAUDE_CMD"
	sleep 3

	# Send task via keyboard (Claude uses interactive mode)
	kitty @ send-text --match "title:^${TAB_NAME}$" "$PROMPT
"
	;;

copilot)
	# Copilot runs in yolo mode (full autonomy, no confirmations)
	MODEL_FLAG=""
	[[ -n "$MODEL" ]] && MODEL_FLAG="--model $MODEL"

	kitty @ launch --type=tab --title="$TAB_NAME" --cwd="$CWD" \
		--keep-focus zsh -ic \
		"copilot --yolo --add-dir '$CWD' $MODEL_FLAG -p '$(echo "$PROMPT" | sed "s/'/'\\\\''/g")'"
	;;

*)
	echo "ERROR: Unknown type '$TYPE'. Use: claude|copilot" >&2
	exit 1
	;;
esac

echo "Launched $TYPE worker: $TAB_NAME (task $TASK_DB_ID)"
