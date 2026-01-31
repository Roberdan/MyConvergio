#!/bin/bash
# Worktree Guard - BLOCKS git write operations on main/master when worktrees exist
# Hook for PreToolUse on Bash commands
# Exit 2 = BLOCK (stderr shown to Claude), Exit 0 = ALLOW

# Read the tool input JSON from stdin
INPUT=$(cat)

# Extract the command from the JSON
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Only check git commands that modify state
if ! echo "$COMMAND" | grep -qE '^git (commit|push|add|checkout|merge|rebase|reset|stash)'; then
    exit 0
fi

# Get current directory context
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$GIT_ROOT" ]; then
    exit 0  # Not in a git repo, let it fail naturally
fi

# Check if we're in a worktree scenario (multiple worktrees exist)
WORKTREE_COUNT=$(git worktree list 2>/dev/null | /usr/bin/wc -l | tr -d ' ')
if [ "$WORKTREE_COUNT" -le 1 ]; then
    exit 0  # Single repo, no worktree confusion possible
fi

# Multi-worktree scenario: check if we're on main/master (the protected branch)
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "DETACHED")

if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    # BLOCK: git write operation on main/master with active worktrees
    CURRENT_DIR=$(basename "$GIT_ROOT")
    echo "[WORKTREE GUARD] BLOCKED: git write operation on '$CURRENT_BRANCH' while $WORKTREE_COUNT worktrees are active." >&2
    echo "  PWD: $CURRENT_DIR | Branch: $CURRENT_BRANCH" >&2
    echo "  Active worktrees:" >&2
    git worktree list 2>/dev/null | while read -r line; do
        echo "    $line" >&2
    done
    echo "  FIX: cd to the correct worktree directory, or use:" >&2
    echo "    ~/.claude/scripts/worktree-check.sh   # See all worktrees" >&2
    echo "    plan-db.sh get-worktree <plan_id>     # Get worktree for a plan" >&2
    exit 2
fi

# On a non-main branch (likely a worktree branch) - allow but log context
exit 0
