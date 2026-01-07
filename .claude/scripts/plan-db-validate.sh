# Plan validation functions for plan-db.sh
# Fixed versions with proper SQL injection prevention

# Validate plan - FIXED VERSION
# Now escapes validated_by parameter
cmd_validate_fixed() {
    local plan_id="$1"
    local validated_by="${2:-thor}"

    # Escape parameters
    local safe_validated_by=$(sql_escape "$validated_by")

    local errors=0
    local warnings=0

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}           THOR VALIDATION - Plan $plan_id                      ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Get project_id for this plan
    local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")

    # Check 1: Counter sync - waves (updated query to use FK-based logic where possible)
    echo -e "${YELLOW}[1/5] Checking wave counter sync...${NC}"
    local wave_issues=$(sqlite3 "$DB_FILE" "
        SELECT w.wave_id, w.tasks_done, w.tasks_total,
               (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done') as actual_done,
               (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id) as actual_total
        FROM waves w WHERE w.plan_id = $plan_id
        AND (w.tasks_done != (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done')
             OR w.tasks_total != (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id));
    ")
    if [ -n "$wave_issues" ]; then
        echo -e "${RED}  ERROR: Wave counters out of sync:${NC}"
        echo "$wave_issues"
        ((errors++))
    else
        echo -e "${GREEN}  OK: All wave counters synced${NC}"
    fi

    # Check 2: Orphan tasks - now checks FK
    echo -e "${YELLOW}[2/5] Checking for orphan tasks...${NC}"
    local orphans=$(sqlite3 "$DB_FILE" "
        SELECT t.id, t.task_id, t.wave_id_fk FROM tasks t
        WHERE t.project_id = '$project_id'
        AND (t.wave_id_fk IS NULL OR NOT EXISTS (SELECT 1 FROM waves w WHERE w.id = t.wave_id_fk AND w.plan_id = $plan_id));
    ")
    if [ -n "$orphans" ]; then
        echo -e "${RED}  ERROR: Orphan tasks found (no valid wave):${NC}"
        echo "$orphans"
        ((errors++))
    else
        echo -e "${GREEN}  OK: No orphan tasks${NC}"
    fi

    # Check 3: Incomplete tasks in done waves
    echo -e "${YELLOW}[3/5] Checking for incomplete tasks in done waves...${NC}"
    local incomplete=$(sqlite3 "$DB_FILE" "
        SELECT w.wave_id, t.task_id, t.status FROM tasks t
        JOIN waves w ON t.wave_id_fk = w.id
        WHERE w.plan_id = $plan_id AND w.status = 'done' AND t.status != 'done';
    ")
    if [ -n "$incomplete" ]; then
        echo -e "${RED}  ERROR: Incomplete tasks in waves marked done:${NC}"
        echo "$incomplete"
        ((errors++))
    else
        echo -e "${GREEN}  OK: All tasks in done waves are complete${NC}"
    fi

    # Check 4: Plan counter sync
    echo -e "${YELLOW}[4/5] Checking plan counter sync...${NC}"
    local plan_totals=$(sqlite3 "$DB_FILE" "
        SELECT p.tasks_done, p.tasks_total,
               (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE plan_id = p.id) as actual_done,
               (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE plan_id = p.id) as actual_total
        FROM plans p WHERE p.id = $plan_id
        AND (p.tasks_done != (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE plan_id = p.id)
             OR p.tasks_total != (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE plan_id = p.id));
    ")
    if [ -n "$plan_totals" ]; then
        echo -e "${RED}  ERROR: Plan counters out of sync:${NC}"
        echo "$plan_totals"
        ((errors++))
    else
        echo -e "${GREEN}  OK: Plan counters synced${NC}"
    fi

    # Check 5: Sensible dates
    echo -e "${YELLOW}[5/5] Checking date consistency...${NC}"
    local bad_dates=$(sqlite3 "$DB_FILE" "
        SELECT wave_id, planned_start, planned_end FROM waves
        WHERE plan_id = $plan_id AND planned_end < planned_start;
    ")
    if [ -n "$bad_dates" ]; then
        echo -e "${YELLOW}  WARNING: Waves with end before start:${NC}"
        echo "$bad_dates"
        ((warnings++))
    else
        echo -e "${GREEN}  OK: All dates consistent${NC}"
    fi

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

    if [ $errors -gt 0 ]; then
        echo -e "${RED}VALIDATION FAILED: $errors errors, $warnings warnings${NC}"
        echo -e "${YELLOW}Run 'plan-db.sh sync $plan_id' to fix counter issues${NC}"
        return 1
    fi

    # All checks passed - mark as validated
    sqlite3 "$DB_FILE" "
        UPDATE plans
        SET validated_at = datetime('now'), validated_by = '$safe_validated_by'
        WHERE id = $plan_id;
    "

    local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, $version, 'validated', 'Validated by $safe_validated_by - 0 errors', '$safe_validated_by');
    "

    echo -e "${GREEN}VALIDATION PASSED: Plan $plan_id validated by $validated_by${NC}"
    return 0
}

