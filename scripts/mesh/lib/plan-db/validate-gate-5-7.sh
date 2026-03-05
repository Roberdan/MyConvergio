#!/bin/bash
# Plan DB Validation - Gates 5-7 (wave/data quality gates)
# Sourced by lib/plan-db-validate.sh

# Version: 1.0.0

validate_gate_5_date_consistency() {
local plan_id="$1"
echo -e "${YELLOW}[5/7] Date consistency...${NC}"
local bad_dates
bad_dates=$(sqlite3 "$DB_FILE" "SELECT wave_id FROM waves WHERE plan_id = $plan_id AND planned_end < planned_start;")
if [[ -n "$bad_dates" ]]; then
echo -e "${YELLOW}  WARNING: Waves with end < start${NC}"
thor_add_validation_warning
else
echo -e "${GREEN}  OK${NC}"
fi
}

validate_gate_6_executor_agent_tracking() {
local plan_id="$1"
echo -e "${YELLOW}[6/7] Executor agent tracking...${NC}"
local missing_agent
missing_agent=$(sqlite3 "$DB_FILE" "
SELECT COUNT(*) FROM tasks t
JOIN waves w ON t.wave_id_fk = w.id
WHERE w.plan_id = $plan_id AND t.status = 'done' AND (t.executor_agent IS NULL OR t.executor_agent = '');
")
if [[ "$missing_agent" -gt 0 ]]; then
echo -e "${YELLOW}  WARNING: $missing_agent done tasks missing executor_agent${NC}"
thor_add_validation_warning
else
echo -e "${GREEN}  OK${NC}"
fi
}

validate_gate_7_output_data_json_validity() {
local plan_id="$1"
echo -e "${YELLOW}[7/7] Output data JSON validity...${NC}"
local invalid_json=0
local tasks_with_output
tasks_with_output=$(sqlite3 "$DB_FILE" "
SELECT t.task_id, t.output_data FROM tasks t
JOIN waves w ON t.wave_id_fk = w.id
WHERE w.plan_id = $plan_id AND t.output_data IS NOT NULL AND t.output_data != '';
")
while IFS='|' read -r tid output; do
[[ -z "$tid" ]] && continue
if ! echo "$output" | jq -e . >/dev/null 2>&1; then
echo -e "${RED}  ERROR: Task $tid has invalid JSON in output_data${NC}"
invalid_json=$((invalid_json + 1))
fi
done <<<"$tasks_with_output"
if [[ "$invalid_json" -gt 0 ]]; then
echo -e "${RED}  ERROR: $invalid_json tasks with invalid output_data JSON${NC}"
thor_add_validation_error
else
echo -e "${GREEN}  OK${NC}"
fi
}

# Sync counters
cmd_sync() {
local plan_id="$1"
log_info "Syncing counters for plan $plan_id..."

sqlite3 "$DB_FILE" "
UPDATE waves SET
tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status = 'done'),
tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status NOT IN ('cancelled', 'skipped'))
WHERE plan_id = $plan_id;
"

sqlite3 "$DB_FILE" "
UPDATE waves SET status = 'done', completed_at = COALESCE(completed_at, datetime('now'))
WHERE plan_id = $plan_id
AND tasks_total > 0
AND status NOT IN ('done', 'merging', 'cancelled')
AND (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status NOT IN ('done', 'cancelled', 'skipped')) = 0;
"

sqlite3 "$DB_FILE" "
UPDATE plans SET
tasks_done = (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE waves.plan_id = plans.id AND waves.status != 'cancelled'),
tasks_total = (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE waves.plan_id = plans.id AND waves.status != 'cancelled')
WHERE id = $plan_id;
"

sqlite3 -header -column "$DB_FILE" "
SELECT wave_id, name, status, tasks_done || '/' || tasks_total as progress
FROM waves WHERE plan_id = $plan_id ORDER BY position;
"
log_info "Sync complete"
}

# Evaluate wave preconditions - returns READY, SKIP, or BLOCKED
# Usage: cmd_evaluate_wave <wave_db_id>
# Output: JSON to stdout
cmd_evaluate_wave() {
local wave_db_id="$1"

local wave_row
wave_row=$(sqlite3 "$DB_FILE" "SELECT plan_id, wave_id, precondition FROM waves WHERE id = $wave_db_id;")
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
local i
for ((i = 0; i < cond_count; i++)); do
local cond cond_type met="false"
cond=$(echo "$precondition" | jq -c ".[$i]")
cond_type=$(echo "$cond" | jq -r '.type')

case "$cond_type" in
wave_status)
local target_wave_id target_status actual_status
target_wave_id=$(echo "$cond" | jq -r '.wave_id')
target_status=$(echo "$cond" | jq -r '.status')
actual_status=$(sqlite3 "$DB_FILE" "SELECT status FROM waves WHERE plan_id = $plan_id AND wave_id = '$target_wave_id';")
if [[ "$actual_status" == "$target_status" ]]; then
met="true"
elif [[ "$final_result" != "SKIP" ]]; then
final_result="BLOCKED"
fi
;;
output_match)
local task_id output_path equals_val actual_data extracted
task_id=$(echo "$cond" | jq -r '.task_id')
output_path=$(echo "$cond" | jq -r '.output_path')
equals_val=$(echo "$cond" | jq -r '.equals')
actual_data=$(sqlite3 "$DB_FILE" "SELECT output_data FROM tasks WHERE plan_id = $plan_id AND task_id = '$task_id';")
if [[ -n "$actual_data" ]]; then
extracted=$(echo "$actual_data" | jq -r "$output_path" 2>/dev/null || echo "")
if [[ "$extracted" == "$equals_val" ]]; then
met="true"
elif [[ "$final_result" != "SKIP" ]]; then
final_result="BLOCKED"
fi
elif [[ "$final_result" != "SKIP" ]]; then
final_result="BLOCKED"
fi
;;
skip_if)
local task_id output_path equals_val actual_data extracted
task_id=$(echo "$cond" | jq -r '.task_id')
output_path=$(echo "$cond" | jq -r '.output_path')
equals_val=$(echo "$cond" | jq -r '.equals')
actual_data=$(sqlite3 "$DB_FILE" "SELECT output_data FROM tasks WHERE plan_id = $plan_id AND task_id = '$task_id';")
if [[ -n "$actual_data" ]]; then
extracted=$(echo "$actual_data" | jq -r "$output_path" 2>/dev/null || echo "")
if [[ "$extracted" == "$equals_val" ]]; then
met="true"
final_result="SKIP"
fi
fi
;;
*)
if [[ "$final_result" != "SKIP" ]]; then
final_result="BLOCKED"
fi
;;
esac

details=$(echo "$details" | jq --argjson cond "$cond" --argjson met "$met" '. + [{"condition": $cond, "met": $met}]')
done

echo "$details" | jq -c --arg result "$final_result" --arg wave_id "$wave_id" '{"result": $result, "wave_id": $wave_id, "details": .}'
return 0
}
