#!/usr/bin/env bash
# Version: 1.0.0
# Worktree setup: symlink .env* files and run npm install in new worktree.
# Not registered in hooks.json (Copilot CLI has no worktreeCreate phase).
# Call directly: worktree-setup.sh <worktree_path>
set -euo pipefail

WORKTREE_PATH="${1:-}"

if [[ -z "$WORKTREE_PATH" ]]; then
	exit 0
fi

MAIN_REPO=$(git -C "$WORKTREE_PATH" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||' || true)
if [[ -z "$MAIN_REPO" || "$MAIN_REPO" == "$WORKTREE_PATH" ]]; then
	exit 0
fi

for ENV_FILE in "$MAIN_REPO"/.env*; do
	[[ -e "$ENV_FILE" ]] || continue
	BASENAME=$(basename "$ENV_FILE")
	TARGET="$WORKTREE_PATH/$BASENAME"
	if [[ ! -e "$TARGET" && ! -L "$TARGET" ]]; then
		ln -s "$ENV_FILE" "$TARGET" 2>/dev/null || true
	fi
done

if [[ -f "$WORKTREE_PATH/package.json" ]]; then
	(cd "$WORKTREE_PATH" && npm install --silent 2>/dev/null) || true
fi

exit 0
