#!/usr/bin/env bash
set -euo pipefail

# worktree-guard.sh — Copilot CLI preToolUse hook
# Warns on git writes to main/master when worktrees are active.
# POLICY: Warn, don't block. NEVER suggest deleting worktrees.
# Input: JSON via stdin (Copilot hook protocol)

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""' 2>/dev/null)

# Only check bash/shell tools
if [[ "$TOOL_NAME" != "bash" && "$TOOL_NAME" != "shell" ]]; then
	exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.toolArgs.command // ""' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Check git worktree add — BLOCK if path is inside current repo
if echo "$COMMAND" | grep -qE 'git worktree add'; then
	GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
	WT_PATH=$(echo "$COMMAND" | sed -E 's/.*git worktree add (-b [^ ]+ )?//' | awk '{print $1}')
	if [ -n "$WT_PATH" ] && [ -n "$GIT_ROOT" ]; then
		RESOLVED=$(cd "$(dirname "$WT_PATH")" 2>/dev/null && pwd)/$(basename "$WT_PATH") 2>/dev/null || true
		if [[ "$RESOLVED" == "$GIT_ROOT"/* ]]; then
			jq -n '{permissionDecision: "deny", permissionDecisionReason: "WORKTREE GUARD: Path is INSIDE the repo. Use a SIBLING path instead."}'
			exit 0
		fi
	fi
	exit 0
fi

# Only check git commands that modify state
if ! echo "$COMMAND" | grep -qE '^git (commit|push|add|checkout|merge|rebase|reset|stash)'; then
	exit 0
fi

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

WORKTREE_COUNT=$(git worktree list 2>/dev/null | grep -c '' || echo 0)
[ "$WORKTREE_COUNT" -le 1 ] && exit 0

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "DETACHED")

# BLOCK: git worktree remove
if echo "$COMMAND" | grep -qE 'git worktree remove'; then
	jq -n '{permissionDecision: "deny", permissionDecisionReason: "Use worktree-cleanup.sh instead of direct git worktree remove."}'
	exit 0
fi

# WARN on main with active worktrees (allow but warn via stderr)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
	echo "[WORKTREE GUARD] WARNING: git op on '$CURRENT_BRANCH' with $WORKTREE_COUNT worktrees active." >&2
	exit 0
fi

exit 0
