#!/bin/bash
set -euo pipefail
# Worktree Guard - BLOCKS execution if not in correct worktree
# Usage: worktree-guard.sh <expected_worktree_path>
# Exit codes: 0=OK, 1=VIOLATION (on main or wrong worktree)
#
# MUST be called as first command by every worker (Claude or Copilot).
# This is a hard blocker, not informational.

# Version: 1.1.0
set -euo pipefail

EXPECTED="${1:-}"

if [[ -z "$EXPECTED" ]]; then
	echo "WORKTREE_VIOLATION: no expected path provided" >&2
	echo "Usage: worktree-guard.sh <expected_worktree_path>" >&2
	exit 1
fi

# Expand ~ if present
EXPECTED="${EXPECTED/#\~/$HOME}"

# Check 1: Are we in a git repo?
if ! GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
	echo "WORKTREE_VIOLATION: not in a git repository" >&2
	exit 1
fi

# Check 2: Current branch must NOT be main or master
BRANCH=$(git branch --show-current 2>/dev/null || echo "DETACHED")
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
	echo "WORKTREE_VIOLATION: on protected branch '$BRANCH'" >&2
	echo "  Expected worktree: $EXPECTED" >&2
	echo "  Actual location: $GIT_ROOT (branch: $BRANCH)" >&2
	echo "  ACTION: cd to your assigned worktree before any work" >&2
	exit 1
fi

# Check 3: Current directory matches expected worktree
CURRENT_DIR=$(pwd)
# Normalize paths for comparison (resolve symlinks)
EXPECTED_REAL=$(cd "$EXPECTED" 2>/dev/null && pwd -P || echo "$EXPECTED")
CURRENT_REAL=$(pwd -P)
GIT_ROOT_REAL=$(cd "$GIT_ROOT" && pwd -P)

if [[ "$GIT_ROOT_REAL" != "$EXPECTED_REAL" && "$CURRENT_REAL" != "$EXPECTED_REAL" ]]; then
	echo "WORKTREE_VIOLATION: wrong worktree" >&2
	echo "  Expected: $EXPECTED" >&2
	echo "  Actual: $GIT_ROOT (branch: $BRANCH)" >&2
	exit 1
fi

# Check 4: Worktree is valid (listed by git)
if ! git worktree list --porcelain 2>/dev/null | grep -qF "worktree $GIT_ROOT_REAL"; then
	echo "WORKTREE_VIOLATION: directory is not a registered git worktree" >&2
	echo "  Path: $GIT_ROOT_REAL" >&2
	exit 1
fi

echo "WORKTREE_OK: $BRANCH @ $GIT_ROOT_REAL"
exit 0
