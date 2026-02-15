#!/bin/bash
# session-recovery.sh - Check all active plans for uncommitted work
# Run at session start to detect and recover lost changes
# Version: 1.0.0
set -euo pipefail

DB_FILE="${HOME}/.claude/data/dashboard.db"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

if [[ ! -f "$DB_FILE" ]]; then
	echo "No dashboard DB found"
	exit 0
fi

issues=0

# Check all active plans with worktrees
while IFS='|' read -r plan_id name worktree status; do
	[[ -z "$worktree" || ! -d "$worktree" ]] && continue

	dirty=$(git -C "$worktree" status --porcelain 2>/dev/null || echo "")
	stashes=$(git -C "$worktree" stash list 2>/dev/null | grep -c "" || echo "0")
	branch=$(git -C "$worktree" branch --show-current 2>/dev/null || echo "unknown")

	if [[ -n "$dirty" ]]; then
		echo -e "${RED}[DIRTY]${NC} Plan #${plan_id} (${name}) on ${branch}"
		echo "  Worktree: $worktree"
		echo "  Uncommitted files:"
		git -C "$worktree" status --porcelain 2>/dev/null | head -10 | sed 's/^/    /'
		issues=$((issues + 1))
	fi

	if [[ "$stashes" -gt 0 ]]; then
		echo -e "${YELLOW}[STASH]${NC} Plan #${plan_id} (${name}): ${stashes} stash(es)"
		git -C "$worktree" stash list 2>/dev/null | head -3 | sed 's/^/    /'
		issues=$((issues + 1))
	fi

	# Check for done tasks without commits (task marked done after last commit)
	local last_commit_ts
	last_commit_ts=$(git -C "$worktree" log -1 --format='%ct' 2>/dev/null || echo "0")
	orphan_tasks=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT task_id FROM tasks WHERE plan_id = $plan_id AND status = 'done'
     AND strftime('%s', completed_at) > '$last_commit_ts'
     AND validated_at IS NOT NULL;" 2>/dev/null || echo "")
	if [[ -n "$orphan_tasks" ]]; then
		echo -e "${YELLOW}[ORPHAN]${NC} Plan #${plan_id}: tasks done after last commit:"
		echo "$orphan_tasks" | sed 's/^/    /'
		issues=$((issues + 1))
	fi
done < <(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
	"SELECT id, name, worktree_path, status FROM plans WHERE status = 'doing';" 2>/dev/null)

# Check non-plan repos with known paths for dirty state
for repo_path in "$HOME/GitHub/MirrorBuddy" "$HOME/dev/myconvergio"; do
	[[ ! -d "$repo_path/.git" ]] && continue
	dirty=$(git -C "$repo_path" status --porcelain 2>/dev/null | head -1)
	stashes=$(git -C "$repo_path" stash list 2>/dev/null | grep -c "" || echo "0")
	branch=$(git -C "$repo_path" branch --show-current 2>/dev/null || echo "unknown")

	if [[ -n "$dirty" || "$stashes" -gt 0 ]]; then
		name=$(basename "$repo_path")
		echo -e "${YELLOW}[REPO]${NC} ${name} on ${branch}"
		[[ -n "$dirty" ]] && echo "  Uncommitted:" && git -C "$repo_path" status --porcelain 2>/dev/null | head -5 | sed 's/^/    /'
		[[ "$stashes" -gt 0 ]] && echo "  Stashes: $stashes"
		issues=$((issues + 1))
	fi
done

if [[ "$issues" -eq 0 ]]; then
	echo -e "${GREEN}[OK]${NC} All active plans and repos clean"
else
	echo ""
	echo -e "${RED}Found $issues issue(s). Review and commit/stash before proceeding.${NC}"
fi

exit 0
