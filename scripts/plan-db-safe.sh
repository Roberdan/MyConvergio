#!/bin/bash
# plan-db-safe.sh - Safe wrapper around plan-db.sh
# Auto-releases file locks and checks staleness before marking done.
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extract task_id from args (first numeric arg after command)
COMMAND="${1:-}"
TASK_ID="${2:-}"

if [[ "$COMMAND" == "update-task" && "${3:-}" == "done" ]]; then
	# Before marking done: check staleness if stale-check.sh is available
	if [[ -x "$SCRIPT_DIR/stale-check.sh" ]]; then
		stale_result=$("$SCRIPT_DIR/stale-check.sh" check "$TASK_ID" 2>/dev/null || echo "ok")
		if [[ "$stale_result" == *"stale=true"* ]]; then
			echo "ERROR: Stale files detected for task $TASK_ID. Rebase before marking done." >&2
			exit 1
		fi
	fi

	# Release all file locks held by this task
	if [[ -x "$SCRIPT_DIR/file-lock.sh" ]]; then
		"$SCRIPT_DIR/file-lock.sh" release-task "$TASK_ID" 2>/dev/null || true
	fi
fi

# Delegate to plan-db.sh with all original args
exec "$SCRIPT_DIR/plan-db.sh" "$@"
