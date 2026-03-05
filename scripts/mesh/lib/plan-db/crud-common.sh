#!/bin/bash
# Plan DB CRUD common helpers
# Sourced by plan-db-crud.sh

_cleanup_plan_file_cache() {
	local plan_id="$1"
	local cache_dir="${HOME}/.claude/data"
	local cache_file="${cache_dir}/plan-${plan_id}-files.txt"
	local active_file="${cache_dir}/active-plan-id.txt"

	rm -f "$cache_file"

	# Remove plan_id line from active-plan-id.txt (portable sed: create temp and move)
	if [[ -f "$active_file" ]]; then
		local tmp_file
		tmp_file=$(mktemp "${active_file}.XXXXXX")
		grep -vxF "$plan_id" "$active_file" >"$tmp_file" 2>/dev/null || true
		mv "$tmp_file" "$active_file"
	fi
}

_normalize_path() {
	local p="$1"
	echo "$p" | sed "s|^${HOME}|~|"
}

_expand_path() {
	local p="$1"
	echo "$p" | sed "s|^~|${HOME}|"
}

_calc_git_stats() {
	local plan_id="$1"
	local project_id started completed worktree_path
	IFS='|' read -r project_id started completed worktree_path < <(sqlite3 "$DB_FILE" "SELECT project_id, started_at, completed_at, worktree_path FROM plans WHERE id = $plan_id;")
	[ -z "$started" ] || [ -z "$completed" ] && return 0

	# Try worktree first, then project dir
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

cmd_complete() {
	local plan_id="$1"
	local force_flag="${2:-}"
	local tasks_done tasks_total validated_at worktree_path
	IFS='|' read -r tasks_done tasks_total validated_at worktree_path < <(sqlite3 "$DB_FILE" "SELECT tasks_done, tasks_total, validated_at, worktree_path FROM plans WHERE id = $plan_id;")

	if [[ -z "$tasks_total" || "$tasks_total" -eq 0 ]]; then
		log_error "Cannot complete plan $plan_id: no tasks"
		return 1
	fi

	# Count resolved tasks: done + cancelled + skipped
	local resolved
	resolved=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE w.plan_id = $plan_id AND t.status IN ('done', 'cancelled', 'skipped');")
	if [[ "$resolved" -lt "$tasks_total" ]]; then
		local unresolved=$((tasks_total - resolved))
		log_error "Cannot complete plan $plan_id: $unresolved tasks still unresolved ($resolved/$tasks_total resolved)"
		return 1
	fi

	# Check for waves stuck in 'merging' — block completion until all merged
	local waves_merging
	waves_merging=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM waves WHERE plan_id = $plan_id AND status = 'merging';")
	if [[ "$waves_merging" -gt 0 ]]; then
		local merging_list
		merging_list=$(sqlite3 "$DB_FILE" "SELECT wave_id || ' (' || name || ')' FROM waves WHERE plan_id = $plan_id AND status = 'merging';")
		log_error "Cannot complete plan $plan_id: $waves_merging wave(s) still merging"
		echo "  Waves in merging state:" >&2
		echo "$merging_list" | sed 's/^/    /' >&2
		echo "  Wait for PR merge to complete or run: wave-worktree.sh merge $plan_id <wave_db_id>" >&2
		return 1
	fi
	if [[ -z "$validated_at" ]]; then
		log_error "Cannot complete plan $plan_id: Thor validation required"
		return 1
	fi

	# Check that all wave PRs are actually MERGED on GitHub (live verification)
	if [[ "$force_flag" != "--force" ]] && command -v gh >/dev/null 2>&1; then
		local waves_with_prs unmerged_prs
		waves_with_prs=$(sqlite3 "$DB_FILE" "SELECT wave_id, pr_number FROM waves WHERE plan_id = $plan_id AND pr_number IS NOT NULL AND pr_number > 0;")
		if [[ -n "$waves_with_prs" ]]; then
			unmerged_prs=""
			while IFS='|' read -r wave_id pr_num; do
				[[ -z "$pr_num" ]] && continue
				local pr_state
				pr_state=$(gh pr view "$pr_num" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
				if [[ "$pr_state" != "MERGED" ]]; then
					unmerged_prs="${unmerged_prs}  Wave $wave_id: PR #$pr_num ($pr_state)\n"
				fi
			done <<<"$waves_with_prs"
			if [[ -n "$unmerged_prs" ]]; then
				log_error "Cannot complete plan $plan_id: PRs not merged on GitHub"
				echo -e "$unmerged_prs" >&2
				echo "  Use --force to bypass this check" >&2
				return 1
			fi
		fi
	fi

	# Check worktree merge status if worktree exists
	if [[ -n "$worktree_path" && "$force_flag" != "--force" ]]; then
		local wt_expanded="$(_expand_path "$worktree_path")"
		if [[ -d "$wt_expanded" && -x "$SCRIPT_DIR/worktree-merge-check.sh" ]]; then
			local branch_name=$(git -C "$wt_expanded" branch --show-current 2>/dev/null || echo "")
			if [[ -n "$branch_name" && "$branch_name" != "main" ]]; then
				local wt_status=$("$SCRIPT_DIR/worktree-merge-check.sh" 2>/dev/null | grep "$branch_name" | awk -F'|' '{print $3}' | xargs || echo "UNKNOWN")
				if [[ "$wt_status" =~ DIRTY|BEHIND|CONFLICT ]]; then
					log_error "Cannot complete plan $plan_id: worktree not ready for merge ($wt_status)"
					echo "  Worktree: $worktree_path" >&2
					echo "  Status: $wt_status" >&2
					echo "  Action: Commit changes, merge to main, or use --force to bypass check" >&2
					return 1
				fi
			fi
		fi
	fi

	sqlite3 "$DB_FILE" "UPDATE plans SET status = 'done', completed_at = datetime('now'), execution_host = '$PLAN_DB_HOST' WHERE id = $plan_id;"

	# Calculate git line stats before worktree cleanup
	_calc_git_stats "$plan_id"

	local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
	sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by, changed_host)
        VALUES ($plan_id, $version, 'completed', 'Plan completed', 'executor', '$PLAN_DB_HOST');
    "
	log_info "Plan $plan_id completed! (host: $PLAN_DB_HOST)"

	# Cleanup enforce-plan-edit cache files
	_cleanup_plan_file_cache "$plan_id"

	# Auto-cleanup worktree if merged
	if [[ -x "$SCRIPT_DIR/worktree-cleanup.sh" ]]; then
		"$SCRIPT_DIR/worktree-cleanup.sh" --plan "$plan_id" 2>&1 || true
	fi

	# Final safety net: prune stale worktree metadata from .git
	local project_path
	project_path=$(sqlite3 "$DB_FILE" "SELECT p2.path FROM plans p JOIN projects p2 ON p.project_id=p2.id WHERE p.id=$plan_id;" 2>/dev/null | sed "s|^~|${HOME}|" || true)
	if [[ -n "$project_path" && -d "$project_path/.git" ]]; then
		git -C "$project_path" worktree prune 2>/dev/null || true
		git -C "$project_path" fetch --prune 2>/dev/null || true
	fi
}

cmd_where() {
	local plan_id="${1:-}"

	if [[ -n "$plan_id" ]]; then
		local info=$(sqlite3 "$DB_FILE" "SELECT name, status, execution_host FROM plans WHERE id = $plan_id;")
		if [[ -z "$info" ]]; then
			log_error "Plan $plan_id not found"
			return 1
		fi
		local name=$(echo "$info" | cut -d'|' -f1)
		local status=$(echo "$info" | cut -d'|' -f2)
		local host=$(echo "$info" | cut -d'|' -f3)
		[[ -z "$host" ]] && host="unknown"

		# Liveness check for remote hosts
		local liveness=""
		if [[ "$host" == "$PLAN_DB_HOST" || "$host" == "unknown" ]]; then
			liveness="${GREEN}LOCAL${NC}"
		elif type cmd_is_alive &>/dev/null; then
			local alive_result=$(cmd_is_alive "$host" 2>/dev/null)
			case "$alive_result" in
			ALIVE) liveness="${GREEN}ALIVE${NC}" ;;
			STALE) liveness="${YELLOW}STALE${NC}" ;;
			*) liveness="${RED}UNREACHABLE${NC}" ;;
			esac
		fi

		echo -e "Plan $plan_id (${BLUE}$name${NC}) -> ${GREEN}$host${NC} [$status] $liveness"
		echo ""

		# Show per-task hosts for active tasks
		local task_hosts=$(sqlite3 "$DB_FILE" "
			SELECT t.task_id, t.title, t.status, COALESCE(t.executor_host, '-')
			FROM tasks t WHERE t.plan_id = $plan_id AND t.status IN ('in_progress', 'done')
			ORDER BY t.id;
		")
		if [[ -n "$task_hosts" ]]; then
			echo -e "${YELLOW}Tasks with host info:${NC}"
			while IFS='|' read -r tid title tstatus thost; do
				[[ -z "$tid" ]] && continue
				local status_color="$GREEN"
				[[ "$tstatus" == "in_progress" ]] && status_color="$YELLOW"
				echo -e "  $tid ${status_color}[$tstatus]${NC} -> $thost"
			done <<<"$task_hosts"
		fi
	else
		echo -e "${BLUE}=== Plan Execution Hosts ===${NC}"
		echo -e "Current host: ${GREEN}$PLAN_DB_HOST${NC}"
		echo ""

		local active=$(sqlite3 "$DB_FILE" "
			SELECT id, name, status, COALESCE(execution_host, 'unknown')
			FROM plans WHERE status IN ('todo', 'doing')
			ORDER BY status, id;
		")
		if [[ -z "$active" ]]; then
			echo "No active plans."
		else
			while IFS='|' read -r pid pname pstatus phost; do
				[[ -z "$pid" ]] && continue
				local host_color="$GREEN"
				[[ "$phost" == "unknown" ]] && host_color="$RED"
				[[ "$phost" == "$PLAN_DB_HOST" ]] && host_color="$GREEN" || host_color="$YELLOW"
				echo -e "  Plan $pid (${BLUE}$pname${NC}) [$pstatus] -> ${host_color}$phost${NC}"
			done <<<"$active"
		fi
	fi
}
