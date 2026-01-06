# Wave management functions for plan-db.sh
# Fixed versions with proper SQL injection prevention

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

