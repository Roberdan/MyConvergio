#!/bin/bash
# Plan DB CRUD plan operations
# Sourced by plan-db-crud.sh

cmd_list() {
	local project_id="$1"
	local safe_project_id="$(sql_escape "$project_id")"
	echo -e "${BLUE}Plans for project: ${project_id}${NC}"
	echo ""
	sqlite3 -header -column "$DB_FILE" "
        SELECT id, name,
            CASE WHEN is_master THEN 'MASTER' ELSE '' END as type,
            status, tasks_done || '/' || tasks_total as progress
        FROM plans WHERE project_id = '$safe_project_id'
        ORDER BY is_master DESC, status, name;
    "
}

cmd_create() {
	local project_id="$1"
	local name="$2"
	shift 2
	local is_master=0
	local parent_id="NULL"
	local source_file="" markdown_path="" worktree_path="" auto_worktree=0 description="" human_summary=""

	set +u
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--source-file)
			source_file="$2"
			shift 2
			;;
		--markdown-path)
			markdown_path="$2"
			shift 2
			;;
		--worktree-path)
			worktree_path="$2"
			shift 2
			;;
		--auto-worktree)
			auto_worktree=1
			log_warn "--auto-worktree is deprecated. Use wave-level worktrees (default in new plans). Plan-level worktree created for backward compatibility."
			shift
			;;
		--wave-worktrees)
			# New default: wave-level worktrees (no-op flag, documenting intent)
			shift
			;;
		--description)
			description="$2"
			shift 2
			;;
		--human-summary)
			human_summary="$2"
			shift 2
			;;
		*) shift ;;
		esac
	done
	set -u

	local safe_project_id="$(sql_escape "$project_id")"
	local safe_name="$(sql_escape "$name")"

	[[ "$name" == *"-Main"* ]] || [[ "$name" == *"-Master"* ]] && is_master=1

	if [[ $is_master -eq 0 ]]; then
		local base_name="${name%%-Phase*}"
		base_name="${base_name%%-[0-9]*}"
		local master_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$safe_project_id' AND name LIKE '$(sql_escape "$base_name")%' AND is_master=1 LIMIT 1;")
		[[ -n "$master_id" ]] && parent_id="$master_id"
	fi

	# Auto-extract description from source file if not explicitly provided
	if [[ -z "$description" && -n "$source_file" && -f "$source_file" ]]; then
		description=$(grep -v '^\s*#' "$source_file" | grep -v '^\s*//' | grep -v '^\s*$' | head -1 | cut -c1-200)
	fi

	local sf_val="NULL" mp_val="NULL" md_val="NULL" wp_val="NULL" desc_val="NULL"
	if [[ -n "$source_file" ]]; then
		sf_val="'$(sql_escape "$source_file")'"
	fi
	if [[ -n "$markdown_path" ]]; then
		mp_val="'$(sql_escape "$markdown_path")'"
		md_val="'$(sql_escape "$(dirname "$markdown_path")")'"
	fi
	if [[ -n "$worktree_path" ]]; then
		wp_val="'$(sql_escape "$(_normalize_path "$worktree_path")")'"
	fi
	if [[ -n "$description" ]]; then
		desc_val="'$(sql_escape "$description")'"
	fi
	local hs_val="NULL"
	if [[ -n "$human_summary" ]]; then
		hs_val="'$(sql_escape "$human_summary")'"
	fi

	sqlite3 "$DB_FILE" "
        INSERT INTO plans (project_id, name, is_master, parent_plan_id, status, source_file, markdown_path, markdown_dir, worktree_path, description, human_summary)
        VALUES ('$safe_project_id', '$safe_name', $is_master, $parent_id, 'todo', $sf_val, $mp_val, $md_val, $wp_val, $desc_val, $hs_val);
    "
	local plan_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$safe_project_id' AND name='$safe_name';")

	sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, 1, 'created', 'Plan created', 'planner');
    "
	log_info "Created plan: $name (ID: $plan_id)"

	# Auto-worktree: create worktree + set markdown path in one shot
	if [[ "$auto_worktree" -eq 1 ]]; then
		local project_path
		project_path=$(_expand_path "$(sqlite3 "$DB_FILE" \
			"SELECT path FROM projects WHERE id='$safe_project_id';")")
		[[ -z "$project_path" ]] && project_path=$(pwd)

		local repo_name
		repo_name=$(basename "$project_path")
		local plan_slug
		plan_slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' |
			sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/-$//')
		local wt_branch="plan/${plan_id}-${plan_slug}"
		local wt_path="${project_path}/../${repo_name}-plan-${plan_id}"

		(cd "$project_path" && "$SCRIPT_DIR/worktree-create.sh" "$wt_branch" "$wt_path") >&2
		cmd_set_worktree "$plan_id" "$wt_path"

		# Auto-set markdown_path if not specified
		if [[ -z "$markdown_path" ]]; then
			local plans_dir="${HOME}/.claude/plans/${safe_project_id}"
			mkdir -p "$plans_dir"
			markdown_path="$plans_dir/${name}-Main.md"
			local norm_mp norm_md
			norm_mp=$(_normalize_path "$markdown_path")
			norm_md=$(_normalize_path "$plans_dir")
			sqlite3 "$DB_FILE" "UPDATE plans SET \
				markdown_path='$(sql_escape "$norm_mp")', \
				markdown_dir='$(sql_escape "$norm_md")' \
				WHERE id=$plan_id;"
			log_info "Auto-set markdown: $markdown_path"
		fi
	fi

	echo "$plan_id"
}

cmd_start() {
	local plan_id="$1"
	local force_flag="${2:-}"

	# Atomic claim via cmd_claim (from plan-db-cluster.sh)
	if ! cmd_claim "$plan_id" "$force_flag"; then
		log_error "Failed to claim plan $plan_id. Use --force to override."
		return 1
	fi

	# Plan is now claimed and status set to 'doing' by cmd_claim
	# Record version history
	local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
	sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by, changed_host)
        VALUES ($plan_id, $version, 'started', 'Execution started', 'planner', '$PLAN_DB_HOST');
    "

	# Record active plan for enforce-plan-edit hook
	local active_file="${HOME}/.claude/data/active-plan-id.txt"
	mkdir -p "${HOME}/.claude/data"
	# Append only if not already present
	if ! grep -qxF "$plan_id" "$active_file" 2>/dev/null; then
		echo "$plan_id" >>"$active_file"
	fi

	log_info "Started plan ID: $plan_id (host: $PLAN_DB_HOST)"
}

cmd_get_worktree() {
	local plan_id="$1"
	local wt_path
	wt_path=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id = $plan_id;")
	if [[ -z "$wt_path" ]]; then
		log_error "No worktree_path set for plan $plan_id"
		exit 1
	fi
	echo "$(_expand_path "$wt_path")"
}

# Set worktree path for a plan (normalized to ~)
# Usage: set-worktree <plan_id> <path>
cmd_set_worktree() {
	local plan_id="$1"
	local wt_path="$2"
	local normalized="$(_normalize_path "$wt_path")"
	local safe_path="$(sql_escape "$normalized")"
	sqlite3 "$DB_FILE" "UPDATE plans SET worktree_path = '$safe_path' WHERE id = $plan_id;"
	log_info "Set worktree for plan $plan_id: $normalized"
}

cmd_cancel() {
	local plan_id="$1"
	local reason="${2:-Cancelled by user}"
	local safe_reason="$(sql_escape "$reason")"

	local current_status
	current_status=$(sqlite3 "$DB_FILE" "SELECT status FROM plans WHERE id = $plan_id;")
	if [[ -z "$current_status" ]]; then
		log_error "Plan $plan_id not found"
		return 1
	fi
	if [[ "$current_status" == "done" || "$current_status" == "cancelled" ]]; then
		log_error "Plan $plan_id is already '$current_status' — cannot cancel"
		return 1
	fi

	sqlite3 "$DB_FILE" <<SQL
BEGIN TRANSACTION;
-- Cancel pending/in_progress/blocked tasks
UPDATE tasks SET
    status = 'cancelled',
    cancelled_at = datetime('now'),
    cancelled_reason = '$safe_reason'
WHERE plan_id = $plan_id AND status IN ('pending', 'in_progress', 'blocked');
-- Cancel pending/in_progress/blocked waves
UPDATE waves SET
    status = 'cancelled',
    cancelled_at = datetime('now'),
    cancelled_reason = '$safe_reason'
WHERE plan_id = $plan_id AND status IN ('pending', 'in_progress', 'blocked');
-- Cancel plan
UPDATE plans SET
    status = 'cancelled',
    cancelled_at = datetime('now'),
    cancelled_reason = '$safe_reason'
WHERE id = $plan_id;
COMMIT;
SQL

	local cancelled_tasks cancelled_waves
	cancelled_tasks=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id = $plan_id AND status = 'cancelled';")
	cancelled_waves=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM waves WHERE plan_id = $plan_id AND status = 'cancelled';")
	log_info "Cancelled plan $plan_id: $cancelled_tasks tasks, $cancelled_waves waves ($reason)"

	# Cleanup enforce-plan-edit cache files
	_cleanup_plan_file_cache "$plan_id"
}
