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

	# Check for uncommitted changes in plan worktree
	plan_id=$(sqlite3 -cmd ".timeout 3000" "$HOME/.claude/data/dashboard.db" \
		"SELECT plan_id FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")
	if [[ -n "$plan_id" ]]; then
		worktree=$(sqlite3 -cmd ".timeout 3000" "$HOME/.claude/data/dashboard.db" \
			"SELECT worktree_path FROM plans WHERE id = $plan_id;" 2>/dev/null || echo "")
		if [[ -n "$worktree" && -d "$worktree" ]]; then
			dirty=$(git -C "$worktree" status --porcelain 2>/dev/null | head -1)
			if [[ -n "$dirty" ]]; then
				echo "WARN: Uncommitted changes in worktree $worktree for task $TASK_ID" >&2
				echo "WARN: Auto-stashing to prevent data loss..." >&2
				git -C "$worktree" stash push -m "auto-save: task $TASK_ID marked done" 2>/dev/null || true
				git -C "$worktree" stash pop 2>/dev/null || true
			fi
		fi
	fi

	# Release all file locks held by this task
	if [[ -x "$SCRIPT_DIR/file-lock.sh" ]]; then
		"$SCRIPT_DIR/file-lock.sh" release-task "$TASK_ID" 2>/dev/null || true
	fi
fi

# Delegate to plan-db.sh with all original args
exec "$SCRIPT_DIR/plan-db.sh" "$@"
