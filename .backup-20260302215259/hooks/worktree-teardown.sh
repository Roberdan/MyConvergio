#!/usr/bin/env bash
# Version: 1.0.0
# WorktreeRemove hook: release file locks for the worktree session on removal
set -euo pipefail

# Read worktree path from stdin JSON
WORKTREE_PATH=""
INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || true)

if [[ -z "$WORKTREE_PATH" ]]; then
	exit 0
fi

# Derive session id from worktree path (used as session key in file-lock)
SESSION_ID=$(echo "$WORKTREE_PATH" | tr '/' '_' | tr -cd '[:alnum:]_')

# Release all session-based file locks for this worktree
if command -v file-lock.sh >/dev/null 2>&1; then
	file-lock.sh release-session "$SESSION_ID" 2>/dev/null || true
fi

exit 0
