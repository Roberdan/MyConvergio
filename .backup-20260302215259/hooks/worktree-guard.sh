#!/bin/bash
# Worktree Guard - Warns on main operations with active worktrees
# Hook for PreToolUse on Bash commands
# Exit 2 = BLOCK, Exit 0 = ALLOW
# Version: 1.1.0
#
# POLICY: Warn, don't block. NEVER suggest deleting worktrees.
# Other agents/sessions may be using them.
set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Check git worktree add — BLOCK if path is inside current repo
if echo "$COMMAND" | grep -qE 'git worktree add'; then
	GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
	# Extract the path argument (first non-flag arg after 'add')
	WT_PATH=$(echo "$COMMAND" | sed -E 's/.*git worktree add (-b [^ ]+ )?//' | awk '{print $1}')
	if [ -n "$WT_PATH" ] && [ -n "$GIT_ROOT" ]; then
		RESOLVED=$(cd "$(dirname "$WT_PATH")" 2>/dev/null && pwd)/$(basename "$WT_PATH") 2>/dev/null || true
		if [[ "$RESOLVED" == "$GIT_ROOT"/* ]]; then
			echo "[WORKTREE GUARD] BLOCKED: Worktree path is INSIDE the repo!" >&2
			echo "  Path: $WT_PATH (resolves to $RESOLVED)" >&2
			echo "  This poisons TypeScript, ESLint, and build for the main repo." >&2
			echo "  Use a SIBLING path: $GIT_ROOT/../<name>" >&2
			exit 2
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

# BLOCK: git worktree remove (protect other agents' work)
# ALLOW: worktree-cleanup.sh (safe - verifies merge before removing)
if echo "$COMMAND" | grep -qE 'git worktree remove'; then
	echo "[WORKTREE GUARD] BLOCKED: Use worktree-cleanup.sh instead of direct git worktree remove." >&2
	echo "  worktree-cleanup.sh --branch <branch> (verifies merge + updates DB)" >&2
	echo "  worktree-cleanup.sh --plan <id> (cleanup by plan ID)" >&2
	echo "  worktree-cleanup.sh --all-merged (cleanup all merged worktrees)" >&2
	exit 2
fi

# WARN (not block) on main with active worktrees
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
	echo "[WORKTREE GUARD] WARNING: git operation on '$CURRENT_BRANCH' with $WORKTREE_COUNT worktrees active." >&2
	echo "  Proceeding. Make sure you intend to commit to main." >&2
	exit 0
fi

exit 0
