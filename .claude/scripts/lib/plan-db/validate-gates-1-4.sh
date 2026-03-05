#!/bin/bash
# Plan DB Validation - Gates 1-4 (code/data integrity)
# Sourced by lib/plan-db-validate.sh

# Version: 1.0.0

validate_gate_1_wave_counter_sync() {
local plan_id="$1"
echo -e "${YELLOW}[1/7] Wave counter sync...${NC}"
local wave_issues
wave_issues=$(sqlite3 "$DB_FILE" "
SELECT w.wave_id, w.tasks_done, w.tasks_total,
       (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done') as actual_done,
       (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id) as actual_total
FROM waves w WHERE w.plan_id = $plan_id
AND (w.tasks_done != (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done')
     OR w.tasks_total != (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id));
")
if [[ -n "$wave_issues" ]]; then
echo -e "${RED}  ERROR: Wave counters out of sync${NC}"
echo "$wave_issues"
thor_add_validation_error
else
echo -e "${GREEN}  OK${NC}"
fi
}

validate_gate_2_orphan_tasks() {
local plan_id="$1"
echo -e "${YELLOW}[2/7] Orphan tasks...${NC}"
local orphans
orphans=$(sqlite3 "$DB_FILE" "
SELECT t.id, t.task_id, t.wave_id FROM tasks t
WHERE t.plan_id = $plan_id
AND NOT EXISTS (SELECT 1 FROM waves w WHERE w.id = t.wave_id_fk);
")
if [[ -n "$orphans" ]]; then
echo -e "${RED}  ERROR: Orphan tasks found${NC}"
echo "$orphans"
thor_add_validation_error
else
echo -e "${GREEN}  OK${NC}"
fi
}

validate_gate_3_incomplete_in_done_waves() {
local plan_id="$1"
echo -e "${YELLOW}[3/7] Incomplete in done waves...${NC}"
local incomplete
incomplete=$(sqlite3 "$DB_FILE" "
SELECT w.wave_id, t.task_id, t.status FROM tasks t
JOIN waves w ON t.wave_id_fk = w.id
WHERE w.plan_id = $plan_id AND w.status = 'done' AND t.status NOT IN ('done', 'cancelled', 'skipped');
")
if [[ -n "$incomplete" ]]; then
echo -e "${RED}  ERROR: Incomplete tasks in done waves${NC}"
echo "$incomplete"
thor_add_validation_error
else
echo -e "${GREEN}  OK${NC}"
fi
}

validate_gate_4_plan_counter_sync() {
local plan_id="$1"
echo -e "${YELLOW}[4/7] Plan counter sync...${NC}"
local plan_totals
plan_totals=$(sqlite3 "$DB_FILE" "
SELECT p.tasks_done, p.tasks_total,
       (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE plan_id = p.id) as actual_done,
       (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE plan_id = p.id) as actual_total
FROM plans p WHERE p.id = $plan_id
AND (p.tasks_done != (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE plan_id = p.id)
     OR p.tasks_total != (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE plan_id = p.id));
")
if [[ -n "$plan_totals" ]]; then
echo -e "${RED}  ERROR: Plan counters out of sync${NC}"
thor_add_validation_error
else
echo -e "${GREEN}  OK${NC}"
fi
}
