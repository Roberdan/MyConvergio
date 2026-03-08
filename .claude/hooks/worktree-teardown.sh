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
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(cd "$HOOK_DIR/.." && pwd)"
MYCONVERGIO_HOME="${MYCONVERGIO_HOME:-$HOME/.myconvergio}"
FILE_LOCK_SCRIPT="${MYCONVERGIO_FILE_LOCK_SCRIPT:-$CLAUDE_DIR/scripts/file-lock.sh}"

if [[ -x "$FILE_LOCK_SCRIPT" ]]; then
	"$FILE_LOCK_SCRIPT" release-session "$SESSION_ID" 2>/dev/null || true
elif command -v file-lock.sh >/dev/null 2>&1; then
	file-lock.sh release-session "$SESSION_ID" 2>/dev/null || true
fi

exit 0
