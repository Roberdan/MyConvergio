#!/bin/bash
# Plan DB Validation - Gate 8 (per-task/wave validation)
# Sourced by lib/plan-db-validate.sh

# Version: 1.1.0

# Validate a single task by DB id or task_id within a plan
# Usage: validate-task <task_db_id_or_task_id> [plan_id] [validated_by] [--force] [--report 'JSON']
# Sets validated_at + validated_by + validation_report on the task
cmd_validate_task() {
	local identifier="$1"
	local plan_id="${2:-}"
	local validated_by="${3:-thor}"
	local force=false
	local report=""

	local skip_next=false
	local i
	for i in "$@"; do
		if [[ "$skip_next" == true ]]; then
			skip_next=false
			continue
		fi
		case "$i" in
		--force) force=true ;;
		--report) skip_next=true ;;
		esac
	done
	report=$(thor_extract_report_arg "$@")

	local task_db_id
	task_db_id=$(thor_resolve_task_db_id "$identifier" "$plan_id")
	if [[ -z "$task_db_id" ]]; then
		log_error "Task not found: $identifier (plan: ${plan_id:-any})"
		return 1
	fi

	local task_status
	task_status=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id = $task_db_id;")
	if [[ "$task_status" != "submitted" && "$task_status" != "done" ]]; then
		log_error "Task $identifier status is '$task_status' — only 'submitted' or 'done' tasks can be validated"
		log_error "Flow: in_progress → submitted (plan-db-safe.sh) → done (Thor validate-task)"
		return 1
	fi

	if [[ "$task_status" == "done" ]]; then
		local already_validated
		already_validated=$(sqlite3 "$DB_FILE" "SELECT validated_at FROM tasks WHERE id = $task_db_id;")
		if [[ -n "$already_validated" ]]; then
			echo -e "${YELLOW}Task $identifier already validated at $already_validated${NC}"
			return 0
		fi
	fi

	local effective_validator="$validated_by"
	if [[ "$force" == false ]]; then
		if ! thor_is_allowed_validator "$validated_by"; then
			log_error "REJECTED: Validator '$validated_by' is not a Thor agent."
			log_error "Only [thor|thor-quality-assurance-guardian|thor-per-wave] can validate tasks. Use --force to override (audited)."
			return 1
		fi
	else
		if ! thor_is_allowed_validator "$validated_by"; then
			effective_validator="forced-admin"
			log_warn "FORCED validation: using 'forced-admin' validator (audited, not Thor)"
			local timestamp audit_entry
			timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
			audit_entry="{\"timestamp\":\"$timestamp\",\"event\":\"forced_validation\",\"task_db_id\":$task_db_id,\"validated_by\":\"$validated_by\",\"forced_as\":\"forced-admin\",\"action\":\"forced_bypass\"}"
			mkdir -p "$(dirname "$AUDIT_LOG")"
			echo "$audit_entry" >>"$AUDIT_LOG" 2>/dev/null || true
		fi
	fi

	local report_clause=""
	if [[ -n "$report" ]]; then
		report_clause=", validation_report = '$(sql_escape "$report")'"
	fi

	local task_id_text
	task_id_text=$(sqlite3 "$DB_FILE" "SELECT task_id FROM tasks WHERE id = $task_db_id;")

	if [[ "$task_status" == "submitted" ]]; then
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = 'done', completed_at = COALESCE(completed_at, datetime('now')), validated_at = datetime('now'), validated_by = '$(sql_escape "$effective_validator")'${report_clause} WHERE id = $task_db_id AND status = 'submitted';"

		local wave_fk_id plan_fk_id
		IFS='|' read -r wave_fk_id plan_fk_id < <(sqlite3 "$DB_FILE" "SELECT wave_id_fk, plan_id FROM tasks WHERE id = $task_db_id;")
		if [[ -n "$wave_fk_id" ]]; then
			sqlite3 "$DB_FILE" "
UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_fk_id AND status = 'done') WHERE id = $wave_fk_id;
UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done),0) FROM waves WHERE plan_id = $plan_fk_id) WHERE id = $plan_fk_id;
"
			local wave_all_done
			wave_all_done=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_fk_id AND status NOT IN ('done', 'cancelled', 'skipped');")
			if [[ "$wave_all_done" -eq 0 ]]; then
				log_info "Wave fully validated — all tasks done"
			fi
		fi

		# Token attribution: sum token_usage entries in task time window (DB-only, no file reads)
		{
			local tu_project_id tu_started_at tu_completed_at
			IFS='|' read -r tu_project_id tu_started_at tu_completed_at < <(sqlite3 "$DB_FILE" "
  SELECT pl.project_id, t.started_at, t.completed_at
  FROM tasks t JOIN plans pl ON t.plan_id = pl.id
  WHERE t.id = $task_db_id;" 2>/dev/null)
			if [[ -n "$tu_started_at" ]]; then
				local tu_end="${tu_completed_at:-$(date -u '+%Y-%m-%d %H:%M:%S')}"
				local safe_pid
				safe_pid=$(sql_escape "$tu_project_id")
				# Prefer real API counts from token_usage over _ap_tokens estimates.
				# If time-window has no data, keep existing tokens (don't regress to 0).
				sqlite3 "$DB_FILE" "
    UPDATE tasks SET tokens = COALESCE(
      (SELECT SUM(input_tokens + output_tokens) FROM token_usage
       WHERE project_id = '$safe_pid'
         AND created_at >= '$tu_started_at'
         AND created_at <= '$tu_end'),
      tokens,
      0)
    WHERE id = $task_db_id;" 2>/dev/null || true
			fi
		} 2>/dev/null || true

		echo -e "${GREEN}Task $task_id_text: submitted → done (validated by $effective_validator)${NC}"
	else
		sqlite3 "$DB_FILE" "UPDATE tasks SET validated_at = datetime('now'), validated_by = '$(sql_escape "$effective_validator")'${report_clause} WHERE id = $task_db_id;"
		echo -e "${GREEN}Task $task_id_text validated by $effective_validator (legacy re-validation)${NC}"
	fi

	[[ -n "$report" ]] && echo -e "${GREEN}  Validation report saved${NC}"
	return 0
}

# Validate all done tasks in a wave
# Usage: validate-wave <wave_db_id> [validated_by]
cmd_validate_wave() {
	local wave_db_id="$1"
	local validated_by="${2:-thor}"

	local wave_info
	wave_info=$(sqlite3 -separator '|' "$DB_FILE" "SELECT wave_id, plan_id, tasks_done, tasks_total FROM waves WHERE id = $wave_db_id;")
	if [[ -z "$wave_info" ]]; then
		log_error "Wave not found: $wave_db_id"
		return 1
	fi

	local wave_id plan_id tasks_done tasks_total
	IFS='|' read -r wave_id plan_id tasks_done tasks_total <<<"$wave_info"

	local not_resolved
	not_resolved=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status NOT IN ('done', 'cancelled', 'skipped');")
	if [[ "$not_resolved" -gt 0 ]]; then
		local submitted_count
		submitted_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'submitted';")
		if [[ "$submitted_count" -gt 0 ]]; then
			log_error "Wave $wave_id has $submitted_count tasks in SUBMITTED status — Thor must validate each before wave completion"
			sqlite3 "$DB_FILE" "SELECT task_id, title FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'submitted';" | while IFS='|' read -r tid title; do
				echo "  - $tid: $title (needs: plan-db.sh validate-task $tid)"
			done
		fi
		local other_count=$((not_resolved - submitted_count))
		if [[ "$other_count" -gt 0 ]]; then
			log_error "Wave $wave_id has $other_count unresolved tasks (not submitted/done/cancelled/skipped)"
		fi
		return 1
	fi

	local not_validated
	not_validated=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'done' AND validated_at IS NULL;")
	if [[ "$not_validated" -gt 0 ]]; then
		log_error "Wave $wave_id has $not_validated done tasks NOT validated by Thor — run per-task validation first"
		sqlite3 "$DB_FILE" "SELECT task_id, title FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'done' AND validated_at IS NULL;" | while IFS='|' read -r tid title; do
			echo "  - $tid: $title"
		done
		return 1
	fi

	echo -e "${YELLOW}Wave $wave_id: all tasks already validated${NC}"
	sqlite3 "$DB_FILE" "UPDATE waves SET status = 'done', completed_at = COALESCE(completed_at, datetime('now')) WHERE id = $wave_db_id;"

	return 0
}
