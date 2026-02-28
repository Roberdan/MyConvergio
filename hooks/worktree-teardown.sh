#!/usr/bin/env bash
# Version: 1.0.0
# Worktree teardown: release file locks for the worktree on removal.
# Not registered in hooks.json (Copilot CLI has no worktreeRemove phase).
# Call directly: worktree-teardown.sh <worktree_path>
set -euo pipefail

WORKTREE_PATH="${1:-}"

if [[ -z "$WORKTREE_PATH" ]]; then
	exit 0
fi

SESSION_ID=$(echo "$WORKTREE_PATH" | tr '/' '_' | tr -cd '[:alnum:]_')

if command -v file-lock.sh >/dev/null 2>&1; then
	file-lock.sh release-session "$SESSION_ID" 2>/dev/null || true
fi

exit 0
