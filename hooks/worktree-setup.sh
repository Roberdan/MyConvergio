#!/usr/bin/env bash
# Version: 1.1.0
# WorktreeCreate hook: symlink .env* files and run npm install in new worktree
set -euo pipefail

# Read worktree path from stdin JSON or $1
WORKTREE_PATH=""
if [[ -n "${1:-}" ]]; then
	WORKTREE_PATH="$1"
else
	INPUT=$(cat)
	WORKTREE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || true)
fi

if [[ -z "$WORKTREE_PATH" ]]; then
	# Non-blocking: exit 0 if we can't determine path
	exit 0
fi

# Find main repo root (the worktree's linked repo)
MAIN_REPO=$(git -C "$WORKTREE_PATH" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||' || true)
if [[ -z "$MAIN_REPO" || "$MAIN_REPO" == "$WORKTREE_PATH" ]]; then
	exit 0
fi

# Symlink all .env* files from main repo to worktree
for ENV_FILE in "$MAIN_REPO"/.env*; do
	[[ -e "$ENV_FILE" ]] || continue
	BASENAME=$(basename "$ENV_FILE")
	TARGET="$WORKTREE_PATH/$BASENAME"
	if [[ ! -e "$TARGET" && ! -L "$TARGET" ]]; then
		ln -s "$ENV_FILE" "$TARGET" 2>/dev/null || true
	fi
done

# Run npm install if package.json exists in worktree
if [[ -f "$WORKTREE_PATH/package.json" ]]; then
	(cd "$WORKTREE_PATH" && npm install --silent 2>/dev/null) || true
fi

# Exclude build/cache dirs from Spotlight indexing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
if [[ -x "$SCRIPT_DIR/spotlight-exclude.sh" ]]; then
	"$SCRIPT_DIR/spotlight-exclude.sh" "$WORKTREE_PATH" >/dev/null 2>/dev/null || true
fi

exit 0
