# Task management functions for plan-db.sh
# Fixed versions with proper SQL injection prevention

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

