#!/bin/bash
# Worktree Guard - Warns when git operations happen outside expected context
# Hook for PreToolUse on Bash commands
# Reads tool input from stdin, checks if it's a git operation in a worktree scenario

set -euo pipefail

# Read the tool input JSON from stdin
INPUT=$(cat)

# Extract the command from the JSON
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

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

# We're in a multi-worktree scenario - emit a warning
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "DETACHED")
CURRENT_DIR=$(basename "$GIT_ROOT")
DIRTY_COUNT=$(git status --porcelain 2>/dev/null | /usr/bin/wc -l | tr -d ' ')

# Build warning message
WARNING="[WORKTREE GUARD] Multi-worktree detected!"
WARNING="$WARNING | PWD: $CURRENT_DIR | Branch: $CURRENT_BRANCH"
if [ "$DIRTY_COUNT" -gt 0 ]; then
    WARNING="$WARNING | Uncommitted: $DIRTY_COUNT files"
fi
WARNING="$WARNING | Worktrees: $WORKTREE_COUNT"

# Output as JSON for Claude to see
echo "{\"worktree_warning\": \"$WARNING\", \"current_dir\": \"$CURRENT_DIR\", \"branch\": \"$CURRENT_BRANCH\", \"worktree_count\": $WORKTREE_COUNT, \"dirty_files\": $DIRTY_COUNT}"

# Don't block, just warn
exit 0
