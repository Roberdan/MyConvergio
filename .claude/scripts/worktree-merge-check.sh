#!/usr/bin/env bash
# worktree-merge-check.sh - AI-optimized worktree merge readiness
# Output: ~1 line per worktree, minimal tokens
# Usage: worktree-merge-check.sh [--detail BRANCH]
set -uo pipefail

DETAIL="${2:-}"
[ "${1:-}" = "--detail" ] && DETAIL="$2"

MAIN_REF=$(git rev-parse main 2>/dev/null) || {
	echo "ERR: not a git repo"
	exit 1
}
WORKTREES=$(git worktree list --porcelain)

echo "MAIN=$MAIN_REF"

while IFS= read -r wt_path; do
	[ -z "$wt_path" ] && continue
	branch=$(git -C "$wt_path" branch --show-current 2>/dev/null || echo "DETACHED")
	[ "$branch" = "main" ] && continue

	# Dirty check
	dirty=$(git -C "$wt_path" status --porcelain 2>/dev/null | /usr/bin/wc -l | tr -d ' ')

	# Ahead/behind main
	ab=$(git rev-list --left-right --count main..."$branch" 2>/dev/null || echo "? ?")
	behind=$(echo "$ab" | awk '{print $1}')
	ahead=$(echo "$ab" | awk '{print $2}')

	# Merge conflict check (dry-run)
	conflicts="clean"
	if [ "$ahead" -gt 0 ] 2>/dev/null; then
		merge_test=$(git merge-tree $(git merge-base main "$branch") main "$branch" 2>/dev/null)
		if echo "$merge_test" | /usr/bin/grep -q "^<<<<<<<"; then
			conflicts="CONFLICT"
		fi
	fi

	# Source branch already in main?
	base_merged="no"
	merge_base=$(git merge-base main "$branch" 2>/dev/null)
	[ "$merge_base" = "$(git rev-parse "$branch" 2>/dev/null)" ] && base_merged="yes"

	# Status line
	status=""
	[ "$dirty" -gt 0 ] && status="${status}DIRTY($dirty) "
	[ "$behind" -gt 0 ] 2>/dev/null && status="${status}BEHIND($behind) "
	[ "$conflicts" = "CONFLICT" ] && status="${status}CONFLICT "
	[ "$base_merged" = "yes" ] && status="${status}ALREADY_MERGED "

	if [ -z "$status" ] && [ "$ahead" -gt 0 ] 2>/dev/null; then
		status="READY(+$ahead) "
	elif [ -z "$status" ]; then
		status="EMPTY "
	fi

	short_path=$(basename "$wt_path")
	echo "$branch | $short_path | ${status% }"

	# Detail mode for specific branch
	if [ "$DETAIL" = "$branch" ]; then
		echo "  path: $wt_path"
		echo "  ahead: $ahead behind: $behind"
		echo "  files:"
		git diff --stat main..."$branch" 2>/dev/null | tail -1
		if [ "$dirty" -gt 0 ]; then
			echo "  uncommitted:"
			git -C "$wt_path" status --porcelain | head -5
		fi
	fi
done < <(echo "$WORKTREES" | /usr/bin/grep "^worktree " | sed 's/^worktree //')
