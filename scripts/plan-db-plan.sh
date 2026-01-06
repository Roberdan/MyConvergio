# Plan management functions for plan-db.sh
# Fixed versions with proper SQL injection prevention

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

