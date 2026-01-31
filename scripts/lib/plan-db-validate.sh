#!/bin/bash
# Plan DB Validation - Thor validation functions
# Sourced by plan-db.sh

# Thor validates plan - ACTUAL validation checks
cmd_validate() {
	local plan_id="$1"
	local validated_by="${2:-thor}"
	local errors=0
	local warnings=0

	echo -e "${BLUE}======= THOR VALIDATION - Plan $plan_id =======${NC}"
	echo ""

	local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")

	# Check 1: Counter sync - waves
	echo -e "${YELLOW}[1/5] Wave counter sync...${NC}"
	local wave_issues=$(sqlite3 "$DB_FILE" "
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

	# Check 2: Orphan tasks
	echo -e "${YELLOW}[2/5] Orphan tasks...${NC}"
	local orphans=$(sqlite3 "$DB_FILE" "
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

	# Check 3: Incomplete tasks in done waves
	echo -e "${YELLOW}[3/5] Incomplete in done waves...${NC}"
	local incomplete=$(sqlite3 "$DB_FILE" "
        SELECT w.wave_id, t.task_id, t.status FROM tasks t
        JOIN waves w ON t.wave_id_fk = w.id
        WHERE w.plan_id = $plan_id AND w.status = 'done' AND t.status != 'done';
    ")
	if [ -n "$incomplete" ]; then
		echo -e "${RED}  ERROR: Incomplete tasks in done waves${NC}"
		echo "$incomplete"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	# Check 4: Plan counter sync
	echo -e "${YELLOW}[4/5] Plan counter sync...${NC}"
	local plan_totals=$(sqlite3 "$DB_FILE" "
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

	# Check 5: Date consistency
	echo -e "${YELLOW}[5/5] Date consistency...${NC}"
	local bad_dates=$(sqlite3 "$DB_FILE" "
        SELECT wave_id FROM waves WHERE plan_id = $plan_id AND planned_end < planned_start;
    ")
	if [ -n "$bad_dates" ]; then
		echo -e "${YELLOW}  WARNING: Waves with end < start${NC}"
		((warnings++))
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

	# Also mark all done tasks as validated
	local done_tasks=$(sqlite3 "$DB_FILE" "
        SELECT t.id FROM tasks t
        JOIN waves w ON t.wave_id_fk = w.id
        WHERE w.plan_id = $plan_id AND t.status = 'done' AND t.validated_at IS NULL;
    ")
	if [ -n "$done_tasks" ]; then
		sqlite3 "$DB_FILE" "
            UPDATE tasks SET validated_at = datetime('now'), validated_by = '$validated_by'
            WHERE id IN (
                SELECT t.id FROM tasks t
                JOIN waves w ON t.wave_id_fk = w.id
                WHERE w.plan_id = $plan_id AND t.status = 'done'
            );
        "
		local count=$(echo "$done_tasks" | grep -c . || echo 0)
		echo -e "${GREEN}Marked $count tasks as validated${NC}"
	fi

	local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
	sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, $version, 'validated', 'Validated - 0 errors', '$validated_by');
    "
	echo -e "${GREEN}PASSED: Plan $plan_id validated by $validated_by${NC}"

	# Auto-close plan if all tasks are done
	local tasks_done=$(sqlite3 "$DB_FILE" "SELECT tasks_done FROM plans WHERE id = $plan_id;")
	local tasks_total=$(sqlite3 "$DB_FILE" "SELECT tasks_total FROM plans WHERE id = $plan_id;")
	local current_status=$(sqlite3 "$DB_FILE" "SELECT status FROM plans WHERE id = $plan_id;")

	if [[ "$tasks_total" -gt 0 && "$tasks_done" -eq "$tasks_total" && "$current_status" != "done" ]]; then
		sqlite3 "$DB_FILE" "UPDATE plans SET status = 'done', completed_at = datetime('now') WHERE id = $plan_id;"
		echo -e "${GREEN}AUTO-CLOSE: Plan $plan_id marked as done (all $tasks_total tasks complete)${NC}"

		# Record auto-close in version history
		local close_version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
		sqlite3 "$DB_FILE" "
            INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
            VALUES ($plan_id, $close_version, 'closed', 'Auto-closed after Thor validation', '$validated_by');
        "
	fi

	return 0
}

# Validate F-xx requirements from plan markdown
cmd_validate_fxx() {
	local plan_id="$1"
	local verified=0
	local pending=0

	echo -e "${BLUE}======= F-xx VALIDATION - Plan $plan_id =======${NC}"
	echo ""

	# Try markdown_path first (exact file), fallback to markdown_dir search
	local plan_file=$(sqlite3 "$DB_FILE" "SELECT markdown_path FROM plans WHERE id = $plan_id;")
	local plan_name=$(sqlite3 "$DB_FILE" "SELECT name FROM plans WHERE id = $plan_id;")

	if [[ -z "$plan_file" || ! -f "$plan_file" ]]; then
		local markdown_dir=$(sqlite3 "$DB_FILE" "SELECT markdown_dir FROM plans WHERE id = $plan_id;")
		[[ -z "$markdown_dir" ]] && markdown_dir="$HOME/.claude/plans/active/${plan_name}"
		plan_file=""
		for f in "$markdown_dir/plan.md" "$markdown_dir/${plan_name}.md" "$markdown_dir"/*.md; do
			[[ -f "$f" ]] && {
				plan_file="$f"
				break
			}
		done
	fi

	if [[ -z "$plan_file" || ! -f "$plan_file" ]]; then
		log_error "Plan markdown not found. Set markdown_path: plan-db.sh create ... --markdown-path <file>"
		return 1
	fi

	echo -e "${GREEN}File: $plan_file${NC}"
	echo ""

	while IFS= read -r line; do
		if [[ "$line" =~ \|[[:space:]]*(F-[0-9]+)[[:space:]]*\| ]]; then
			local fxx="${BASH_REMATCH[1]}"
			local req_text=$(echo "$line" | sed 's/.*F-[0-9]*[[:space:]]*|[[:space:]]*\([^|]*\).*/\1/' | head -c 40)

			if [[ "$line" =~ \[x\] ]] || [[ "$line" =~ \[X\] ]]; then
				echo -e "  ${GREEN}[x]${NC} $fxx - ${req_text}..."
				((verified++))
			elif [[ "$line" =~ \[[[:space:]]*\] ]]; then
				echo -e "  ${RED}[ ]${NC} $fxx - ${req_text}..."
				((pending++))
			fi
		fi
	done <"$plan_file"

	echo ""
	echo -e "Verified: ${GREEN}$verified${NC} | Pending: ${RED}$pending${NC}"

	[[ $pending -gt 0 ]] && {
		echo -e "${RED}FAILED: $pending not verified${NC}"
		return 1
	}
	[[ $verified -eq 0 ]] && {
		echo -e "${YELLOW}WARNING: No F-xx found${NC}"
		return 0
	}

	echo -e "${GREEN}PASSED: All $verified verified${NC}"
	return 0
}

# Check plan readiness for execution (BLOCKS if metadata missing)
cmd_check_readiness() {
	local plan_id="$1"
	local errors=0
	echo -e "${BLUE}======= READINESS CHECK - Plan $plan_id =======${NC}"
	local src=$(sqlite3 "$DB_FILE" "SELECT source_file FROM plans WHERE id=$plan_id;")
	local wt=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id=$plan_id;")
	if [[ -z "$src" ]]; then
		echo -e "${RED}  FAIL: source_file not set${NC}"
		errors=$((errors + 1))
	else echo -e "${GREEN}  OK: source_file${NC}"; fi
	if [[ -z "$wt" ]]; then
		echo -e "${RED}  FAIL: worktree_path not set (run /planner to create worktree)${NC}"
		errors=$((errors + 1))
	else echo -e "${GREEN}  OK: worktree_path ($wt)${NC}"; fi
	local no_desc=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id AND status='pending' AND (description IS NULL OR description='');")
	local no_tc=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id AND status='pending' AND (test_criteria IS NULL OR test_criteria='');")
	if [[ "$no_desc" -gt 0 ]]; then
		echo -e "${RED}  FAIL: $no_desc tasks missing description${NC}"
		errors=$((errors + 1))
	else echo -e "${GREEN}  OK: all tasks have description${NC}"; fi
	if [[ "$no_tc" -gt 0 ]]; then
		echo -e "${RED}  FAIL: $no_tc tasks missing test_criteria${NC}"
		errors=$((errors + 1))
	else echo -e "${GREEN}  OK: all tasks have test_criteria${NC}"; fi
	[[ $errors -gt 0 ]] && {
		echo -e "${RED}BLOCKED: $errors issues. Fix before /execute.${NC}"
		return 1
	}
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
        WHERE plan_id = $plan_id AND tasks_done = tasks_total AND tasks_total > 0 AND status != 'done';
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
