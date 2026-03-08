#!/usr/bin/env bash
# wave-worktree-core.sh — Shared library for wave-level worktree management
# Sourced by wave-worktree scripts; requires plan-db-core.sh to be sourced first
# Version: 1.1.0
set -euo pipefail

# ---------------------------------------------------------------------------
# Guard: source plan-db-core.sh if not already loaded
# ---------------------------------------------------------------------------
if ! declare -f db_query >/dev/null 2>&1; then
	_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	# shellcheck source=plan-db-core.sh
	source "$_CORE_DIR/plan-db-core.sh"
fi

# ---------------------------------------------------------------------------
# Path helpers (inlined from plan-db-crud.sh to avoid heavy dependency)
# ---------------------------------------------------------------------------
_normalize_path() {
	local p="$1"
	echo "$p" | sed "s|^${HOME}|~|"
}
_expand_path() {
	local p="$1"
	echo "$p" | sed "s|^~|${HOME}|"
}

# ---------------------------------------------------------------------------
# wave_branch_name plan_id wave_id → "plan/{plan_id}-{wave_id}"
# ---------------------------------------------------------------------------
wave_branch_name() {
	local plan_id="$1" wave_id="$2"
	echo "plan/${plan_id}-${wave_id}"
}

# ---------------------------------------------------------------------------
# wave_worktree_path project_path plan_id wave_id
# → "{project_path}-plan-{plan_id}-{wave_id}"
# Pattern: sibling directory named <repo>-plan-<id>-<wave>
# ---------------------------------------------------------------------------
wave_worktree_path() {
	local project_path="$1" plan_id="$2" wave_id="$3"
	# Strip trailing slash, then append suffix
	local base="${project_path%/}"
	echo "${base}-plan-${plan_id}-${wave_id}"
}

# ---------------------------------------------------------------------------
# wave_set_db wave_db_id worktree_path branch_name
# Stores worktree_path (normalized) and branch_name into waves table.
# Requires columns added by migrate-v8-wave-worktree.sh.
# ---------------------------------------------------------------------------
wave_set_db() {
	local wave_db_id="$1" worktree_path="$2" branch_name="$3"
	local norm_path
	norm_path=$(_normalize_path "$worktree_path")
	local esc_path esc_branch
	esc_path=$(sql_escape "$norm_path")
	esc_branch=$(sql_escape "$branch_name")
	db_query "UPDATE waves SET worktree_path='${esc_path}', branch_name='${esc_branch}' WHERE id=${wave_db_id};"
	log_info "Wave ${wave_db_id}: worktree_path='${norm_path}' branch_name='${branch_name}'"
}

# ---------------------------------------------------------------------------
# wave_get_db wave_db_id → JSON {worktree_path, branch_name, pr_number, pr_url}
# Expands ~ to $HOME in worktree_path output.
# ---------------------------------------------------------------------------
wave_get_db() {
	local wave_db_id="$1"
	local row
	row=$(db_query -separator '|' \
		"SELECT COALESCE(worktree_path,''), COALESCE(branch_name,''), COALESCE(CAST(pr_number AS TEXT),'null'), COALESCE(pr_url,'null') FROM waves WHERE id=${wave_db_id};")
	if [[ -z "$row" ]]; then
		echo '{"error":"wave not found"}'
		return 1
	fi
	local wp bn pn pu
	IFS='|' read -r wp bn pn pu <<<"$row"
	# Expand ~ in worktree_path
	[[ -n "$wp" ]] && wp=$(_expand_path "$wp")
	# Quote strings, keep pr_number/pr_url as JSON (null or quoted)
	local pn_json pu_json
	[[ "$pn" == "null" ]] && pn_json="null" || pn_json="$pn"
	[[ "$pu" == "null" ]] && pu_json="null" || pu_json="\"${pu}\""
	printf '{"worktree_path":"%s","branch_name":"%s","pr_number":%s,"pr_url":%s}\n' \
		"$wp" "$bn" "$pn_json" "$pu_json"
}

# ---------------------------------------------------------------------------
# wave_is_active plan_id → 0 (true) if any wave has worktree_path set
# Distinguishes old-model (plan-level worktree) from new-model (wave-level)
# ---------------------------------------------------------------------------
wave_is_active() {
	local plan_id="$1"
	local count
	count=$(db_query "SELECT COUNT(*) FROM waves WHERE plan_id=${plan_id} AND worktree_path IS NOT NULL AND worktree_path != '';")
	[[ "${count:-0}" -gt 0 ]]
}

# ---------------------------------------------------------------------------
# wave_stash_if_dirty worktree_path → stash ref or empty string
# ---------------------------------------------------------------------------
wave_stash_if_dirty() {
	local path="$1"
	local dirty
	dirty=$(git -C "$path" status --porcelain 2>/dev/null || true)
	if [[ -z "$dirty" ]]; then
		echo ""
		return 0
	fi
	local stash_out
	stash_out=$(git -C "$path" stash push -m "wave-worktree auto-stash" 2>&1)
	# Extract stash ref from output like "Saved working directory … stash@{0}"
	local ref
	ref=$(echo "$stash_out" | grep -o 'stash@{[0-9]*}' || true)
	echo "${ref:-stash@{0}}"
}

# ---------------------------------------------------------------------------
# resolve_github_remote [path] → remote name to use for GitHub operations
# 1. Run `git remote -v` in path (or cwd)
# 2. Return first remote whose URL contains 'github.com'
# 3. If none, return first remote name
# 4. If no remotes at all, return empty string
# ---------------------------------------------------------------------------
resolve_github_remote() {
	local path="${1:-}"
	local git_opts=()
	[[ -n "$path" ]] && git_opts=(-C "$path")
	local remotes
	remotes=$(git "${git_opts[@]}" remote -v 2>/dev/null || true)
	[[ -z "$remotes" ]] && echo "" && return 0
	# Find first remote with github.com in URL
	local github_remote
	github_remote=$(echo "$remotes" | awk '/github\.com/ {print $1; exit}')
	if [[ -n "$github_remote" ]]; then
		echo "$github_remote"
		return 0
	fi
	# Fall back to first remote name
	echo "$remotes" | awk 'NR==1 {print $1}'
}
