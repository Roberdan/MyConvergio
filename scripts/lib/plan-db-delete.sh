#!/bin/bash
# Plan DB DELETE operations
# Sourced by plan-db-crud.sh

# Cancel a plan (cascades to pending/in_progress tasks and waves)
# Usage: cancel <plan_id> [reason]
cmd_cancel() {
	local plan_id="$1"
	local reason="${2:-Cancelled by user}"
	local safe_reason="$(sql_lit "$reason")"

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

# Cancel a single wave (cascades to its pending/in_progress tasks)
# Usage: cancel-wave <wave_db_id> [reason]
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

# Cancel a single task
# Usage: cancel-task <task_db_id> [reason]
cmd_cancel_task() {
	local task_db_id="$1"
	local reason="${2:-Cancelled by user}"
	local safe_reason="$(sql_lit "$reason")"

	local task_status task_id
	IFS='|' read -r task_status task_id < <(sqlite3 "$DB_FILE" "SELECT status, task_id FROM tasks WHERE id = $task_db_id;")
	if [[ -z "$task_status" ]]; then
		log_error "Task $task_db_id not found"
		return 1
	fi
	if [[ "$task_status" == "done" || "$task_status" == "cancelled" ]]; then
		log_error "Task $task_id is already '$task_status' — cannot cancel"
		return 1
	fi

	sqlite3 "$DB_FILE" "
		UPDATE tasks SET
		    status = 'cancelled',
		    cancelled_at = datetime('now'),
		    cancelled_reason = '$safe_reason'
		WHERE id = $task_db_id;
	"
	log_info "Cancelled task $task_id (db:$task_db_id): $reason"
}
