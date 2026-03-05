#!/bin/bash
# Plan-level validation functions

cmd_validate() {
	local plan_id="$1"
	local validated_by="${2:-thor}"
	local errors=0
	local warnings=0

	echo -e "${BLUE}======= THOR VALIDATION - Plan $plan_id =======${NC}"
	echo ""

	local project_id
	project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")

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
	if [ -n "$wave_issues" ]; then
		echo -e "${RED}  ERROR: Wave counters out of sync${NC}"
		echo "$wave_issues"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	echo -e "${YELLOW}[2/7] Orphan tasks...${NC}"
	local orphans
	orphans=$(sqlite3 "$DB_FILE" "
        SELECT t.id, t.task_id, t.wave_id FROM tasks t
        WHERE t.plan_id = $plan_id
        AND NOT EXISTS (SELECT 1 FROM waves w WHERE w.id = t.wave_id_fk);
    ")
	if [ -n "$orphans" ]; then
		echo -e "${RED}  ERROR: Orphan tasks found${NC}"
		echo "$orphans"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	echo -e "${YELLOW}[3/7] Incomplete in done waves...${NC}"
	local incomplete
	incomplete=$(sqlite3 "$DB_FILE" "
        SELECT w.wave_id, t.task_id, t.status FROM tasks t
        JOIN waves w ON t.wave_id_fk = w.id
        WHERE w.plan_id = $plan_id AND w.status = 'done' AND t.status NOT IN ('done', 'cancelled', 'skipped');
    ")
	if [ -n "$incomplete" ]; then
		echo -e "${RED}  ERROR: Incomplete tasks in done waves${NC}"
		echo "$incomplete"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

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
	if [ -n "$plan_totals" ]; then
		echo -e "${RED}  ERROR: Plan counters out of sync${NC}"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	echo -e "${YELLOW}[5/7] Date consistency...${NC}"
	local bad_dates
	bad_dates=$(sqlite3 "$DB_FILE" "
        SELECT wave_id FROM waves WHERE plan_id = $plan_id AND planned_end < planned_start;
    ")
	if [ -n "$bad_dates" ]; then
		echo -e "${YELLOW}  WARNING: Waves with end < start${NC}"
		((warnings++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	echo -e "${YELLOW}[6/7] Executor agent tracking...${NC}"
	local missing_agent
	missing_agent=$(sqlite3 "$DB_FILE" "
	    SELECT COUNT(*) FROM tasks t
	    JOIN waves w ON t.wave_id_fk = w.id
	    WHERE w.plan_id = $plan_id AND t.status = 'done' AND (t.executor_agent IS NULL OR t.executor_agent = '');
	")
	if [ "$missing_agent" -gt 0 ]; then
		echo -e "${YELLOW}  WARNING: $missing_agent done tasks missing executor_agent${NC}"
		((warnings++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

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
			((invalid_json++))
		fi
	done <<<"$tasks_with_output"
	if [ "$invalid_json" -gt 0 ]; then
		echo -e "${RED}  ERROR: $invalid_json tasks with invalid output_data JSON${NC}"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	echo ""
	if [ $errors -gt 0 ]; then
		echo -e "${RED}FAILED: $errors errors, $warnings warnings${NC}"
		echo -e "${YELLOW}Run 'plan-db.sh sync $plan_id' to fix${NC}"
		return 1
	fi

	sqlite3 "$DB_FILE" "UPDATE plans SET validated_at = datetime('now'), validated_by = '$validated_by' WHERE id = $plan_id;"

	local unvalidated_count
	unvalidated_count=$(sqlite3 "$DB_FILE" "
        SELECT COUNT(*) FROM tasks t
        JOIN waves w ON t.wave_id_fk = w.id
        WHERE w.plan_id = $plan_id AND t.status = 'done' AND t.validated_at IS NULL;
    ")
	if [ "$unvalidated_count" -gt 0 ]; then
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
        VALUES ($plan_id, $version, 'validated', 'Validated - 0 errors', '$validated_by', '${PLAN_DB_HOST:-unknown}');
    "
	echo -e "${GREEN}PASSED: Plan $plan_id validated by $validated_by (host: ${PLAN_DB_HOST:-unknown})${NC}"

	local tasks_done tasks_total current_status
	IFS='|' read -r tasks_done tasks_total current_status < <(sqlite3 "$DB_FILE" "SELECT tasks_done, tasks_total, status FROM plans WHERE id = $plan_id;")
	if [[ "$tasks_total" -gt 0 && "$tasks_done" -eq "$tasks_total" && "$current_status" != "done" ]]; then
		sqlite3 "$DB_FILE" "UPDATE plans SET status = 'done', completed_at = datetime('now'), execution_host = '${PLAN_DB_HOST:-unknown}' WHERE id = $plan_id;"
		echo -e "${GREEN}AUTO-CLOSE: Plan $plan_id marked as done (all $tasks_total tasks complete)${NC}"

		local close_version
		close_version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
		sqlite3 "$DB_FILE" "
            INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by, changed_host)
            VALUES ($plan_id, $close_version, 'completed', 'Auto-closed after Thor validation', '$validated_by', '${PLAN_DB_HOST:-unknown}');
        "
	fi

	return 0
}

# Check plan readiness for execution (BLOCKS if metadata missing)
cmd_check_readiness() {
	local plan_id="$1"
	local errors=0
	echo -e "${BLUE}======= READINESS CHECK - Plan $plan_id =======${NC}"

	echo -e "${YELLOW}[0/N] Precondition cycle detection...${NC}"
	if ! detect_precondition_cycles "$plan_id"; then
		echo -e "${RED}  FAIL: Circular dependencies in wave preconditions${NC}"
		errors=$((errors + 1))
	else
		echo -e "${GREEN}  OK: No cycles${NC}"
	fi

	local src wt
	src=$(sqlite3 "$DB_FILE" "SELECT source_file FROM plans WHERE id=$plan_id;")
	wt=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id=$plan_id;")
	if [[ -z "$src" ]]; then
		echo -e "${RED}  FAIL: source_file not set${NC}"
		errors=$((errors + 1))
	else
		echo -e "${GREEN}  OK: source_file${NC}"
	fi
	local wave_wt_count
	wave_wt_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM waves WHERE plan_id=$plan_id AND worktree_path IS NOT NULL AND worktree_path <> '';" 2>/dev/null || echo "0")
	if [[ -z "$wt" && "$wave_wt_count" -eq 0 ]]; then
		echo -e "${RED}  FAIL: No worktree set (plan-level or wave-level). Use wave-worktree.sh create or --auto-worktree${NC}"
		errors=$((errors + 1))
	elif [[ -n "$wt" ]]; then
		echo -e "${GREEN}  OK: plan worktree_path ($wt)${NC}"
	else
		echo -e "${GREEN}  OK: wave-level worktrees ($wave_wt_count waves with worktree)${NC}"
	fi

	local no_desc no_tc
	no_desc=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id AND status='pending' AND (description IS NULL OR description='');")
	no_tc=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id AND status='pending' AND (test_criteria IS NULL OR test_criteria='');")
	if [[ "$no_desc" -gt 0 ]]; then
		echo -e "${RED}  FAIL: $no_desc tasks missing description${NC}"
		errors=$((errors + 1))
	else
		echo -e "${GREEN}  OK: all tasks have description${NC}"
	fi
	if [[ "$no_tc" -gt 0 ]]; then
		echo -e "${RED}  FAIL: $no_tc tasks missing test_criteria${NC}"
		errors=$((errors + 1))
	else
		echo -e "${GREEN}  OK: all tasks have test_criteria${NC}"
	fi

	# ── Planner Process Gates (Rule 14: MANDATORY for 3+ tasks) ──
	local task_count
	task_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id;")
	if [[ "$task_count" -ge 3 ]]; then
		local gate_errors=0
		echo -e "${YELLOW}[P] Planner Process Gates (Rule 14, $task_count tasks)...${NC}"

		local review_count biz_count challenger_count approval_count
		review_count=$(sqlite3 "$DB_FILE" \
			"SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%reviewer%' AND reviewer_agent NOT LIKE '%challenger%';" 2>/dev/null || echo "0")
		biz_count=$(sqlite3 "$DB_FILE" \
			"SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND (reviewer_agent LIKE '%business%' OR reviewer_agent LIKE '%advisor%');" 2>/dev/null || echo "0")
		challenger_count=$(sqlite3 "$DB_FILE" \
			"SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%challenger%';" 2>/dev/null || echo "0")
		approval_count=$(sqlite3 "$DB_FILE" \
			"SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent='user-approval';" 2>/dev/null || echo "0")

		if [[ "$review_count" -eq 0 ]]; then
			echo -e "${RED}  FAIL: No plan-reviewer record. Run Step 3.1 (plan intelligence review).${NC}"
			gate_errors=$((gate_errors + 1))
		else
			local rv
			rv=$(sqlite3 "$DB_FILE" "SELECT verdict FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%reviewer%' AND reviewer_agent NOT LIKE '%challenger%' ORDER BY id DESC LIMIT 1;")
			echo -e "${GREEN}  OK: plan-reviewer (verdict: $rv)${NC}"
		fi
		if [[ "$biz_count" -eq 0 ]]; then
			echo -e "${RED}  FAIL: No business-advisor record. Run Step 3.1 (business assessment).${NC}"
			gate_errors=$((gate_errors + 1))
		else
			echo -e "${GREEN}  OK: plan-business-advisor${NC}"
		fi
		if [[ "$challenger_count" -eq 0 ]]; then
			echo -e "${RED}  FAIL: No challenger-review record. Run Step 3.3 (challenger review).${NC}"
			gate_errors=$((gate_errors + 1))
		else
			local cv
			cv=$(sqlite3 "$DB_FILE" "SELECT verdict FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%challenger%' ORDER BY id DESC LIMIT 1;")
			echo -e "${GREEN}  OK: plan-challenger (verdict: $cv)${NC}"
		fi
		if [[ "$approval_count" -eq 0 ]]; then
			echo -e "${RED}  FAIL: No user-approval record. Run: plan-db.sh approve $plan_id${NC}"
			gate_errors=$((gate_errors + 1))
		else
			echo -e "${GREEN}  OK: user-approval${NC}"
		fi
		errors=$((errors + gate_errors))
	fi

	if [[ $errors -gt 0 ]]; then
		echo -e "${RED}BLOCKED: $errors issues. Fix before /execute.${NC}"
		return 1
	fi
	echo -e "${GREEN}READY: Plan $plan_id is ready for execution${NC}"
	return 0
}

# Sync counters
cmd_sync() {
	local plan_id="$1"
	log_info "Syncing counters for plan $plan_id..."

	sqlite3 "$DB_FILE" "
        UPDATE waves SET
            tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status = 'done'),
            tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id)
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
            tasks_done = (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE waves.plan_id = plans.id),
            tasks_total = (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE waves.plan_id = plans.id)
        WHERE id = $plan_id;
    "
	sqlite3 -header -column "$DB_FILE" "
        SELECT wave_id, name, status, tasks_done || '/' || tasks_total as progress
        FROM waves WHERE plan_id = $plan_id ORDER BY position;
    "
	log_info "Sync complete"
}
