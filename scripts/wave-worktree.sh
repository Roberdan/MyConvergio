#!/usr/bin/env bash
# wave-worktree.sh — Wave-level worktree lifecycle management
# Usage: wave-worktree.sh <command> <plan_id> [wave_db_id]
# Commands: create, merge, cleanup, status
# Version: 2.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/plan-db-core.sh"
source "$SCRIPT_DIR/lib/wave-worktree-core.sh"

# ---------------------------------------------------------------------------
# cmd_create plan_id wave_db_id
# ---------------------------------------------------------------------------
cmd_create() {
	local plan_id="$1" wave_db_id="$2"

	# 1. Get project path from DB
	local project_path
	project_path=$(db_query \
		"SELECT p2.path FROM plans p JOIN projects p2 ON p.project_id = p2.id WHERE p.id = ${plan_id};" \
		2>/dev/null || true)

	# Expand ~ to $HOME
	[[ -n "$project_path" ]] && project_path=$(_expand_path "$project_path")

	# Fallback: try git rev-parse from cwd
	if [[ -z "$project_path" ]]; then
		project_path=$(git rev-parse --show-toplevel 2>/dev/null || true)
	fi
	if [[ -z "$project_path" ]]; then
		log_error "Cannot determine project path for plan $plan_id"
		exit 1
	fi

	# 2. Get wave_id (text code like W1)
	local wave_id
	wave_id=$(db_query "SELECT wave_id FROM waves WHERE id = ${wave_db_id};" 2>/dev/null || true)
	if [[ -z "$wave_id" ]]; then
		log_error "Wave not found: db_id=${wave_db_id}"
		exit 1
	fi

	local branch wt_path
	branch=$(wave_branch_name "$plan_id" "$wave_id")
	wt_path=$(wave_worktree_path "$project_path" "$plan_id" "$wave_id")

	local expanded_wt
	expanded_wt=$(_expand_path "$wt_path")
	if [[ -d "$expanded_wt" ]]; then
		log_info "Worktree already exists: $expanded_wt (skipping creation)"
	else
		local remote
		remote=$(resolve_github_remote "$project_path")
		git -C "$project_path" fetch "${remote:-origin}" main 2>/dev/null || true
		(cd "$project_path" && "$SCRIPT_DIR/worktree-create.sh" "$branch" "$wt_path")
	fi

	wave_set_db "$wave_db_id" "$wt_path" "$branch"

	local norm_wt
	norm_wt=$(_normalize_path "$wt_path")
	db_query "UPDATE plans SET worktree_path = '$(sql_escape "$norm_wt")' WHERE id = ${plan_id};"

	db_query "UPDATE waves SET status = 'in_progress', started_at = COALESCE(started_at, datetime('now')) WHERE id = ${wave_db_id};"
	log_info "Wave ${wave_db_id} -> in_progress"
	wave_get_db "$wave_db_id"
}

# ---------------------------------------------------------------------------
# cmd_status plan_id
# ---------------------------------------------------------------------------
cmd_status() {
	local plan_id="$1"

	local rows
	rows=$(db_query -separator '|' \
		"SELECT w.id, w.wave_id, w.name, w.status, COALESCE(w.worktree_path,''), COALESCE(w.branch_name,''), COALESCE(CAST(w.pr_number AS TEXT),'-'), w.tasks_done, w.tasks_total
		 FROM waves w WHERE w.plan_id = ${plan_id} ORDER BY w.position;" \
		2>/dev/null || true)

	if [[ -z "$rows" ]]; then
		echo "No waves found for plan $plan_id"
		return 0
	fi

	printf "%-6s %-12s %-6s %-24s %-5s %s\n" "Wave" "Status" "Tasks" "Branch" "PR" "Worktree"
	printf "%-6s %-12s %-6s %-24s %-5s %s\n" "------" "------------" "------" "------------------------" "-----" "--------"

	while IFS='|' read -r id wid name status wt_path branch pr_num done total; do
		local clean="-"
		if [[ -n "$wt_path" ]]; then
			local expanded
			expanded=$(_expand_path "$wt_path")
			if [[ -d "$expanded" ]]; then
				local dirty
				dirty=$(git -C "$expanded" status --porcelain 2>/dev/null | head -1 || true)
				[[ -z "$dirty" ]] && clean="Clean" || clean="Dirty"
			else
				clean="Missing"
			fi
		fi
		local disp_wt="${wt_path:-"-"}"
		printf "%-6s %-12s %-6s %-24s %-5s %s [%s]\n" \
			"$wid" "$status" "${done}/${total}" "${branch:-"-"}" "${pr_num}" "$disp_wt" "$clean"
	done <<<"$rows"
}

# ---------------------------------------------------------------------------
# cmd_merge plan_id wave_db_id
# ---------------------------------------------------------------------------
cmd_merge() {
	local plan_id="$1" wave_db_id="$2"

	# 1. Read worktree_path + branch from DB
	local db_json wt_path branch wave_name
	db_json=$(wave_get_db "$wave_db_id" 2>/dev/null || true)
	if echo "$db_json" | grep -q '"error"'; then
		log_error "Wave not found: db_id=${wave_db_id}"
		exit 1
	fi
	wt_path=$(echo "$db_json" | sed 's/.*"worktree_path":"\([^"]*\)".*/\1/')
	branch=$(echo "$db_json" | sed 's/.*"branch_name":"\([^"]*\)".*/\1/')
	wave_name=$(db_query "SELECT COALESCE(name, wave_id) FROM waves WHERE id = ${wave_db_id};" 2>/dev/null || true)

	# 2. Verify worktree exists
	if [[ -z "$wt_path" ]] || [[ ! -d "$wt_path" ]]; then
		log_error "Worktree not found for wave ${wave_db_id}: '${wt_path}'"
		exit 1
	fi

	# 3. Resolve remote (auto-detect, not hardcoded 'origin')
	local remote
	remote=$(resolve_github_remote "$wt_path")
	if [[ -z "$remote" ]]; then
		log_warn "No git remote found — skipping merge, marking wave done"
		db_query "UPDATE waves SET status='done', completed_at=datetime('now') WHERE id=${wave_db_id};" 2>/dev/null || true
		cmd_cleanup "$plan_id" "$wave_db_id"
		return 0
	fi

	# 4. Pre-flight: check if branch has commits beyond main
	local main_branch="main"
	if ! git -C "$wt_path" rev-parse --verify "$main_branch" >/dev/null 2>&1; then
		main_branch="master"
	fi
	local diff_count
	diff_count=$(git -C "$wt_path" log "${main_branch}..HEAD" --oneline 2>/dev/null | wc -l | tr -d ' ')
	if [[ "${diff_count:-0}" -eq 0 ]]; then
		log_info "No changes in wave worktree vs $main_branch — skipping merge"
		db_query "UPDATE waves SET status='done', completed_at=datetime('now') WHERE id=${wave_db_id};" 2>/dev/null || true
		cmd_cleanup "$plan_id" "$wave_db_id"
		return 0
	fi

	# 5. Commit if dirty
	local dirty
	dirty=$(git -C "$wt_path" status --porcelain 2>/dev/null || true)
	if [[ -n "$dirty" ]]; then
		git -C "$wt_path" add -A
		git -C "$wt_path" commit -m "feat(plan-${plan_id}): ${wave_db_id} — ${wave_name}"
	fi

	# 6. Push (use resolved remote)
	if ! git -C "$wt_path" push -u "$remote" "$branch" 2>&1; then
		log_error "Push failed for wave ${wave_db_id} — rolling back to in_progress"
		db_query "UPDATE waves SET status='in_progress' WHERE id=${wave_db_id};" 2>/dev/null || true
		return 1
	fi

	# 7. DRY_RUN: skip PR creation, CI, merge
	if [[ "${WAVE_DRY_RUN:-0}" == "1" ]]; then
		log_info "DRY_RUN: skipping PR creation and merge for wave ${wave_db_id}"
		db_query "UPDATE waves SET status='done', completed_at=datetime('now') WHERE id=${wave_db_id};" 2>/dev/null || true
		return 0
	fi

	# 8. Create PR (use resolved remote)
	local remote_repo pr_url pr_number
	remote_repo=$(git -C "$wt_path" remote get-url "$remote" 2>/dev/null | sed 's|.*github.com[:/]||;s|\.git$||' || true)
	if [[ -z "$remote_repo" ]] || ! command -v gh >/dev/null 2>&1; then
		log_warn "gh not installed or no GitHub remote — skipping PR creation"
		db_query "UPDATE waves SET status='done', completed_at=datetime('now') WHERE id=${wave_db_id};" 2>/dev/null || true
		cmd_cleanup "$plan_id" "$wave_db_id"
		return 0
	fi
	pr_url=$(gh pr create --repo "$remote_repo" --base "$main_branch" --head "$branch" \
		--title "Plan ${plan_id}: ${wave_db_id} — ${wave_name}" \
		--body "Auto-generated by wave-worktree.sh for plan ${plan_id}, wave ${wave_db_id}" 2>&1 || true)
	pr_number=$(basename "$pr_url")
	db_query "UPDATE waves SET pr_number=${pr_number:-0}, pr_url='$(sql_escape "$pr_url")' WHERE id=${wave_db_id};" 2>/dev/null || true

	# 9. Wait for CI (--watch --fail-fast)
	gh pr checks "$pr_number" --repo "$remote_repo" --watch --fail-fast 2>&1 || true

	# 10. Readiness gate (BLOCKING)
	if [[ -x "$SCRIPT_DIR/pr-ops.sh" ]]; then
		local ready_output blockers
		ready_output=$("$SCRIPT_DIR/pr-ops.sh" ready "$pr_number" 2>&1 || true)
		blockers=$(echo "$ready_output" | grep -c "BLOCKER:" || true)
		if [[ "$blockers" -gt 0 ]]; then
			if echo "$ready_output" | grep -qi "unresolved thread"; then
				log_error "PR #$pr_number has unresolved review comments. Resolve before merge."
				log_error "Run: pr-comment-resolver agent or pr-threads.sh $pr_number to inspect"
				log_error "Then retry: wave-worktree.sh merge $plan_id $wave_db_id"
			else
				log_error "PR #$pr_number not ready to merge:"
				echo "$ready_output" | grep "BLOCKER:" >&2
			fi
			db_query "UPDATE waves SET status='in_progress' WHERE id=${wave_db_id};" 2>/dev/null || true
			return 1
		fi
	else
		local ci_status
		ci_status=$(gh pr checks "$pr_number" --repo "$remote_repo" 2>/dev/null | grep -c "fail" || true)
		if [[ "${ci_status:-0}" -gt 0 ]]; then
			log_error "CI failed for PR $pr_url"
			db_query "UPDATE waves SET status='in_progress' WHERE id=${wave_db_id};" 2>/dev/null || true
			return 1
		fi
	fi

	# 11. Merge
	if [[ -x "$SCRIPT_DIR/pr-ops.sh" ]]; then
		if ! "$SCRIPT_DIR/pr-ops.sh" merge "$pr_number"; then
			log_error "Merge failed for wave ${wave_db_id} — rolling back to in_progress"
			db_query "UPDATE waves SET status='in_progress' WHERE id=${wave_db_id};" 2>/dev/null || true
			return 1
		fi
	else
		if ! gh pr merge "$pr_number" --squash --delete-branch; then
			log_error "Merge failed for wave ${wave_db_id} — rolling back to in_progress"
			db_query "UPDATE waves SET status='in_progress' WHERE id=${wave_db_id};" 2>/dev/null || true
			return 1
		fi
	fi

	# 12. Mark done + cleanup
	db_query "UPDATE waves SET status='done', completed_at=datetime('now') WHERE id=${wave_db_id};" 2>/dev/null || true
	cmd_cleanup "$plan_id" "$wave_db_id"
}

# ---------------------------------------------------------------------------
# cmd_cleanup plan_id wave_db_id [--force]
# ---------------------------------------------------------------------------
cmd_cleanup() {
	local plan_id="$1" wave_db_id="$2" force="${3:-}"

	# 1. Read worktree_path + branch from DB
	local db_json wt_path branch
	db_json=$(wave_get_db "$wave_db_id" 2>/dev/null || true)
	if echo "$db_json" | grep -q '"error"'; then
		log_error "Wave not found: db_id=${wave_db_id}"
		exit 1
	fi
	wt_path=$(echo "$db_json" | sed 's/.*"worktree_path":"\([^"]*\)".*/\1/')
	branch=$(echo "$db_json" | sed 's/.*"branch_name":"\([^"]*\)".*/\1/')

	# 2. Check for dirty worktree
	if [[ -d "$wt_path" ]]; then
		local dirty
		dirty=$(git -C "$wt_path" status --porcelain 2>/dev/null || true)
		if [[ -n "$dirty" ]] && [[ "$force" != "--force" ]]; then
			log_error "Worktree has uncommitted changes. Use --force or commit first."
			exit 1
		fi
	fi

	# 3. Get project path for git operations
	local project_path
	project_path=$(db_query "SELECT p2.path FROM plans p JOIN projects p2 ON p.project_id=p2.id WHERE p.id=${plan_id};" 2>/dev/null | sed "s|^~|${HOME}|" || true)
	[[ -z "$project_path" ]] && project_path=$(git rev-parse --show-toplevel 2>/dev/null || true)

	# 4. Remove worktree
	if [[ -n "$project_path" ]] && [[ -d "$wt_path" ]]; then
		git -C "$project_path" worktree remove "$wt_path" --force 2>/dev/null || true
	fi

	# 5. Delete local branch
	if [[ -n "$project_path" ]] && [[ -n "$branch" ]]; then
		git -C "$project_path" branch -d "$branch" 2>/dev/null || true
	fi

	# 6. Prune stale worktree metadata + remote refs
	if [[ -n "$project_path" ]]; then
		git -C "$project_path" worktree prune 2>/dev/null || true
		git -C "$project_path" fetch --prune 2>/dev/null || true
	fi

	# 7. Clear worktree + branch in DB
	db_query "UPDATE waves SET worktree_path=NULL, branch_name=NULL WHERE id=${wave_db_id};" 2>/dev/null || true
	log_info "Cleaned up wave ${wave_db_id} worktree"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "${1:-help}" in
create) cmd_create "${2:?plan_id required}" "${3:?wave_db_id required}" ;;
status) cmd_status "${2:?plan_id required}" ;;
merge) cmd_merge "${2:?plan_id required}" "${3:?wave_db_id required}" ;;
cleanup) cmd_cleanup "${2:?plan_id required}" "${3:?wave_db_id required}" ;;
*) echo "Usage: wave-worktree.sh <create|merge|cleanup|status> <plan_id> [wave_db_id]" ;;
esac
