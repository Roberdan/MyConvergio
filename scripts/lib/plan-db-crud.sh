#!/bin/bash
# Plan DB CRUD facade - sources CRUD sub-modules
# Sourced by plan-db.sh

# Version: 1.3.0

# Remove plan file cache and plan_id from active-plan-id.txt
_cleanup_plan_file_cache() {
	local plan_id="$1"
	local cache_dir="${HOME}/.claude/data"
	local cache_file="${cache_dir}/plan-${plan_id}-files.txt"
	local active_file="${cache_dir}/active-plan-id.txt"

	rm -f "$cache_file"
	if [[ -f "$active_file" ]]; then
		local tmp_file
		tmp_file=$(mktemp "${active_file}.XXXXXX")
		grep -vxF "$plan_id" "$active_file" >"$tmp_file" 2>/dev/null || true
		mv "$tmp_file" "$active_file"
	fi
}

# Normalize path: replace $HOME with ~ for portability across machines
_normalize_path() {
	local p="$1"
	echo "$p" | sed "s|^${HOME}|~|"
}

# Expand path: replace leading ~ with $HOME for runtime use
_expand_path() {
	local p="$1"
	echo "$p" | sed "s|^~|${HOME}|"
}

# Calculate git lines added/removed for a completed plan
_calc_git_stats() {
	local plan_id="$1"
	local project_id started completed worktree_path
	IFS='|' read -r project_id started completed worktree_path < <(sqlite3 "$DB_FILE" "SELECT project_id, started_at, completed_at, worktree_path FROM plans WHERE id = $plan_id;")
	[ -z "$started" ] || [ -z "$completed" ] && return 0

	local git_dir=""
	if [ -n "$worktree_path" ]; then
		local wt_expanded="$(_expand_path "$worktree_path")"
		[ -d "$wt_expanded" ] && git_dir="$wt_expanded"
	fi
	if [ -z "$git_dir" ]; then
		git_dir=$(find ~/GitHub -maxdepth 1 -iname "$project_id" -type d 2>/dev/null | head -1)
	fi
	if [ -z "$git_dir" ] || { [ ! -d "$git_dir/.git" ] && [ ! -f "$git_dir/.git" ]; }; then
		sqlite3 "$DB_FILE" "UPDATE plans SET lines_added = 0, lines_removed = 0 WHERE id = $plan_id;"
		return 0
	fi

	local stats added removed
	stats=$(git -C "$git_dir" log --all --shortstat --after="$started" --before="$completed" --format="" 2>/dev/null)
	added=$(echo "$stats" | awk '{s+=$4} END {print s+0}')
	removed=$(echo "$stats" | awk '{s+=$6} END {print s+0}')
	sqlite3 "$DB_FILE" "UPDATE plans SET lines_added = $added, lines_removed = $removed WHERE id = $plan_id;"
}

source "${BASH_SOURCE[0]%/*}/plan-db-create.sh"
source "${BASH_SOURCE[0]%/*}/plan-db-read.sh"
source "${BASH_SOURCE[0]%/*}/plan-db-update.sh"
source "${BASH_SOURCE[0]%/*}/plan-db-delete.sh"
