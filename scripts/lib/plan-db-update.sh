#!/bin/bash
cmd_start() {
	local plan_id="$1"
	local force_flag="${2:-}"

	# GATE: Readiness check BLOCKS start if planner process incomplete
	if [[ "$force_flag" != "--force" ]]; then
		if declare -F cmd_check_readiness >/dev/null 2>&1; then
			if ! cmd_check_readiness "$plan_id"; then
				log_error "Plan $plan_id failed readiness check. Fix issues above or use --force to override (audited)."
				return 1
			fi
		else
			log_info "Readiness check unavailable in legacy source mode; continuing without gate"
		fi
	fi

	if ! cmd_claim "$plan_id" "$force_flag"; then
		log_error "Failed to claim plan $plan_id. Use --force to override."
		return 1
	fi
	local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
	sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by, changed_host)
        VALUES ($plan_id, $version, 'started', 'Execution started', 'planner', '$PLAN_DB_HOST');
    "
	local active_file="${HOME}/.claude/data/active-plan-id.txt"
	mkdir -p "${HOME}/.claude/data"
	if ! grep -qxF "$plan_id" "$active_file" 2>/dev/null; then
		echo "$plan_id" >>"$active_file"
	fi
	log_info "Started plan ID: $plan_id (host: $PLAN_DB_HOST)"
}
cmd_update_task() {
	local task_id="$1"
	local status="$2"
	shift 2
	local notes="" tokens="" output_data=""
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--tokens)
			tokens="$2"
			shift 2
			;;
		--output-data)
			output_data="$2"
			shift 2
			;;
		*)
			[[ -z "$notes" ]] && notes="$1"
			shift
			;;
		esac
	done
	local notes_escaped=$(sql_escape "$notes")
	if [[ -n "$output_data" ]]; then
		echo "$output_data" | jq -e . >/dev/null 2>&1 || {
			log_error "Invalid JSON in --output-data"
			exit 1
		}
	fi
	case "$status" in
	pending | in_progress | submitted | done | blocked | skipped | cancelled) ;;
	*)
		log_error "Invalid task status: '$status'. Valid: pending | in_progress | submitted | done | blocked | skipped | cancelled"
		exit 1
		;;
	esac
	local old_status=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id = $task_id;")

	# GATE: Cannot start task if plan is not 'doing' (enforces plan-db.sh start prerequisite)
	if [[ "$status" == "in_progress" && "$old_status" == "pending" ]]; then
		local plan_status
		plan_status=$(sqlite3 "$DB_FILE" "SELECT p.status FROM tasks t JOIN plans p ON t.plan_id = p.id WHERE t.id = $task_id;")
		if [[ "$plan_status" != "doing" ]]; then
			log_error "Cannot start task: plan status is '$plan_status' (must be 'doing'). Run: plan-db.sh start <plan_id>"
			exit 1
		fi
	fi

	if [[ "$status" == "done" && "$old_status" == "pending" ]]; then
		log_error "Cannot transition pending→done directly. Mark as in_progress first."
		exit 1
	fi
	if [[ "$status" == "submitted" && "$old_status" == "pending" ]]; then
		log_error "Cannot transition pending→submitted directly. Mark as in_progress first."
		exit 1
	fi
	local tokens_sql=""
	[[ -n "$tokens" ]] && tokens_sql=", tokens = $tokens"
	local output_sql=""
	[[ -n "$output_data" ]] && output_sql=", output_data = '$(sql_escape "$output_data")'"
	if [[ "$status" == "in_progress" ]]; then
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', started_at = datetime('now'), executor_host = '$PLAN_DB_HOST', notes = '$notes_escaped'$tokens_sql$output_sql WHERE id = $task_id;"
	elif [[ "$status" == "submitted" ]]; then
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = 'submitted', completed_at = datetime('now'), executor_host = '$PLAN_DB_HOST', notes = '$notes_escaped'$tokens_sql$output_sql WHERE id = $task_id;"
		log_info "Task $task_id submitted — awaiting Thor validation"
	elif [[ "$status" == "done" ]]; then
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', started_at = COALESCE(started_at, datetime('now')), completed_at = COALESCE(completed_at, datetime('now')), executor_host = '$PLAN_DB_HOST', notes = '$notes_escaped'$tokens_sql$output_sql WHERE id = $task_id;"
		sqlite3 "$DB_FILE" "
			CREATE TRIGGER IF NOT EXISTS task_done_counter
			AFTER UPDATE OF status ON tasks
			WHEN NEW.status = 'done' AND OLD.status != 'done'
			BEGIN
				UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = NEW.wave_id_fk;
				UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = NEW.plan_id;
			END;
		"
		local wave_fk_id plan_fk_id
		IFS='|' read -r wave_fk_id plan_fk_id < <(sqlite3 "$DB_FILE" "SELECT wave_id_fk, plan_id FROM tasks WHERE id = $task_id;")
		[[ -n "$wave_fk_id" ]] && sqlite3 "$DB_FILE" "
			UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_fk_id AND status = 'done') WHERE id = $wave_fk_id;
			UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done),0) FROM waves WHERE plan_id = $plan_fk_id) WHERE id = $plan_fk_id;
		"
		local wave_fk wave_done wave_id_text
		IFS='|' read -r wave_fk wave_done wave_id_text < <(sqlite3 "$DB_FILE" "SELECT t.wave_id_fk, (w.tasks_done = w.tasks_total), w.wave_id FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE t.id = $task_id;")
		[[ "$wave_done" == "1" ]] && {
			sqlite3 "$DB_FILE" "UPDATE waves SET status = 'done', started_at = COALESCE(started_at, datetime('now')), completed_at = datetime('now') WHERE id = $wave_fk;"
			log_info "Wave $wave_id_text completed!"
		}
	elif [[ "$status" == "cancelled" ]]; then
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', cancelled_at = datetime('now'), cancelled_reason = '$notes_escaped', executor_host = '$PLAN_DB_HOST'$tokens_sql$output_sql WHERE id = $task_id;"
	else
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', executor_host = '$PLAN_DB_HOST', notes = '$notes_escaped'$tokens_sql$output_sql WHERE id = $task_id;"
	fi
	sqlite3 "$DB_FILE" "UPDATE plans SET execution_host = '$PLAN_DB_HOST' WHERE id = (SELECT plan_id FROM tasks WHERE id = $task_id);"
	[[ -n "$tokens" ]] && log_info "Task $task_id: $old_status -> $status (tokens: $tokens)" || log_info "Task $task_id: $old_status -> $status"
}
cmd_update_wave() {
	local wave_id="$1"
	local status="$2"
	case "$status" in
	pending | in_progress | done | blocked | merging | cancelled) ;;
	*)
		log_error "Invalid wave status: '$status'. Valid: pending | in_progress | done | blocked | merging | cancelled"
		exit 1
		;;
	esac
	if [[ "$status" == "in_progress" ]]; then
		sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', started_at = datetime('now') WHERE id = $wave_id;"
	elif [[ "$status" == "done" ]]; then
		sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', started_at = COALESCE(started_at, datetime('now')), completed_at = datetime('now') WHERE id = $wave_id;"
	elif [[ "$status" == "cancelled" ]]; then
		sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', cancelled_at = datetime('now') WHERE id = $wave_id;"
	else
		sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status' WHERE id = $wave_id;"
	fi
	log_info "Wave $wave_id -> $status"
}
# Record user approval for plan (required by planner process gates)
cmd_approve() {
	local plan_id="$1"
	local notes="${2:-User approved plan}"
	local plan_name
	plan_name=$(sqlite3 "$DB_FILE" "SELECT name FROM plans WHERE id=$plan_id;")
	if [[ -z "$plan_name" ]]; then
		log_error "Plan $plan_id not found"
		return 1
	fi
	local review_count biz_count challenger_count
	review_count=$(sqlite3 "$DB_FILE" \
		"SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%reviewer%' AND reviewer_agent NOT LIKE '%challenger%';" 2>/dev/null || echo "0")
	biz_count=$(sqlite3 "$DB_FILE" \
		"SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND (reviewer_agent LIKE '%business%' OR reviewer_agent LIKE '%advisor%');" 2>/dev/null || echo "0")
	challenger_count=$(sqlite3 "$DB_FILE" \
		"SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%challenger%';" 2>/dev/null || echo "0")
	if [[ "$review_count" -eq 0 || "$biz_count" -eq 0 || "$challenger_count" -eq 0 ]]; then
		log_error "Cannot approve: missing reviews (reviewer=$review_count, business=$biz_count, challenger=$challenger_count)"
		log_error "Run plan-reviewer, plan-business-advisor, and plan-challenger FIRST"
		return 1
	fi
	local safe_notes
	safe_notes=$(sql_escape "$notes")
	sqlite3 "$DB_FILE" "
		INSERT INTO plan_reviews (plan_id, reviewer_agent, verdict, suggestions, reviewed_at)
		VALUES ($plan_id, 'user-approval', 'approved', '$safe_notes', datetime('now'));
	"
	log_info "Plan #$plan_id ($plan_name) approved by user"
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
	local resolved
	resolved=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE w.plan_id = $plan_id AND t.status IN ('done', 'cancelled', 'skipped');")
	if [[ "$resolved" -lt "$tasks_total" ]]; then
		local unresolved=$((tasks_total - resolved))
		log_error "Cannot complete plan $plan_id: $unresolved tasks still unresolved ($resolved/$tasks_total resolved)"
		return 1
	fi
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
	_calc_git_stats "$plan_id"
	local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
	sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by, changed_host)
        VALUES ($plan_id, $version, 'completed', 'Plan completed', 'executor', '$PLAN_DB_HOST');
    "
	log_info "Plan $plan_id completed! (host: $PLAN_DB_HOST)"
	_cleanup_plan_file_cache "$plan_id"
	if [[ -x "$SCRIPT_DIR/worktree-cleanup.sh" ]]; then
		"$SCRIPT_DIR/worktree-cleanup.sh" --plan "$plan_id" 2>&1 || true
	fi
	local project_path
	project_path=$(sqlite3 "$DB_FILE" "SELECT p2.path FROM plans p JOIN projects p2 ON p.project_id=p2.id WHERE p.id=$plan_id;" 2>/dev/null | sed "s|^~|${HOME}|" || true)
	if [[ -n "$project_path" && -d "$project_path/.git" ]]; then
		git -C "$project_path" worktree prune 2>/dev/null || true
		git -C "$project_path" fetch --prune 2>/dev/null || true
	fi
	local sync_script="${SCRIPT_DIR}/../mesh-sync-all.sh"
	if [[ -x "$sync_script" ]]; then
		local my_role=""
		my_role=$(sqlite3 "$DB_FILE" \
			"SELECT role FROM peer_heartbeats WHERE host='${PLAN_DB_HOST}' LIMIT 1;" \
			2>/dev/null || echo "")
		if [[ "$my_role" == "worker" ]]; then
			log_info "Worker node — reverse-syncing to coordinator..."
			local coordinator_alias=""
			coordinator_alias=$(awk -F= '
				/^\[/{section=$0; gsub(/[\[\]]/,"",section)}
				/^role=coordinator/{print section}
			' "${CLAUDE_HOME:-$HOME/.claude}/config/peers.conf" 2>/dev/null || true)
			if [[ -n "$coordinator_alias" ]]; then
				local coord_ssh
				coord_ssh=$(awk -F= -v s="[$coordinator_alias]" '
					$0==s{found=1} found && /^ssh_alias=/{print $2; exit}
				' "${CLAUDE_HOME:-$HOME/.claude}/config/peers.conf" 2>/dev/null || echo "$coordinator_alias")
				local wt_path
				wt_path=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id=$plan_id;" 2>/dev/null || true)
				wt_path="${wt_path/#\~/$HOME}"
				if [[ -n "$wt_path" && -d "$wt_path" ]]; then
					log_info "Reverse-syncing worktree: $wt_path → $coord_ssh"
					rsync -az -e "ssh -o ConnectTimeout=10 -o BatchMode=yes" \
						"${wt_path}/" "${coord_ssh}:${wt_path}/" 2>&1 \
						| sed 's/^/  [rsync] /' || log_warn "Worktree reverse-sync failed"
				fi
				log_info "Reverse-syncing DB to coordinator"
				sqlite3 "$DB_FILE" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
				scp -o ConnectTimeout=10 -o BatchMode=yes \
					"$DB_FILE" "${coord_ssh}:~/.claude/data/dashboard.db" 2>&1 \
					| sed 's/^/  [scp] /' || log_warn "DB reverse-sync failed"
			fi
		fi
		log_info "Syncing plan results to mesh peers..."
		"$sync_script" 2>&1 | sed 's/^/  [sync] /' || log_warn "Mesh sync failed (non-fatal)"
	fi
}
cmd_set_worktree() {
	local plan_id="$1"
	local wt_path="$2"
	local normalized="$(_normalize_path "$wt_path")"
	local safe_path="$(sql_escape "$normalized")"
	sqlite3 "$DB_FILE" "UPDATE plans SET worktree_path = '$safe_path' WHERE id = $plan_id;"
	log_info "Set worktree for plan $plan_id: $normalized"
}
cmd_set_wave_worktree() {
	local wave_db_id="$1"
	local wt_path="$2"
	local normalized="$(_normalize_path "$wt_path")"
	local safe_path="$(sql_escape "$normalized")"
	sqlite3 "$DB_FILE" "UPDATE waves SET worktree_path = '$safe_path' WHERE id = $wave_db_id;"
	log_info "Set wave worktree for wave $wave_db_id: $normalized"
}
