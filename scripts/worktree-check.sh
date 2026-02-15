#!/bin/bash
# Worktree Context Check - Shows current git context clearly
# Usage: worktree-check.sh [expected-worktree-name]
# Returns: 0 if OK, 1 if mismatch or problems

# Version: 1.0.0
set -uo pipefail
# Note: -e removed to allow grep failures without exit

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

EXPECTED_WORKTREE="${1:-}"

echo ""
echo -e "${BLUE}=== WORKTREE CONTEXT CHECK ===${NC}"
echo ""

# Current directory
CURRENT_DIR=$(pwd)
echo -e "📁 ${YELLOW}PWD:${NC} $CURRENT_DIR"

# Git root
if ! GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
    echo -e "${RED}ERROR: Not in a git repository${NC}"
    exit 1
fi
echo -e "📂 ${YELLOW}Git root:${NC} $GIT_ROOT"

# Current branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "DETACHED")
echo -e "🌿 ${YELLOW}Branch:${NC} $BRANCH"

# Is this a worktree?
if git worktree list | grep -q "^$GIT_ROOT "; then
    WORKTREE_INFO=$(git worktree list | grep "^$GIT_ROOT ")
    IS_MAIN=$(echo "$WORKTREE_INFO" | grep -q "(bare)\|^\S*\s\+\S\+\s\+\[" && echo "yes" || echo "no")
    echo -e "🌳 ${YELLOW}Worktree:${NC} YES (main=$IS_MAIN)"
else
    echo -e "🌳 ${YELLOW}Worktree:${NC} Main repo"
fi

# Uncommitted changes
DIRTY_COUNT=$(git status --porcelain 2>/dev/null | /usr/bin/wc -l | tr -d ' ')
if [ "$DIRTY_COUNT" -gt 0 ]; then
    echo -e "⚠️  ${RED}Uncommitted changes: $DIRTY_COUNT files${NC}"
    git status --porcelain | head -5
    [ "$DIRTY_COUNT" -gt 5 ] && echo "   ... and $((DIRTY_COUNT - 5)) more"
else
    echo -e "✅ ${GREEN}Working tree clean${NC}"
fi

# List all worktrees
echo ""
echo -e "${BLUE}--- All Worktrees ---${NC}"
git worktree list

# Check expected worktree if provided
if [ -n "$EXPECTED_WORKTREE" ]; then
    echo ""
    CURRENT_NAME=$(basename "$GIT_ROOT")
    if [ "$CURRENT_NAME" = "$EXPECTED_WORKTREE" ] || [ "$GIT_ROOT" = "$EXPECTED_WORKTREE" ]; then
        echo -e "${GREEN}✅ MATCH: In expected worktree '$EXPECTED_WORKTREE'${NC}"
        exit 0
    else
        echo -e "${RED}❌ MISMATCH: Expected '$EXPECTED_WORKTREE' but in '$CURRENT_NAME'${NC}"
        echo -e "${RED}   Full path: $GIT_ROOT${NC}"
        exit 1
    fi
fi

echo ""
