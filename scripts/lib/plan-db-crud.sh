#!/bin/bash
# Plan DB CRUD - Create, Read, Update operations
# Sourced by plan-db.sh

# Dashboard API base URL
DASHBOARD_API="${DASHBOARD_API:-http://localhost:31415}"

# Send notification to dashboard (non-blocking)
send_notification() {
    local project_id="$1"
    local type="$2"
    local severity="$3"
    local title="$4"
    local message="${5:-}"
    local source_table="${6:-}"
    local source_id="${7:-}"

    # Fire and forget - don't block on notification failure
    curl -s -X POST "$DASHBOARD_API/api/notifications" \
        -H "Content-Type: application/json" \
        -d "{\"project_id\":\"$project_id\",\"type\":\"$type\",\"severity\":\"$severity\",\"title\":\"$title\",\"message\":\"$message\",\"source_table\":\"$source_table\",\"source_id\":\"$source_id\"}" \
        >/dev/null 2>&1 &
}

# List plans for a project
cmd_list() {
    local project_id="$1"
    echo -e "${BLUE}Plans for project: ${project_id}${NC}"
    echo ""
    sqlite3 -header -column "$DB_FILE" "
        SELECT id, name,
            CASE WHEN is_master THEN 'MASTER' ELSE '' END as type,
            status, tasks_done || '/' || tasks_total as progress
        FROM plans WHERE project_id = '$project_id'
        ORDER BY is_master DESC, status, name;
    "
}

# Create a new plan
cmd_create() {
    local project_id="$1"
    local name="$2"
    local is_master=0
    local parent_id="NULL"

    local safe_project_id="$(sql_escape "$project_id")"
    local safe_name="$(sql_escape "$name")"

    [[ "$name" == *"-Main"* ]] || [[ "$name" == *"-Master"* ]] && is_master=1

    if [[ $is_master -eq 0 ]]; then
        local base_name="${name%%-Phase*}"
        base_name="${base_name%%-[0-9]*}"
        local master_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$safe_project_id' AND name LIKE '$(sql_escape "$base_name")%' AND is_master=1 LIMIT 1;")
        [[ -n "$master_id" ]] && parent_id="$master_id"
    fi

    sqlite3 "$DB_FILE" "
        INSERT INTO plans (project_id, name, is_master, parent_plan_id, status)
        VALUES ('$safe_project_id', '$safe_name', $is_master, $parent_id, 'todo');
    "
    local plan_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$safe_project_id' AND name='$safe_name';")

    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, 1, 'created', 'Plan created', 'planner');
    "
    log_info "Created plan: $name (ID: $plan_id)"
    echo "$plan_id"
}

# Start a plan
cmd_start() {
    local plan_id="$1"

    # Get plan info for notifications
    local plan_info=$(sqlite3 "$DB_FILE" "SELECT project_id, name FROM plans WHERE id = $plan_id;")
    local project_id=$(echo "$plan_info" | cut -d'|' -f1)
    local plan_name=$(echo "$plan_info" | cut -d'|' -f2)

    sqlite3 "$DB_FILE" "
        UPDATE plans SET status = 'doing', started_at = datetime('now')
        WHERE id = $plan_id;
    "
    local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, $version, 'started', 'Execution started', 'planner');
    "

    send_notification "$project_id" "plan_started" "info" "Plan Started: $plan_name" "Execution is now IN FLIGHT" "plans" "$plan_id"
    log_info "Started plan ID: $plan_id"
}

# Add wave to plan
cmd_add_wave() {
    local plan_id="$1"
    local wave_id="$2"
    local name="$3"
    shift 3

    local assignee="" planned_start="" planned_end="" estimated_hours="8" depends_on=""

    set +u
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --assignee) [[ -z "${2}" ]] && { log_error "Missing --assignee value"; set -u; exit 1; }; assignee="$2"; shift 2 ;;
            --planned-start) [[ -z "${2}" ]] && { log_error "Missing --planned-start value"; set -u; exit 1; }; planned_start="$2"; shift 2 ;;
            --planned-end) [[ -z "${2}" ]] && { log_error "Missing --planned-end value"; set -u; exit 1; }; planned_end="$2"; shift 2 ;;
            --estimated-hours) [[ -z "${2}" ]] && { log_error "Missing --estimated-hours value"; set -u; exit 1; }; estimated_hours="$2"; shift 2 ;;
            --depends-on) [[ -z "${2}" ]] && { log_error "Missing --depends-on value"; set -u; exit 1; }; depends_on="$2"; shift 2 ;;
            *) assignee="$1"; shift ;;
        esac
    done
    set -u

    local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")
    local position=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(position), 0) + 1 FROM waves WHERE plan_id = $plan_id;")

    local safe_planned_start="$(sql_escape "$planned_start")"
    local safe_planned_end="$(sql_escape "$planned_end")"
    local safe_depends_val="$(sql_escape "$depends_on")"

    local start_val="NULL" end_val="NULL" depends_val="NULL"
    [[ -n "$planned_start" ]] && start_val="'$safe_planned_start'"
    [[ -n "$planned_end" ]] && end_val="'$safe_planned_end'"
    [[ -n "$depends_on" ]] && depends_val="'$safe_depends_val'"

    local safe_wave_id="$(sql_escape "$wave_id")"
    local safe_name="$(sql_escape "$name")"
    local safe_assignee="$(sql_escape "$assignee")"
    sqlite3 "$DB_FILE" "
        INSERT INTO waves (project_id, plan_id, wave_id, name, status, assignee, position, estimated_hours, planned_start, planned_end, depends_on)
        VALUES ('$project_id', $plan_id, '$safe_wave_id', '$safe_name', 'pending', '$safe_assignee', $position, $estimated_hours, $start_val, $end_val, $depends_val);
    "
    local db_wave_id=$(sqlite3 "$DB_FILE" "SELECT id FROM waves WHERE plan_id=$plan_id AND wave_id='$safe_wave_id';")
    log_info "Added wave: $name (ID: $db_wave_id)"
    echo "$db_wave_id"
}

# Add task to wave
cmd_add_task() {
    local db_wave_id="$1"
    local task_id="$2"
    local title="$3"
    local priority="${4:-P1}"
    local type="${5:-feature}"
    local assignee="${6:-}"

    local wave_info=$(sqlite3 "$DB_FILE" "SELECT project_id, wave_id, plan_id FROM waves WHERE id = $db_wave_id;")
    local project_id=$(echo "$wave_info" | cut -d'|' -f1)
    local wave_id_text=$(echo "$wave_info" | cut -d'|' -f2)
    local plan_id=$(echo "$wave_info" | cut -d'|' -f3)

    local safe_task_id="$(sql_escape "$task_id")"
    local safe_title="$(sql_escape "$title")"
    local safe_priority="$(sql_escape "$priority")"
    local safe_type="$(sql_escape "$type")"
    local safe_assignee="$(sql_escape "$assignee")"

    sqlite3 "$DB_FILE" "
        INSERT INTO tasks (project_id, wave_id, wave_id_fk, plan_id, task_id, title, status, priority, type, assignee)
        VALUES ('$project_id', '$wave_id_text', $db_wave_id, $plan_id, '$safe_task_id', '$safe_title', 'pending', '$safe_priority', '$safe_type', '$safe_assignee');
    "
    sqlite3 "$DB_FILE" "UPDATE waves SET tasks_total = tasks_total + 1 WHERE id = $db_wave_id;"

    sqlite3 "$DB_FILE" "UPDATE plans SET tasks_total = tasks_total + 1 WHERE id = $plan_id;"

    local db_task_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE id = last_insert_rowid();")
    log_info "Added task: $title (ID: $db_task_id)"
    echo "$db_task_id"
}

# Update task status
# Usage: update-task <task_id> <status> [notes] [--tokens N]
cmd_update_task() {
    local task_id="$1"
    local status="$2"
    shift 2

    local notes="" tokens=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tokens) tokens="$2"; shift 2 ;;
            *) [[ -z "$notes" ]] && notes="$1"; shift ;;
        esac
    done

    local notes_escaped=$(sql_escape "$notes")

    case "$status" in
        pending|in_progress|done|blocked|skipped) ;;
        *) log_error "Invalid status: $status"; exit 1 ;;
    esac

    # Get task info
    local task_info=$(sqlite3 "$DB_FILE" "SELECT project_id, task_id, title, plan_id, wave_id_fk, status FROM tasks WHERE id = $task_id;")
    local project_id=$(echo "$task_info" | cut -d'|' -f1)
    local task_code=$(echo "$task_info" | cut -d'|' -f2)
    local task_title=$(echo "$task_info" | cut -d'|' -f3)
    local plan_id=$(echo "$task_info" | cut -d'|' -f4)
    local wave_fk=$(echo "$task_info" | cut -d'|' -f5)
    local old_status=$(echo "$task_info" | cut -d'|' -f6)

    # Skip if status unchanged
    [[ "$old_status" == "$status" ]] && { log_info "Task $task_id already $status"; return 0; }

    local tokens_sql=""
    [[ -n "$tokens" ]] && tokens_sql=", tokens = $tokens"

    # Determine counter changes based on status transition
    local was_done=0 will_be_done=0
    [[ "$old_status" == "done" ]] && was_done=1
    [[ "$status" == "done" ]] && will_be_done=1

    # Update task status
    if [[ "$status" == "in_progress" ]]; then
        sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', started_at = COALESCE(started_at, datetime('now')), notes = '$notes_escaped'$tokens_sql WHERE id = $task_id;"
        send_notification "$project_id" "task_started" "info" "Task Started: $task_code" "$task_title" "tasks" "$task_id"
    elif [[ "$status" == "done" ]]; then
        sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', completed_at = datetime('now'), notes = '$notes_escaped'$tokens_sql WHERE id = $task_id;"
        send_notification "$project_id" "task_completed" "success" "Task Completed: $task_code" "$task_title" "tasks" "$task_id"
    elif [[ "$status" == "blocked" ]]; then
        sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', notes = '$notes_escaped'$tokens_sql WHERE id = $task_id;"
        send_notification "$project_id" "task_blocked" "warning" "Task Blocked: $task_code" "$notes" "tasks" "$task_id"
    else
        sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', notes = '$notes_escaped'$tokens_sql WHERE id = $task_id;"
    fi

    # Update counters only on actual done-status transitions
    if [[ $was_done -eq 0 && $will_be_done -eq 1 ]]; then
        # Transitioning TO done: increment counters
        sqlite3 "$DB_FILE" "UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = $wave_fk;"
        sqlite3 "$DB_FILE" "UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = $plan_id;"
    elif [[ $was_done -eq 1 && $will_be_done -eq 0 ]]; then
        # Transitioning FROM done: decrement counters
        sqlite3 "$DB_FILE" "UPDATE waves SET tasks_done = MAX(0, tasks_done - 1) WHERE id = $wave_fk;"
        sqlite3 "$DB_FILE" "UPDATE plans SET tasks_done = MAX(0, tasks_done - 1) WHERE id = $plan_id;"
    fi

    # Check and update wave completion status
    _update_wave_completion "$wave_fk" "$project_id"

    # Check and update plan completion status
    _update_plan_completion "$plan_id" "$project_id"

    [[ -n "$tokens" ]] && log_info "Task $task_id: $old_status -> $status (tokens: $tokens)" || log_info "Task $task_id: $old_status -> $status"
}

# Helper: Update wave completion status based on actual task counts
_update_wave_completion() {
    local wave_fk="$1"
    local project_id="$2"

    local wave_info=$(sqlite3 "$DB_FILE" "SELECT wave_id, status, tasks_done, tasks_total FROM waves WHERE id = $wave_fk;")
    local wave_id_text=$(echo "$wave_info" | cut -d'|' -f1)
    local wave_status=$(echo "$wave_info" | cut -d'|' -f2)
    local tasks_done=$(echo "$wave_info" | cut -d'|' -f3)
    local tasks_total=$(echo "$wave_info" | cut -d'|' -f4)

    if [[ "$tasks_done" -eq "$tasks_total" && "$tasks_total" -gt 0 && "$wave_status" != "done" ]]; then
        sqlite3 "$DB_FILE" "UPDATE waves SET status = 'done', completed_at = datetime('now') WHERE id = $wave_fk;"
        send_notification "$project_id" "wave_completed" "success" "Wave Completed: $wave_id_text" "All tasks completed" "waves" "$wave_fk"
        log_info "Wave $wave_id_text completed!"
    elif [[ "$tasks_done" -lt "$tasks_total" && "$wave_status" == "done" ]]; then
        # Wave was done but now has incomplete tasks - reopen it
        sqlite3 "$DB_FILE" "UPDATE waves SET status = 'in_progress', completed_at = NULL WHERE id = $wave_fk;"
        log_info "Wave $wave_id_text reopened (incomplete tasks)"
    fi
}

# Helper: Update plan completion status based on wave statuses
_update_plan_completion() {
    local plan_id="$1"
    local project_id="$2"

    local plan_info=$(sqlite3 "$DB_FILE" "SELECT name, status, tasks_done, tasks_total FROM plans WHERE id = $plan_id;")
    local plan_name=$(echo "$plan_info" | cut -d'|' -f1)
    local plan_status=$(echo "$plan_info" | cut -d'|' -f2)
    local tasks_done=$(echo "$plan_info" | cut -d'|' -f3)
    local tasks_total=$(echo "$plan_info" | cut -d'|' -f4)

    # Check if all waves are done
    local incomplete_waves=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM waves WHERE plan_id = $plan_id AND status NOT IN ('done', 'skipped');")

    if [[ "$incomplete_waves" -eq 0 && "$tasks_total" -gt 0 && "$plan_status" != "done" ]]; then
        sqlite3 "$DB_FILE" "UPDATE plans SET status = 'done', completed_at = datetime('now') WHERE id = $plan_id;"
        send_notification "$project_id" "plan_completed" "success" "Plan Completed: $plan_name" "All waves and tasks completed" "plans" "$plan_id"
        log_info "Plan $plan_name completed!"
    elif [[ "$incomplete_waves" -gt 0 && "$plan_status" == "done" ]]; then
        # Plan was done but now has incomplete waves - reopen it
        sqlite3 "$DB_FILE" "UPDATE plans SET status = 'doing', completed_at = NULL WHERE id = $plan_id;"
        log_info "Plan $plan_name reopened (incomplete waves)"
    fi
}

# Update wave status
cmd_update_wave() {
    local wave_id="$1"
    local status="$2"

    # Get wave info for notifications
    local wave_info=$(sqlite3 "$DB_FILE" "SELECT project_id, wave_id, name, plan_id, status FROM waves WHERE id = $wave_id;")
    local project_id=$(echo "$wave_info" | cut -d'|' -f1)
    local wave_code=$(echo "$wave_info" | cut -d'|' -f2)
    local wave_name=$(echo "$wave_info" | cut -d'|' -f3)
    local plan_id=$(echo "$wave_info" | cut -d'|' -f4)
    local old_status=$(echo "$wave_info" | cut -d'|' -f5)

    # Skip if status unchanged
    [[ "$old_status" == "$status" ]] && { log_info "Wave $wave_id already $status"; return 0; }

    if [[ "$status" == "in_progress" ]]; then
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', started_at = COALESCE(started_at, datetime('now')) WHERE id = $wave_id;"
        send_notification "$project_id" "wave_started" "info" "Wave Started: $wave_code" "$wave_name" "waves" "$wave_id"
    elif [[ "$status" == "done" ]]; then
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', completed_at = datetime('now') WHERE id = $wave_id;"
        send_notification "$project_id" "wave_completed" "success" "Wave Completed: $wave_code" "$wave_name" "waves" "$wave_id"
    elif [[ "$status" == "blocked" ]]; then
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status' WHERE id = $wave_id;"
        send_notification "$project_id" "wave_blocked" "warning" "Wave Blocked: $wave_code" "$wave_name" "waves" "$wave_id"
    else
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status' WHERE id = $wave_id;"
    fi

    # Update plan completion status after wave change
    _update_plan_completion "$plan_id" "$project_id"

    log_info "Wave $wave_id: $old_status -> $status"
}

# Complete plan
cmd_complete() {
    local plan_id="$1"

    # Get plan info for notifications
    local plan_info=$(sqlite3 "$DB_FILE" "SELECT project_id, name FROM plans WHERE id = $plan_id;")
    local project_id=$(echo "$plan_info" | cut -d'|' -f1)
    local plan_name=$(echo "$plan_info" | cut -d'|' -f2)

    sqlite3 "$DB_FILE" "UPDATE plans SET status = 'done', completed_at = datetime('now') WHERE id = $plan_id;"

    local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, $version, 'completed', 'Plan completed', 'executor');
    "

    send_notification "$project_id" "plan_completed" "success" "Plan Completed: $plan_name" "All waves and tasks completed" "plans" "$plan_id"
    log_info "Plan $plan_id completed!"
}
