#!/bin/bash
# Plan DB Drift Detection - Pre-execution plan staleness checks
# Sourced by plan-db.sh

# Check plan drift against current main branch
# Returns JSON: drift level, overlapping files, recommendation
# Exit codes: 0=clean, 1=minor drift (rebase), 2=major drift (replan)
# Version: 1.2.0
cmd_check_drift() {
	local plan_id="$1"

	local plan_data
	plan_data=$(sqlite3 "$DB_FILE" "
		SELECT json_object(
			'created_at', created_at,
			'worktree_path', COALESCE(worktree_path,''),
			'name', name,
			'status', status
		) FROM plans WHERE id=$plan_id;")

	if [[ -z "$plan_data" ]]; then
		echo '{"error":"plan not found"}' && return 2
	fi

	local created_at wt_raw wt_path plan_status
	created_at=$(echo "$plan_data" | jq -r '.created_at')
	wt_raw=$(echo "$plan_data" | jq -r '.worktree_path')
	plan_status=$(echo "$plan_data" | jq -r '.status')
	wt_path=$(_expand_path "$wt_raw")

	# Calculate days since creation (using SQLite for portability)
	local days_stale
	days_stale=$(sqlite3 "$DB_FILE" "SELECT CAST(julianday('now') - julianday('$created_at') AS INTEGER);")

	# Find git root (main repo, not worktree)
	local git_root
	if [[ -d "$wt_path" ]]; then
		git_root=$(cd "$wt_path" && git rev-parse --path-format=absolute \
			--git-common-dir 2>/dev/null | sed 's|/.git$||') || git_root=""
	else
		git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
	fi

	if [[ -z "$git_root" ]]; then
		jq -n --argjson id "$plan_id" --argjson d "$days_stale" \
			'{plan_id:$id, error:"no git root", days_stale:$d}'
		return 2
	fi

	# Commits on main since plan creation
	local main_commits main_files
	main_commits=$(cd "$git_root" &&
		git rev-list --count "main@{${created_at}}..main" 2>/dev/null || echo 0)
	main_files=$(cd "$git_root" &&
		git log main --since="$created_at" --name-only --format="" 2>/dev/null |
		sort -u) || main_files=""

	# Branch behind count (if worktree exists)
	local behind=0
	if [[ -d "$wt_path" ]]; then
		(cd "$wt_path" && git fetch origin main --quiet 2>/dev/null) || true
		behind=$(cd "$wt_path" &&
			git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
	fi

	# Extract file paths from pending task descriptions
	local task_files
	task_files=$(sqlite3 "$DB_FILE" "
		SELECT DISTINCT t.description || ' ' || COALESCE(t.test_criteria,'')
		FROM tasks t WHERE t.plan_id=$plan_id AND t.status='pending';
	" | grep -oE '[a-zA-Z0-9_/.-]+\.(ts|tsx|js|jsx|py|rs|go|sh|sql|css|json|md)' |
		sort -u || true)

	# Find overlapping files between main changes and plan tasks
	local overlaps=()
	local overlap_json="[]"
	if [[ -n "$main_files" && -n "$task_files" ]]; then
		while IFS= read -r tf; do
			if echo "$main_files" | grep -qF "$tf"; then
				local ci
				ci=$(cd "$git_root" && git log main --since="$created_at" \
					-1 --format="%h %s" -- "$tf" 2>/dev/null || echo "unknown")
				overlaps+=("{\"file\":\"$tf\",\"commit\":\"$(echo "$ci" | head -c 60)\"}")
			fi
		done <<<"$task_files"
		if [[ ${#overlaps[@]} -gt 0 ]]; then
			overlap_json=$(printf '%s\n' "${overlaps[@]}" | jq -s '.')
		fi
	fi

	# Determine drift level and recommendation
	local drift="none" rec="proceed"
	local overlap_count=${#overlaps[@]}
	if [[ $overlap_count -gt 3 || $days_stale -gt 7 ]]; then
		drift="major"
		rec="replan"
	elif [[ $overlap_count -gt 0 || $behind -gt 5 ]]; then
		drift="minor"
		rec="rebase"
	elif [[ $behind -gt 0 ]]; then
		drift="minor"
		rec="rebase"
	fi

	jq -n \
		--argjson plan_id "$plan_id" \
		--argjson days_stale "$days_stale" \
		--argjson main_commits "$main_commits" \
		--argjson behind "$behind" \
		--argjson overlap_count "$overlap_count" \
		--argjson overlaps "$overlap_json" \
		--arg drift "$drift" --arg rec "$rec" --arg status "$plan_status" \
		'{plan_id:$plan_id, days_stale:$days_stale,
		  main_commits_since:$main_commits, branch_behind:$behind,
		  overlap_count:$overlap_count, overlapping_files:$overlaps,
		  drift:$drift, recommendation:$rec, plan_status:$status}'

	case "$drift" in
	none) return 0 ;; minor) return 1 ;; major) return 2 ;;
	esac
}

# Rebase plan worktree branch onto latest main
cmd_rebase_plan() {
	local plan_id="$1"
	local wt_raw
	wt_raw=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id=$plan_id;")
	local wt_path
	wt_path=$(_expand_path "$wt_raw")

	if [[ ! -d "$wt_path" ]]; then
		log_error "Worktree not found: $wt_path"
		return 1
	fi

	local branch
	branch=$(cd "$wt_path" && git branch --show-current) || branch=""
	if [[ "$branch" == "main" || "$branch" == "master" ]]; then
		log_error "REFUSED: worktree is on $branch. Cannot rebase main onto itself."
		return 1
	fi

	log_info "Rebasing $branch onto main in $wt_path..."
	if ! (cd "$wt_path" && git fetch origin main --quiet && git rebase origin/main); then
		log_error "Rebase failed. Resolve conflicts in $wt_path"
		(cd "$wt_path" && git rebase --abort 2>/dev/null)
		return 1
	fi

	log_info "Rebase complete: $branch is up to date with main"
	return 0
}
