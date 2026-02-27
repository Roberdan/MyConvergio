#!/bin/bash
# Worktree Create - Creates worktree with automatic .env symlinks
# Usage: worktree-create.sh <branch> [path]
# Example: worktree-create.sh feature/new-api ../project-feature

# Version: 1.0.0
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BRANCH="${1:-}"
WORKTREE_PATH="${2:-}"

if [ -z "$BRANCH" ]; then
	echo -e "${RED}Usage: worktree-create.sh <branch> [path]${NC}"
	echo "  branch: Branch name to checkout (will create if doesn't exist)"
	echo "  path:   Where to create worktree (default: ../<repo>-<branch-suffix>)"
	exit 1
fi

# Get main repo root
MAIN_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$MAIN_ROOT" ]; then
	echo -e "${RED}ERROR: Not in a git repository${NC}"
	exit 1
fi

REPO_NAME=$(basename "$MAIN_ROOT")
BRANCH_SUFFIX=$(echo "$BRANCH" | sed 's/.*\///')

# Default path if not provided
if [ -z "$WORKTREE_PATH" ]; then
	WORKTREE_PATH="$MAIN_ROOT/../${REPO_NAME}-${BRANCH_SUFFIX}"
fi

# SAFETY: Never create worktree inside the main repo (pollutes TS/ESLint/build)
RESOLVED_WT=$(cd "$(dirname "$WORKTREE_PATH")" 2>/dev/null && pwd)/$(basename "$WORKTREE_PATH")
if [[ "$RESOLVED_WT" == "$MAIN_ROOT"/* ]]; then
	echo -e "${RED}BLOCKED: Worktree path is INSIDE the main repo!${NC}"
	echo -e "  Requested: $WORKTREE_PATH"
	echo -e "  Main repo: $MAIN_ROOT"
	echo -e "  This would poison TypeScript, ESLint, and build."
	echo -e "  Use a sibling path: $MAIN_ROOT/../${REPO_NAME}-${BRANCH_SUFFIX}"
	exit 1
fi

echo -e "${BLUE}=== WORKTREE CREATE ===${NC}"
echo -e "📂 Main repo: $MAIN_ROOT"
echo -e "🌿 Branch: $BRANCH"
echo -e "📁 Worktree path: $WORKTREE_PATH"
echo ""

# Check if branch exists
if git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
	echo -e "${GREEN}Branch exists, using existing branch${NC}"
	git worktree add "$WORKTREE_PATH" "$BRANCH"
elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH" 2>/dev/null; then
	echo -e "${GREEN}Remote branch exists, tracking it${NC}"
	git worktree add "$WORKTREE_PATH" "$BRANCH"
else
	echo -e "${YELLOW}Creating new branch from current HEAD${NC}"
	git worktree add -b "$BRANCH" "$WORKTREE_PATH"
fi

# Symlink .env files
echo ""
echo -e "${BLUE}--- Symlinking .env files ---${NC}"

ENV_COUNT=0
for envfile in "$MAIN_ROOT"/.env*; do
	if [ -f "$envfile" ]; then
		filename=$(basename "$envfile")
		target="$WORKTREE_PATH/$filename"

		if [ -e "$target" ] || [ -L "$target" ]; then
			echo -e "${YELLOW}⚠️  $filename already exists, skipping${NC}"
		else
			ln -s "$envfile" "$target"
			echo -e "${GREEN}✅ $filename → symlinked${NC}"
			((ENV_COUNT++))
		fi
	fi
done

if [ "$ENV_COUNT" -eq 0 ]; then
	echo -e "${YELLOW}No .env files found in main repo${NC}"
else
	echo -e "${GREEN}Linked $ENV_COUNT .env file(s)${NC}"
fi

# Optional: npm install
echo ""
if [ -f "$WORKTREE_PATH/package.json" ]; then
	echo -e "${BLUE}--- Installing dependencies ---${NC}"
	(cd "$WORKTREE_PATH" && npm install)
fi

# NOTE: If WorktreeCreate hook is configured in settings.json, .env symlink and
# npm install are handled by the hook automatically. This inline setup is the fallback.

echo ""
echo -e "${GREEN}=== WORKTREE READY ===${NC}"
echo -e "cd $WORKTREE_PATH"
echo ""
git worktree list
