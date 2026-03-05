#!/bin/bash
# Wave-level validation functions

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

# Evaluate wave preconditions - returns READY, SKIP, or BLOCKED
# Usage: cmd_evaluate_wave <wave_db_id>
# Output: JSON to stdout
cmd_evaluate_wave() {
	local wave_db_id="$1"

	local wave_row
	wave_row=$(sqlite3 "$DB_FILE" \
		"SELECT plan_id, wave_id, precondition FROM waves WHERE id = $wave_db_id;")
	if [[ -z "$wave_row" ]]; then
		echo '{"result":"BLOCKED","wave_id":"?","details":[{"error":"wave not found"}]}'
		return 1
	fi

	local plan_id wave_id precondition
	plan_id=$(echo "$wave_row" | cut -d'|' -f1)
	wave_id=$(echo "$wave_row" | cut -d'|' -f2)
	precondition=$(echo "$wave_row" | cut -d'|' -f3-)

	if [[ -z "$precondition" || "$precondition" == "null" ]]; then
		echo "{\"result\":\"READY\",\"wave_id\":\"$wave_id\",\"details\":[]}"
		return 0
	fi

	if ! echo "$precondition" | jq -e '.' >/dev/null 2>&1; then
		echo "{\"result\":\"BLOCKED\",\"wave_id\":\"$wave_id\",\"details\":[{\"error\":\"invalid precondition JSON\"}]}"
		return 1
	fi

	local cond_count
	cond_count=$(echo "$precondition" | jq 'length')
	local details="[]"
	local final_result="READY"

	for ((i = 0; i < cond_count; i++)); do
		local cond cond_type met="false"
		cond=$(echo "$precondition" | jq -c ".[$i]")
		cond_type=$(echo "$cond" | jq -r '.type')

		case "$cond_type" in
		wave_status)
			local target_wave_id target_status actual_status
			target_wave_id=$(echo "$cond" | jq -r '.wave_id')
			target_status=$(echo "$cond" | jq -r '.status')
			actual_status=$(sqlite3 "$DB_FILE" \
				"SELECT status FROM waves WHERE plan_id = $plan_id AND wave_id = '$target_wave_id';")
			if [[ "$actual_status" == "$target_status" ]]; then
				met="true"
			else
				if [[ "$final_result" != "SKIP" ]]; then final_result="BLOCKED"; fi
			fi
			;;
		output_match)
			local task_id output_path equals_val actual_data extracted
			task_id=$(echo "$cond" | jq -r '.task_id')
			output_path=$(echo "$cond" | jq -r '.output_path')
			equals_val=$(echo "$cond" | jq -r '.equals')
			actual_data=$(sqlite3 "$DB_FILE" \
				"SELECT output_data FROM tasks WHERE plan_id = $plan_id AND task_id = '$task_id';")
			if [[ -n "$actual_data" ]]; then
				extracted=$(echo "$actual_data" | jq -r "$output_path" 2>/dev/null || echo "")
				if [[ "$extracted" == "$equals_val" ]]; then
					met="true"
				else
					if [[ "$final_result" != "SKIP" ]]; then final_result="BLOCKED"; fi
				fi
			else
				if [[ "$final_result" != "SKIP" ]]; then final_result="BLOCKED"; fi
			fi
			;;
		skip_if)
			local task_id output_path equals_val actual_data extracted
			task_id=$(echo "$cond" | jq -r '.task_id')
			output_path=$(echo "$cond" | jq -r '.output_path')
			equals_val=$(echo "$cond" | jq -r '.equals')
			actual_data=$(sqlite3 "$DB_FILE" \
				"SELECT output_data FROM tasks WHERE plan_id = $plan_id AND task_id = '$task_id';")
			if [[ -n "$actual_data" ]]; then
				extracted=$(echo "$actual_data" | jq -r "$output_path" 2>/dev/null || echo "")
				if [[ "$extracted" == "$equals_val" ]]; then
					met="true"
					final_result="SKIP"
				fi
			fi
			;;
		*)
			if [[ "$final_result" != "SKIP" ]]; then final_result="BLOCKED"; fi
			;;
		esac

		details=$(echo "$details" | jq \
			--argjson cond "$cond" \
			--argjson met "$met" \
			'. + [{"condition": $cond, "met": $met}]')
	done

	echo "$details" | jq -c \
		--arg result "$final_result" \
		--arg wave_id "$wave_id" \
		'{"result": $result, "wave_id": $wave_id, "details": .}'
	return 0
}
