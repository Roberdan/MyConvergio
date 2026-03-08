#!/bin/bash
# Plan DB CRUD wave operations
# Sourced by plan-db-crud.sh

cmd_add_wave() {
	local plan_id="$1"
	local wave_id="$2"
	local name="$3"
	shift 3

	local assignee="" planned_start="" planned_end="" estimated_hours="8" depends_on="" precondition="" merge_mode="sync" theme=""

	set +u
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--merge-mode)
			[[ -z "${2}" ]] && {
				log_error "Missing --merge-mode value"
				set -u
				exit 1
			}
			merge_mode="$2"
			shift 2
			;;
		--theme)
			[[ -z "${2}" ]] && {
				log_error "Missing --theme value"
				set -u
				exit 1
			}
			theme="$2"
			shift 2
			;;
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

	local safe_planned_start="$(sql_lit "$planned_start")"
	local safe_planned_end="$(sql_lit "$planned_end")"
	local safe_depends_val="$(sql_lit "$depends_on")"

	local start_val="NULL" end_val="NULL" depends_val="NULL" precond_val="NULL"
	[[ -n "$planned_start" ]] && start_val="'$safe_planned_start'"
	[[ -n "$planned_end" ]] && end_val="'$safe_planned_end'"
	[[ -n "$depends_on" ]] && depends_val="'$safe_depends_val'"
	[[ -n "$precondition" ]] && precond_val="'$(sql_lit "$precondition")'"

	local safe_wave_id="$(sql_lit "$wave_id")"
	local safe_name="$(sql_lit "$name")"
	local safe_assignee="$(sql_lit "$assignee")"
	local safe_merge_mode="$(sql_lit "$merge_mode")"
	local theme_val="NULL"
	[[ -n "$theme" ]] && theme_val="'$(sql_lit "$theme")'"
	sqlite3 "$DB_FILE" "
        INSERT INTO waves (project_id, plan_id, wave_id, name, status, assignee, position, estimated_hours, planned_start, planned_end, depends_on, precondition, merge_mode, theme)
        VALUES ('$project_id', $plan_id, '$safe_wave_id', '$safe_name', 'pending', '$safe_assignee', $position, $estimated_hours, $start_val, $end_val, $depends_val, $precond_val, '$safe_merge_mode', $theme_val);
    "
	local db_wave_id=$(sqlite3 "$DB_FILE" "SELECT id FROM waves WHERE plan_id=$plan_id AND wave_id='$safe_wave_id';")
	log_info "Added wave: $name (ID: $db_wave_id)"
	echo "$db_wave_id"
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

cmd_get_wave_worktree() {
	local wave_db_id="$1"
	local wt_path
	wt_path=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM waves WHERE id = $wave_db_id;")
	if [[ -z "$wt_path" ]]; then
		log_error "No worktree_path set for wave $wave_db_id"
		exit 1
	fi
	echo "$(_expand_path "$wt_path")"
}

# Set wave worktree path (normalized to ~)
# Usage: set-wave-worktree <wave_db_id> <path>
cmd_set_wave_worktree() {
	local wave_db_id="$1"
	local wt_path="$2"
	local normalized="$(_normalize_path "$wt_path")"
	local safe_path="$(sql_lit "$normalized")"
	sqlite3 "$DB_FILE" "UPDATE waves SET worktree_path = '$safe_path' WHERE id = $wave_db_id;"
	log_info "Set wave worktree for wave $wave_db_id: $normalized"
}

cmd_cancel_wave() {
	local wave_db_id="$1"
	local reason="${2:-Cancelled by user}"
	local safe_reason="$(sql_lit "$reason")"

	local wave_status wave_id
	IFS='|' read -r wave_status wave_id < <(sqlite3 "$DB_FILE" "SELECT status, wave_id FROM waves WHERE id = $wave_db_id;")
	if [[ -z "$wave_status" ]]; then
		log_error "Wave $wave_db_id not found"
		return 1
	fi
	if [[ "$wave_status" == "done" || "$wave_status" == "cancelled" ]]; then
		log_error "Wave $wave_id is already '$wave_status' — cannot cancel"
		return 1
	fi

	sqlite3 "$DB_FILE" <<SQL
BEGIN TRANSACTION;
UPDATE tasks SET
    status = 'cancelled',
    cancelled_at = datetime('now'),
    cancelled_reason = '$safe_reason'
WHERE wave_id_fk = $wave_db_id AND status IN ('pending', 'in_progress', 'blocked');
UPDATE waves SET
    status = 'cancelled',
    cancelled_at = datetime('now'),
    cancelled_reason = '$safe_reason'
WHERE id = $wave_db_id;
COMMIT;
SQL

	local cancelled_tasks
	cancelled_tasks=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'cancelled';")
	log_info "Cancelled wave $wave_id (db:$wave_db_id): $cancelled_tasks tasks ($reason)"
}
