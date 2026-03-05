#!/bin/bash
# Plan DB CRUD task operations
# Sourced by plan-db-crud.sh

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
	pending | in_progress | submitted | done | blocked | skipped | cancelled) ;;
	*)
		log_error "Invalid task status: '$status'. Valid: pending | in_progress | submitted | done | blocked | skipped | cancelled"
		exit 1
		;;
	esac
	local old_status=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id = $task_id;")

	# Strict: cannot go directly from pending to done or submitted
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
		# Executor finished work, awaiting Thor validation. Does NOT count as done.
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = 'submitted', completed_at = datetime('now'), executor_host = '$PLAN_DB_HOST', notes = '$notes_escaped'$tokens_sql$output_sql WHERE id = $task_id;"
		log_info "Task $task_id submitted — awaiting Thor validation"
	elif [[ "$status" == "done" ]]; then
		# NOTE: This branch is reached ONLY from validate-task (Thor).
		# plan-db.sh guard blocks direct 'done'. enforce_thor_done trigger is final defense.
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', started_at = COALESCE(started_at, datetime('now')), completed_at = COALESCE(completed_at, datetime('now')), executor_host = '$PLAN_DB_HOST', notes = '$notes_escaped'$tokens_sql$output_sql WHERE id = $task_id;"
		# Ensure counter trigger exists
		sqlite3 "$DB_FILE" "
			CREATE TRIGGER IF NOT EXISTS task_done_counter
			AFTER UPDATE OF status ON tasks
			WHEN NEW.status = 'done' AND OLD.status != 'done'
			BEGIN
				UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = NEW.wave_id_fk;
				UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = NEW.plan_id;
			END;
		"
		# Recalculate counters from actual data
		local wave_fk_id plan_fk_id
		IFS='|' read -r wave_fk_id plan_fk_id < <(sqlite3 "$DB_FILE" "SELECT wave_id_fk, plan_id FROM tasks WHERE id = $task_id;")
		[[ -n "$wave_fk_id" ]] && sqlite3 "$DB_FILE" "
			UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_fk_id AND status = 'done') WHERE id = $wave_fk_id;
			UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done),0) FROM waves WHERE plan_id = $plan_fk_id) WHERE id = $plan_fk_id;
		"

		# Check if wave is now complete
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

	# Update plan execution_host on any task change
	sqlite3 "$DB_FILE" "UPDATE plans SET execution_host = '$PLAN_DB_HOST' WHERE id = (SELECT plan_id FROM tasks WHERE id = $task_id);"

	[[ -n "$tokens" ]] && log_info "Task $task_id: $old_status -> $status (tokens: $tokens)" || log_info "Task $task_id: $old_status -> $status"
}

cmd_cancel_task() {
	local task_db_id="$1"
	local reason="${2:-Cancelled by user}"
	local safe_reason="$(sql_escape "$reason")"

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
