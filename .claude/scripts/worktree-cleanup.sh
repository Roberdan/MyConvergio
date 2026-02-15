#!/bin/bash
# Worktree Cleanup - Auto-remove merged worktrees
# Usage: worktree-cleanup.sh [--plan <plan_id>] [--branch <branch>] [--all-merged] [--dry-run]
# Called automatically by plan-db.sh complete, or manually after merge.

# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${HOME}/.claude/data/dashboard.db"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=0
MODE=""
TARGET=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--plan)
		MODE="plan"
		TARGET="$2"
		shift 2
		;;
	--branch)
		MODE="branch"
		TARGET="$2"
		shift 2
		;;
	--all-merged)
		MODE="all"
		shift
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	*)
		echo -e "${RED}Usage: worktree-cleanup.sh [--plan <id>] [--branch <branch>] [--all-merged] [--dry-run]${NC}"
		exit 1
		;;
	esac
done

[[ -z "$MODE" ]] && {
	echo -e "${RED}Specify --plan <id>, --branch <branch>, or --all-merged${NC}"
	exit 1
}

# Must be in a git repo
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
	echo -e "${RED}ERROR: Not in a git repository${NC}"
	exit 1
}

cleanup_worktree() {
	local wt_path="$1"
	local branch="$2"

	# Verify branch is merged into main
	local merge_base
	merge_base=$(git merge-base main "$branch" 2>/dev/null || echo "")
	local branch_tip
	branch_tip=$(git rev-parse "$branch" 2>/dev/null || echo "")

	if [[ -z "$merge_base" || -z "$branch_tip" ]]; then
		echo -e "${YELLOW}  SKIP: Branch $branch not found${NC}"
		return 1
	fi

	# Check if branch is merged (tip is ancestor of main)
	if ! git merge-base --is-ancestor "$branch" main 2>/dev/null; then
		echo -e "${YELLOW}  SKIP: $branch not merged into main${NC}"
		return 1
	fi

	# Check for uncommitted changes
	local dirty
	dirty=$(git -C "$wt_path" status --porcelain 2>/dev/null | /usr/bin/wc -l | tr -d ' ')
	if [[ "$dirty" -gt 0 ]]; then
		echo -e "${RED}  SKIP: $branch has $dirty uncommitted changes${NC}"
		return 1
	fi

	if [[ "$DRY_RUN" -eq 1 ]]; then
		echo -e "${BLUE}  DRY-RUN: Would remove worktree $wt_path and branch $branch${NC}"
		return 0
	fi

	# Verify path is actually a registered worktree before removal
	if ! git worktree list --porcelain | grep -qF "worktree $wt_path"; then
		echo -e "${RED}  SKIP: $wt_path is not a registered worktree${NC}"
		return 1
	fi

	# Remove worktree
	echo -e "${GREEN}  Removing worktree: $wt_path${NC}"
	git worktree remove "$wt_path" --force 2>/dev/null || {
		echo -e "${YELLOW}  Fallback: removing directory manually${NC}"
		rm -rf "$wt_path"
		git worktree prune
	}

	# Delete local branch
	echo -e "${GREEN}  Deleting branch: $branch${NC}"
	git branch -d "$branch" 2>/dev/null || true

	# Update plan DB if worktree_path matches
	if [[ -f "$DB_FILE" ]]; then
		local plan_id
		plan_id=$(sqlite3 "$DB_FILE" \
			"SELECT id FROM plans WHERE worktree_path LIKE '%${wt_path##*/}' OR worktree_path='$wt_path' LIMIT 1;" 2>/dev/null || echo "")
		if [[ -n "$plan_id" ]]; then
			sqlite3 "$DB_FILE" \
				"UPDATE plans SET worktree_path = NULL WHERE id = $plan_id;"
			echo -e "${GREEN}  DB: Cleared worktree_path for plan $plan_id${NC}"
		fi
	fi

	return 0
}

case "$MODE" in
plan)
	echo -e "${BLUE}=== CLEANUP WORKTREE FOR PLAN $TARGET ===${NC}"
	WT_PATH=$(sqlite3 "$DB_FILE" \
		"SELECT worktree_path FROM plans WHERE id=$TARGET;" 2>/dev/null || echo "")

	if [[ -z "$WT_PATH" || ! -d "$WT_PATH" ]]; then
		echo -e "${YELLOW}No worktree found for plan $TARGET${NC}"
		exit 0
	fi

	BRANCH=$(git -C "$WT_PATH" branch --show-current 2>/dev/null || echo "")
	if [[ -z "$BRANCH" ]]; then
		echo -e "${RED}Cannot determine branch for worktree $WT_PATH${NC}"
		exit 1
	fi

	cleanup_worktree "$WT_PATH" "$BRANCH"
	;;

branch)
	echo -e "${BLUE}=== CLEANUP WORKTREE FOR BRANCH $TARGET ===${NC}"
	WT_PATH=""
	while IFS= read -r line; do
		if [[ "$line" =~ ^worktree\ (.+) ]]; then
			current_path="${BASH_REMATCH[1]}"
		fi
		if [[ "$line" =~ ^branch\ refs/heads/(.+) ]]; then
			if [[ "${BASH_REMATCH[1]}" == "$TARGET" ]]; then
				WT_PATH="$current_path"
				break
			fi
		fi
	done < <(git worktree list --porcelain)

	if [[ -z "$WT_PATH" ]]; then
		echo -e "${YELLOW}No worktree found for branch $TARGET${NC}"
		# Still try to delete branch if merged
		if git merge-base --is-ancestor "$TARGET" main 2>/dev/null; then
			[[ "$DRY_RUN" -eq 0 ]] && git branch -d "$TARGET" 2>/dev/null || true
			echo -e "${GREEN}Deleted merged branch: $TARGET${NC}"
		fi
		exit 0
	fi

	cleanup_worktree "$WT_PATH" "$TARGET"
	;;

all)
	echo -e "${BLUE}=== CLEANUP ALL MERGED WORKTREES ===${NC}"
	cleaned=0
	while IFS= read -r wt_path; do
		[[ -z "$wt_path" ]] && continue
		branch=$(git -C "$wt_path" branch --show-current 2>/dev/null || echo "")
		[[ -z "$branch" || "$branch" == "main" || "$branch" == "master" ]] && continue

		echo -e "Checking: $branch"
		if cleanup_worktree "$wt_path" "$branch"; then
			((cleaned++))
		fi
	done < <(git worktree list --porcelain | /usr/bin/grep "^worktree " | sed 's/^worktree //')

	echo ""
	echo -e "${GREEN}Cleaned: $cleaned worktree(s)${NC}"
	;;
esac
