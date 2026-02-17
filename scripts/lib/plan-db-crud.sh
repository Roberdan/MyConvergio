#!/bin/bash
# Plan DB CRUD - Create, Read, Update operations
# Sourced by plan-db.sh

# Version: 1.2.0
# List plans for a project
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

# Create a new plan
# Usage: create <project_id> <name> [--source-file path] [--markdown-path path] [--worktree-path path]
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

# Start a plan
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
	log_info "Started plan ID: $plan_id (host: $PLAN_DB_HOST)"
}

# Add wave to plan
cmd_add_wave() {
	local plan_id="$1"
	local wave_id="$2"
	local name="$3"
	shift 3

	local assignee="" planned_start="" planned_end="" estimated_hours="8" depends_on="" precondition=""

	set +u
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--assignee)
			[[ -z "${2}" ]] && {
				log_error "Missing --assignee value"
				set -u
				exit 1
			}
			assignee="$2"
			shift 2
			;;
		--planned-start)
			[[ -z "${2}" ]] && {
				log_error "Missing --planned-start value"
				set -u
				exit 1
			}
			planned_start="$2"
			shift 2
			;;
		--planned-end)
			[[ -z "${2}" ]] && {
				log_error "Missing --planned-end value"
				set -u
				exit 1
			}
			planned_end="$2"
			shift 2
			;;
		--estimated-hours)
			[[ -z "${2}" ]] && {
				log_error "Missing --estimated-hours value"
				set -u
				exit 1
			}
			estimated_hours="$2"
			shift 2
			;;
		--depends-on)
			[[ -z "${2}" ]] && {
				log_error "Missing --depends-on value"
				set -u
				exit 1
			}
			depends_on="$2"
			shift 2
			;;
		--precondition)
			[[ -z "${2}" ]] && {
				log_error "Missing --precondition value"
				set -u
				exit 1
			}
			precondition="$2"
			shift 2
			;;
		*)
			assignee="$1"
			shift
			;;
		esac
	done
	set -u

	local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")
	local position=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(position), 0) + 1 FROM waves WHERE plan_id = $plan_id;")

	local safe_planned_start="$(sql_escape "$planned_start")"
	local safe_planned_end="$(sql_escape "$planned_end")"
	local safe_depends_val="$(sql_escape "$depends_on")"

	local start_val="NULL" end_val="NULL" depends_val="NULL" precond_val="NULL"
	[[ -n "$planned_start" ]] && start_val="'$safe_planned_start'"
	[[ -n "$planned_end" ]] && end_val="'$safe_planned_end'"
	[[ -n "$depends_on" ]] && depends_val="'$safe_depends_val'"
	[[ -n "$precondition" ]] && precond_val="'$(sql_escape "$precondition")'"

	local safe_wave_id="$(sql_escape "$wave_id")"
	local safe_name="$(sql_escape "$name")"
	local safe_assignee="$(sql_escape "$assignee")"
	sqlite3 "$DB_FILE" "
        INSERT INTO waves (project_id, plan_id, wave_id, name, status, assignee, position, estimated_hours, planned_start, planned_end, depends_on, precondition)
        VALUES ('$project_id', $plan_id, '$safe_wave_id', '$safe_name', 'pending', '$safe_assignee', $position, $estimated_hours, $start_val, $end_val, $depends_val, $precond_val);
    "
	local db_wave_id=$(sqlite3 "$DB_FILE" "SELECT id FROM waves WHERE plan_id=$plan_id AND wave_id='$safe_wave_id';")
	log_info "Added wave: $name (ID: $db_wave_id)"
	echo "$db_wave_id"
}

# Add task to wave
# Usage: add-task <wave_id> <task_id> <title> [P0-P3] [feature|bug|chore] [--model <model>] [--effort 1|2|3] [--test-criteria 'json'] [--description 'text']
# Models: freeform (haiku, sonnet, opus, codex, gpt-4o, o3, etc.)
# Effort: 1=low, 2=medium, 3=high (used for weighted progress)
cmd_add_task() {
	local db_wave_id="$1"
	local task_id="$2"
	local title="$3"
	shift 3

	local priority="P1" type="feature" assignee="" test_criteria="" model="sonnet" description="" executor_agent="" effort_level="1"

	set +u
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--test-criteria)
			[[ -z "${2}" ]] && {
				log_error "Missing --test-criteria value"
				set -u
				exit 1
			}
			test_criteria="$2"
			shift 2
			;;
		--model)
			[[ -z "${2}" ]] && {
				log_error "Missing --model value"
				set -u
				exit 1
			}
			model="$2"
			shift 2
			;;
		--effort)
			[[ -z "${2}" ]] && {
				log_error "Missing --effort value (1/2/3)"
				set -u
				exit 1
			}
			effort_level="$2"
			shift 2
			;;
		--description)
			[[ -z "${2}" ]] && {
				log_error "Missing --description value"
				set -u
				exit 1
			}
			description="$2"
			shift 2
			;;
		--executor-agent)
			[[ -z "${2}" ]] && {
				log_error "Missing --executor-agent value"
				set -u
				exit 1
			}
			executor_agent="$2"
			shift 2
			;;
		P0 | P1 | P2 | P3)
			priority="$1"
			shift
			;;
		bug | feature | chore | doc | test)
			type="$1"
			shift
			;;
		haiku | sonnet | opus)
			model="$1"
			shift
			;;
		*)
			[[ -z "$assignee" ]] && assignee="$1"
			shift
			;;
		esac
	done
	set -u

	local project_id wave_id_text plan_id
	IFS='|' read -r project_id wave_id_text plan_id < <(sqlite3 "$DB_FILE" "SELECT project_id, wave_id, plan_id FROM waves WHERE id = $db_wave_id;")

	local safe_task_id="$(sql_escape "$task_id")"
	local safe_title="$(sql_escape "$title")"
	local safe_priority="$(sql_escape "$priority")"
	local safe_type="$(sql_escape "$type")"
	local safe_assignee="$(sql_escape "$assignee")"
	local safe_test_criteria="$(sql_escape "$test_criteria")"
	local safe_model="$(sql_escape "$model")"
	local safe_description="$(sql_escape "$description")"
	local safe_executor_agent="$(sql_escape "$executor_agent")"

	local tc_val="NULL"
	[[ -n "$test_criteria" ]] && tc_val="'$safe_test_criteria'"
	local desc_val="NULL"
	[[ -n "$description" ]] && desc_val="'$safe_description'"
	local exec_agent_val="NULL"
	[[ -n "$executor_agent" ]] && exec_agent_val="'$safe_executor_agent'"

	# Ensure effort_level column exists (pre-migration DBs may lack it)
	sqlite3 "$DB_FILE" "ALTER TABLE tasks ADD COLUMN effort_level INTEGER DEFAULT 1 CHECK(effort_level IN (1, 2, 3));" 2>/dev/null || true

	sqlite3 "$DB_FILE" <<SQL
BEGIN TRANSACTION;
INSERT INTO tasks (project_id, wave_id, wave_id_fk, plan_id, task_id, title, description, status, priority, type, assignee, test_criteria, model, executor_agent, effort_level)
VALUES ('$project_id', '$wave_id_text', $db_wave_id, $plan_id, '$safe_task_id', '$safe_title', COALESCE($desc_val, '$safe_title'), 'pending', '$safe_priority', '$safe_type', '$safe_assignee', $tc_val, '$safe_model', $exec_agent_val, $effort_level);
UPDATE waves SET tasks_total = tasks_total + 1 WHERE id = $db_wave_id;
UPDATE plans SET tasks_total = tasks_total + 1 WHERE id = $plan_id;
COMMIT;
SQL

	local db_task_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE plan_id=$plan_id AND wave_id_fk=$db_wave_id AND task_id='$safe_task_id' ORDER BY id DESC LIMIT 1;")
	log_info "Added task: $title (ID: $db_task_id)"
	echo "$db_task_id"
}

# Update task status
# Usage: update-task <task_id> <status> [notes] [--tokens N]
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

	# Validate JSON if output_data provided
	if [[ -n "$output_data" ]]; then
		echo "$output_data" | jq -e . >/dev/null 2>&1 || {
			log_error "Invalid JSON in --output-data"
			exit 1
		}
	fi

	case "$status" in
	pending | in_progress | done | blocked | skipped) ;;
	*)
		log_error "Invalid task status: '$status'. Valid: pending | in_progress | done | blocked | skipped"
		exit 1
		;;
	esac
	local old_status=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id = $task_id;")

	# Strict: cannot go directly from pending to done
	if [[ "$status" == "done" && "$old_status" == "pending" ]]; then
		log_error "Cannot transition pending→done directly. Mark as in_progress first."
		exit 1
	fi
	local tokens_sql=""
	[[ -n "$tokens" ]] && tokens_sql=", tokens = $tokens"

	local output_sql=""
	[[ -n "$output_data" ]] && output_sql=", output_data = '$(sql_escape "$output_data")'"

	if [[ "$status" == "in_progress" ]]; then
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', started_at = datetime('now'), executor_host = '$PLAN_DB_HOST', notes = '$notes_escaped'$tokens_sql$output_sql WHERE id = $task_id;"
	elif [[ "$status" == "done" ]]; then
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', started_at = COALESCE(started_at, datetime('now')), completed_at = datetime('now'), executor_host = '$PLAN_DB_HOST', notes = '$notes_escaped'$tokens_sql$output_sql WHERE id = $task_id;"
		# NOTE: wave/plan counters updated automatically by SQLite trigger (task_done_counter)

		# Check if wave is now complete (for auto-marking wave as done)
		local wave_fk wave_done wave_id_text
		IFS='|' read -r wave_fk wave_done wave_id_text < <(sqlite3 "$DB_FILE" "SELECT t.wave_id_fk, (w.tasks_done = w.tasks_total), w.wave_id FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE t.id = $task_id;")
		[[ "$wave_done" == "1" ]] && {
			sqlite3 "$DB_FILE" "UPDATE waves SET status = 'done', started_at = COALESCE(started_at, datetime('now')), completed_at = datetime('now') WHERE id = $wave_fk;"
			log_info "Wave $wave_id_text completed!"
		}
	else
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', executor_host = '$PLAN_DB_HOST', notes = '$notes_escaped'$tokens_sql$output_sql WHERE id = $task_id;"
	fi

	# Update plan execution_host on any task change
	sqlite3 "$DB_FILE" "UPDATE plans SET execution_host = '$PLAN_DB_HOST' WHERE id = (SELECT plan_id FROM tasks WHERE id = $task_id);"

	[[ -n "$tokens" ]] && log_info "Task $task_id: $old_status -> $status (tokens: $tokens)" || log_info "Task $task_id: $old_status -> $status"
}

# Update wave status
cmd_update_wave() {
	local wave_id="$1"
	local status="$2"

	case "$status" in
	pending | in_progress | done | blocked) ;;
	*)
		log_error "Invalid wave status: '$status'. Valid: pending | in_progress | done | blocked"
		exit 1
		;;
	esac

	if [[ "$status" == "in_progress" ]]; then
		sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', started_at = datetime('now') WHERE id = $wave_id;"
	elif [[ "$status" == "done" ]]; then
		sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', started_at = COALESCE(started_at, datetime('now')), completed_at = datetime('now') WHERE id = $wave_id;"
	else
		sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status' WHERE id = $wave_id;"
	fi
	log_info "Wave $wave_id -> $status"
}

# Complete plan
cmd_complete() {
	local plan_id="$1"
	local force_flag="${2:-}"
	local tasks_done tasks_total validated_at worktree_path
	IFS='|' read -r tasks_done tasks_total validated_at worktree_path < <(sqlite3 "$DB_FILE" "SELECT tasks_done, tasks_total, validated_at, worktree_path FROM plans WHERE id = $plan_id;")

	if [[ -z "$tasks_total" || "$tasks_total" -eq 0 ]]; then
		log_error "Cannot complete plan $plan_id: no tasks"
		return 1
	fi
	if [[ "$tasks_done" -lt "$tasks_total" ]]; then
		log_error "Cannot complete plan $plan_id: $tasks_done/$tasks_total tasks done"
		return 1
	fi
	if [[ -z "$validated_at" ]]; then
		log_error "Cannot complete plan $plan_id: Thor validation required"
		return 1
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

	# Auto-cleanup worktree if merged
	if [[ -x "$SCRIPT_DIR/worktree-cleanup.sh" ]]; then
		"$SCRIPT_DIR/worktree-cleanup.sh" --plan "$plan_id" 2>&1 || true
	fi
}

# Calculate git lines added/removed for a completed plan
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

# Normalize path: replace $HOME with ~ for portability across machines
# /home/user/GitHub/X -> ~/GitHub/X
# /Users/user/GitHub/X -> ~/GitHub/X
_normalize_path() {
	local p="$1"
	echo "$p" | sed "s|^${HOME}|~|"
}

# Expand path: replace leading ~ with $HOME for runtime use
_expand_path() {
	local p="$1"
	echo "$p" | sed "s|^~|${HOME}|"
}

# Get worktree path for a plan (expanded to $HOME)
# Usage: get-worktree <plan_id>
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

# Show execution host for plans
# Usage: where [plan_id]
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
