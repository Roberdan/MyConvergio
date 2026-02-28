#!/bin/bash
# Plan DB Validation - Thor validation dispatcher
# Sourced by plan-db.sh

# Version: 3.0.0

PLAN_DB_VALIDATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plan-db"

source "$PLAN_DB_VALIDATE_DIR/validate-common.sh"
source "$PLAN_DB_VALIDATE_DIR/validate-gates-1-4.sh"
source "$PLAN_DB_VALIDATE_DIR/validate-gate-5-7.sh"
source "$PLAN_DB_VALIDATE_DIR/validate-gate-8.sh"
source "$PLAN_DB_VALIDATE_DIR/validate-gate-9.sh"

cmd_validate() {
local plan_id="$1"
local validated_by="${2:-thor}"

echo -e "${BLUE}======= THOR VALIDATION - Plan $plan_id =======${NC}"
echo ""

local project_id
project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")
: "${project_id:=}"

thor_reset_validation_counters

validate_gate_1_wave_counter_sync "$plan_id"
validate_gate_2_orphan_tasks "$plan_id"
validate_gate_3_incomplete_in_done_waves "$plan_id"
validate_gate_4_plan_counter_sync "$plan_id"
validate_gate_5_date_consistency "$plan_id"
validate_gate_6_executor_agent_tracking "$plan_id"
validate_gate_7_output_data_json_validity "$plan_id"

echo ""
if [[ "$THOR_VALIDATE_ERRORS" -gt 0 ]]; then
echo -e "${RED}FAILED: $THOR_VALIDATE_ERRORS errors, $THOR_VALIDATE_WARNINGS warnings${NC}"
echo -e "${YELLOW}Run 'plan-db.sh sync $plan_id' to fix${NC}"
return 1
fi

sqlite3 "$DB_FILE" "UPDATE plans SET validated_at = datetime('now'), validated_by = '$(sql_escape "$validated_by")' WHERE id = $plan_id;"

local unvalidated_count
unvalidated_count=$(sqlite3 "$DB_FILE" "
SELECT COUNT(*) FROM tasks t
JOIN waves w ON t.wave_id_fk = w.id
WHERE w.plan_id = $plan_id AND t.status = 'done' AND t.validated_at IS NULL;
")
if [[ "$unvalidated_count" -gt 0 ]]; then
log_warn "$unvalidated_count done tasks lack per-task Thor validation — run validate-task for each"
sqlite3 "$DB_FILE" "
SELECT t.task_id, t.title FROM tasks t
JOIN waves w ON t.wave_id_fk = w.id
WHERE w.plan_id = $plan_id AND t.status = 'done' AND t.validated_at IS NULL;
" | while IFS='|' read -r tid title; do
echo "  - $tid: $title"
done
fi

local version
version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
sqlite3 "$DB_FILE" "
INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by, changed_host)
VALUES ($plan_id, $version, 'validated', 'Validated - 0 errors', '$(sql_escape "$validated_by")', '$(sql_escape "${PLAN_DB_HOST:-unknown}")');
"
echo -e "${GREEN}PASSED: Plan $plan_id validated by $validated_by (host: ${PLAN_DB_HOST:-unknown})${NC}"

local tasks_done tasks_total current_status
IFS='|' read -r tasks_done tasks_total current_status < <(sqlite3 "$DB_FILE" "SELECT tasks_done, tasks_total, status FROM plans WHERE id = $plan_id;")
if [[ "$tasks_total" -gt 0 && "$tasks_done" -eq "$tasks_total" && "$current_status" != "done" ]]; then
sqlite3 "$DB_FILE" "UPDATE plans SET status = 'done', completed_at = datetime('now'), execution_host = '$(sql_escape "${PLAN_DB_HOST:-unknown}")' WHERE id = $plan_id;"
echo -e "${GREEN}AUTO-CLOSE: Plan $plan_id marked as done (all $tasks_total tasks complete)${NC}"

local close_version
close_version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
sqlite3 "$DB_FILE" "
INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by, changed_host)
VALUES ($plan_id, $close_version, 'completed', 'Auto-closed after Thor validation', '$(sql_escape "$validated_by")', '$(sql_escape "${PLAN_DB_HOST:-unknown}")');
"
fi

return 0
}
