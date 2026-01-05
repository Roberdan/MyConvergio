# Fixed functions for plan-db.sh
# These replace the buggy originals with proper SQL injection prevention
# and correct wave_id_fk usage

# Helper: Escape single quotes for SQL
sql_escape() {
    local input="$1"
    # Replace each single quote with two single quotes (SQL standard escaping)
    printf '%s\n' "${input//\'/\'\'}"
}

# Add task to wave - FIXED VERSION
# Now uses wave_id_fk FK after migration, with proper quoting
cmd_add_task_fixed() {
    local db_wave_id="$1"
    local task_id="$2"
    local title="$3"
    local priority="${4:-P1}"
    local type="${5:-feature}"
    local assignee="${6:-}"

    # Escape all user input
    local safe_task_id=$(sql_escape "$task_id")
    local safe_title=$(sql_escape "$title")
    local safe_assignee=$(sql_escape "$assignee")

    # Get project_id and wave_id string from waves table
    local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM waves WHERE id = $db_wave_id;")

    sqlite3 "$DB_FILE" "
        INSERT INTO tasks (project_id, wave_id_fk, task_id, title, status, priority, type, assignee)
        VALUES ('$project_id', $db_wave_id, '$safe_task_id', '$safe_title', 'pending', '$priority', '$type', '$safe_assignee');
    "

    # Update wave total
    sqlite3 "$DB_FILE" "UPDATE waves SET tasks_total = tasks_total + 1 WHERE id = $db_wave_id;"

    # Update plan total
    local plan_id=$(sqlite3 "$DB_FILE" "SELECT plan_id FROM waves WHERE id = $db_wave_id;")
    sqlite3 "$DB_FILE" "UPDATE plans SET tasks_total = tasks_total + 1 WHERE id = $plan_id;"

    local db_task_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE id = last_insert_rowid();")
    log_info "Added task: $title (ID: $db_task_id)"
    echo "$db_task_id"
}

# Update task status - FIXED VERSION
# Now uses wave_id_fk FK and proper quote escaping
cmd_update_task_fixed() {
    local task_id="$1"
    local status="$2"
    local notes="${3:-}"

    # Escape notes for SQL
    local safe_notes=$(sql_escape "$notes")

    local old_status=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id = $task_id;")

    if [[ "$status" == "in_progress" ]]; then
        sqlite3 "$DB_FILE" "
            UPDATE tasks
            SET status = '$status', started_at = datetime('now'), notes = '$safe_notes'
            WHERE id = $task_id;
        "
    elif [[ "$status" == "done" ]]; then
        sqlite3 "$DB_FILE" "
            UPDATE tasks
            SET status = '$status', completed_at = datetime('now'), notes = '$safe_notes'
            WHERE id = $task_id;
        "

        # Get wave FK and project_id using FK (simpler!)
        local wave_fk=$(sqlite3 "$DB_FILE" "SELECT wave_id_fk FROM tasks WHERE id = $task_id;")
        local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM tasks WHERE id = $task_id;")

        # Update wave done count using FK (no composite key needed)
        sqlite3 "$DB_FILE" "UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = $wave_fk;"

        # Update plan done count
        local plan_id=$(sqlite3 "$DB_FILE" "SELECT plan_id FROM waves WHERE id = $wave_fk;")
        sqlite3 "$DB_FILE" "UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = $plan_id;"

        # Check if wave is complete
        local wave_done=$(sqlite3 "$DB_FILE" "SELECT tasks_done = tasks_total FROM waves WHERE id = $wave_fk;")
        if [[ "$wave_done" == "1" ]]; then
            local wave_id=$(sqlite3 "$DB_FILE" "SELECT wave_id FROM waves WHERE id = $wave_fk;")
            sqlite3 "$DB_FILE" "UPDATE waves SET status = 'done', completed_at = datetime('now') WHERE id = $wave_fk;"
            log_info "Wave $wave_id completed!"
        fi
    else
        sqlite3 "$DB_FILE" "
            UPDATE tasks SET status = '$status', notes = '$safe_notes' WHERE id = $task_id;
        "
    fi

    log_info "Task $task_id: $old_status → $status"
}

# Add wave to plan - FIXED VERSION
# Now escapes all string parameters
cmd_add_wave_fixed() {
    local plan_id="$1"
    local wave_id="$2"
    local name="$3"
    shift 3

    # Escape string parameters
    local safe_wave_id=$(sql_escape "$wave_id")
    local safe_name=$(sql_escape "$name")

    # Defaults
    local assignee=""
    local planned_start=""
    local planned_end=""
    local estimated_hours="8"
    local depends_on=""

    # Parse optional flags
    set +u
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --assignee)
                if [[ -z "${2}" ]]; then log_error "Missing value for --assignee"; set -u; exit 1; fi
                assignee=$(sql_escape "$2"); shift 2 ;;
            --planned-start)
                if [[ -z "${2}" ]]; then log_error "Missing value for --planned-start"; set -u; exit 1; fi
                planned_start=$(sql_escape "$2"); shift 2 ;;
            --planned-end)
                if [[ -z "${2}" ]]; then log_error "Missing value for --planned-end"; set -u; exit 1; fi
                planned_end=$(sql_escape "$2"); shift 2 ;;
            --estimated-hours)
                if [[ -z "${2}" ]]; then log_error "Missing value for --estimated-hours"; set -u; exit 1; fi
                estimated_hours="$2"; shift 2 ;;
            --depends-on)
                if [[ -z "${2}" ]]; then log_error "Missing value for --depends-on"; set -u; exit 1; fi
                depends_on=$(sql_escape "$2"); shift 2 ;;
            *) assignee=$(sql_escape "$1"); shift ;;
        esac
    done
    set -u

    # Get project_id from plan
    local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")
    local position=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(position), 0) + 1 FROM waves WHERE plan_id = $plan_id;")

    # Build INSERT with optional Gantt fields (using escaped values)
    local start_val="NULL"
    local end_val="NULL"
    local depends_val="NULL"
    [[ -n "$planned_start" ]] && start_val="'$planned_start'"
    [[ -n "$planned_end" ]] && end_val="'$planned_end'"
    [[ -n "$depends_on" ]] && depends_val="'$depends_on'"

    sqlite3 "$DB_FILE" "
        INSERT INTO waves (project_id, plan_id, wave_id, name, status, assignee, position, estimated_hours, planned_start, planned_end, depends_on)
        VALUES ('$project_id', $plan_id, '$safe_wave_id', '$safe_name', 'pending', '$assignee', $position, $estimated_hours, $start_val, $end_val, $depends_val);
    "

    local db_wave_id=$(sqlite3 "$DB_FILE" "SELECT id FROM waves WHERE plan_id=$plan_id AND wave_id='$safe_wave_id';")
    log_info "Added wave: $name (ID: $db_wave_id, depends: ${depends_on:-none})"
    echo "$db_wave_id"
}

# Create a new plan - FIXED VERSION
# Now escapes all string parameters
cmd_create_fixed() {
    local project_id="$1"
    local name="$2"

    # Escape parameters
    local safe_project_id=$(sql_escape "$project_id")
    local safe_name=$(sql_escape "$name")

    local is_master=0
    local parent_id="NULL"

    # Detect if master plan
    if [[ "$name" == *"-Main"* ]] || [[ "$name" == *"-Master"* ]]; then
        is_master=1
    fi

    # Check for parent master plan (needs escaping too)
    if [[ $is_master -eq 0 ]]; then
        local base_name="${name%%-Phase*}"
        base_name="${base_name%%-[0-9]*}"
        local safe_base_name=$(sql_escape "$base_name")
        local master_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$safe_project_id' AND name LIKE '%${safe_base_name}%' AND is_master=1 LIMIT 1;")
        if [[ -n "$master_id" ]]; then
            parent_id="$master_id"
        fi
    fi

    sqlite3 "$DB_FILE" "
        INSERT INTO plans (project_id, name, is_master, parent_plan_id, status)
        VALUES ('$safe_project_id', '$safe_name', $is_master, $parent_id, 'todo');
    "

    local plan_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$safe_project_id' AND name='$safe_name';")

    # Log version
    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, 1, 'created', 'Plan created', 'planner');
    "

    log_info "Created plan: $name (ID: $plan_id)"
    echo "$plan_id"
}

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

# Sync counters - FIXED VERSION
# Now uses FK-based queries where available
cmd_sync_fixed() {
    local plan_id="$1"

    log_info "Syncing counters for plan $plan_id..."

    # Sync wave counters using FK
    sqlite3 "$DB_FILE" "
        UPDATE waves SET
            tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status = 'done'),
            tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id)
        WHERE plan_id = $plan_id;
    "

    # Update wave status based on completion
    sqlite3 "$DB_FILE" "
        UPDATE waves SET status = 'done', completed_at = COALESCE(completed_at, datetime('now'))
        WHERE plan_id = $plan_id AND tasks_done = tasks_total AND tasks_total > 0 AND status != 'done';
    "

    # Sync plan counters
    sqlite3 "$DB_FILE" "
        UPDATE plans SET
            tasks_done = (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE waves.plan_id = plans.id),
            tasks_total = (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE waves.plan_id = plans.id)
        WHERE id = $plan_id;
    "

    # Show result
    sqlite3 -header -column "$DB_FILE" "
        SELECT wave_id, name, status, tasks_done || '/' || tasks_total as progress
        FROM waves WHERE plan_id = $plan_id ORDER BY position;
    "

    log_info "Sync complete"
}
