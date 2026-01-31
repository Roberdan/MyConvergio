#!/bin/bash
# Plan DB CRUD - Create, Read, Update operations
# Sourced by plan-db.sh

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
# Usage: create <project_id> <name> [--source-file path] [--markdown-path path] [--worktree-path path]
cmd_create() {
    local project_id="$1"
    local name="$2"
    shift 2
    local is_master=0
    local parent_id="NULL"
    local source_file="" markdown_path="" worktree_path=""

    set +u
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source-file) source_file="$2"; shift 2 ;;
            --markdown-path) markdown_path="$2"; shift 2 ;;
            --worktree-path) worktree_path="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    set -u

    local safe_project_id="$(sql_escape "$project_id")"
    local safe_name="$(sql_escape "$name")"

    [[ "$name" == *"-Main"* ]] || [[ "$name" == *"-Master"* ]] && is_master=1

    if [[ $is_master -eq 0 ]]; then
        local base_name="${name%%-Phase*}"
        base_name="${base_name%%-[0-9]*}"
        local master_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$safe_project_id' AND name LIKE '$(sql_escape "$base_name")%' AND is_master=1 LIMIT 1;")
        [[ -n "$master_id" ]] && parent_id="$master_id"
    fi

    local sf_val="NULL" mp_val="NULL" md_val="NULL" wp_val="NULL"
    if [[ -n "$source_file" ]]; then
        sf_val="'$(sql_escape "$source_file")'"
    fi
    if [[ -n "$markdown_path" ]]; then
        mp_val="'$(sql_escape "$markdown_path")'"
        md_val="'$(sql_escape "$(dirname "$markdown_path")")'"
    fi
    if [[ -n "$worktree_path" ]]; then
        wp_val="'$(sql_escape "$worktree_path")'"
    fi

    sqlite3 "$DB_FILE" "
        INSERT INTO plans (project_id, name, is_master, parent_plan_id, status, source_file, markdown_path, markdown_dir, worktree_path)
        VALUES ('$safe_project_id', '$safe_name', $is_master, $parent_id, 'todo', $sf_val, $mp_val, $md_val, $wp_val);
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
    sqlite3 "$DB_FILE" "
        UPDATE plans SET status = 'doing', started_at = datetime('now')
        WHERE id = $plan_id;
    "
    local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, $version, 'started', 'Execution started', 'planner');
    "
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
# Usage: add-task <wave_id> <task_id> <title> [P0-P3] [feature|bug|chore] [--model haiku|sonnet|opus] [--test-criteria 'json'] [--description 'text']
cmd_add_task() {
    local db_wave_id="$1"
    local task_id="$2"
    local title="$3"
    shift 3

    local priority="P1" type="feature" assignee="" test_criteria="" model="sonnet" description=""

    set +u
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --test-criteria) [[ -z "${2}" ]] && { log_error "Missing --test-criteria value"; set -u; exit 1; }; test_criteria="$2"; shift 2 ;;
            --model) [[ -z "${2}" ]] && { log_error "Missing --model value"; set -u; exit 1; }; model="$2"; shift 2 ;;
            --description) [[ -z "${2}" ]] && { log_error "Missing --description value"; set -u; exit 1; }; description="$2"; shift 2 ;;
            P0|P1|P2|P3) priority="$1"; shift ;;
            bug|feature|chore|doc|test) type="$1"; shift ;;
            haiku|sonnet|opus) model="$1"; shift ;;
            *) [[ -z "$assignee" ]] && assignee="$1"; shift ;;
        esac
    done
    set -u

    local wave_info=$(sqlite3 "$DB_FILE" "SELECT project_id, wave_id, plan_id FROM waves WHERE id = $db_wave_id;")
    local project_id=$(echo "$wave_info" | cut -d'|' -f1)
    local wave_id_text=$(echo "$wave_info" | cut -d'|' -f2)
    local plan_id=$(echo "$wave_info" | cut -d'|' -f3)

    local safe_task_id="$(sql_escape "$task_id")"
    local safe_title="$(sql_escape "$title")"
    local safe_priority="$(sql_escape "$priority")"
    local safe_type="$(sql_escape "$type")"
    local safe_assignee="$(sql_escape "$assignee")"
    local safe_test_criteria="$(sql_escape "$test_criteria")"
    local safe_model="$(sql_escape "$model")"
    local safe_description="$(sql_escape "$description")"

    local tc_val="NULL"
    [[ -n "$test_criteria" ]] && tc_val="'$safe_test_criteria'"
    local desc_val="NULL"
    [[ -n "$description" ]] && desc_val="'$safe_description'"

    sqlite3 "$DB_FILE" "
        INSERT INTO tasks (project_id, wave_id, wave_id_fk, plan_id, task_id, title, description, status, priority, type, assignee, test_criteria, model)
        VALUES ('$project_id', '$wave_id_text', $db_wave_id, $plan_id, '$safe_task_id', '$safe_title', COALESCE($desc_val, '$safe_title'), 'pending', '$safe_priority', '$safe_type', '$safe_assignee', $tc_val, '$safe_model');
    "
    sqlite3 "$DB_FILE" "UPDATE waves SET tasks_total = tasks_total + 1 WHERE id = $db_wave_id;"
    sqlite3 "$DB_FILE" "UPDATE plans SET tasks_total = tasks_total + 1 WHERE id = $plan_id;"

    local db_task_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE plan_id=$plan_id AND wave_id_fk=$db_wave_id AND task_id='$safe_task_id' ORDER BY id DESC LIMIT 1;")
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
    local old_status=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id = $task_id;")

    # Strict: cannot go directly from pending to done
    if [[ "$status" == "done" && "$old_status" == "pending" ]]; then
        log_error "Cannot transition pending→done directly. Mark as in_progress first."
        exit 1
    fi
    local tokens_sql=""
    [[ -n "$tokens" ]] && tokens_sql=", tokens = $tokens"

    if [[ "$status" == "in_progress" ]]; then
        sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', started_at = datetime('now'), notes = '$notes_escaped'$tokens_sql WHERE id = $task_id;"
    elif [[ "$status" == "done" ]]; then
        sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', started_at = COALESCE(started_at, datetime('now')), completed_at = datetime('now'), notes = '$notes_escaped'$tokens_sql WHERE id = $task_id;"
        # NOTE: wave/plan counters updated automatically by SQLite trigger (task_done_counter)

        # Check if wave is now complete (for auto-marking wave as done)
        local wave_fk=$(sqlite3 "$DB_FILE" "SELECT wave_id_fk FROM tasks WHERE id = $task_id;")
        local wave_done=$(sqlite3 "$DB_FILE" "SELECT tasks_done = tasks_total FROM waves WHERE id = $wave_fk;")
        [[ "$wave_done" == "1" ]] && {
            local wave_id_text=$(sqlite3 "$DB_FILE" "SELECT wave_id FROM waves WHERE id = $wave_fk;")
            sqlite3 "$DB_FILE" "UPDATE waves SET status = 'done', started_at = COALESCE(started_at, datetime('now')), completed_at = datetime('now') WHERE id = $wave_fk;"
            log_info "Wave $wave_id_text completed!"
        }
    else
        sqlite3 "$DB_FILE" "UPDATE tasks SET status = '$status', notes = '$notes_escaped'$tokens_sql WHERE id = $task_id;"
    fi
    [[ -n "$tokens" ]] && log_info "Task $task_id: $old_status -> $status (tokens: $tokens)" || log_info "Task $task_id: $old_status -> $status"
}

# Update wave status
cmd_update_wave() {
    local wave_id="$1"
    local status="$2"

    if [[ "$status" == "in_progress" ]]; then
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', started_at = datetime('now') WHERE id = $wave_id;"
    elif [[ "$status" == "done" ]]; then
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', started_at = COALESCE(started_at, datetime('now')), completed_at = datetime('now') WHERE id = $wave_id;"
    else
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status' WHERE id = $wave_id;"
    fi
    log_info "Wave $wave_id -> $status"
}

# Complete plan
cmd_complete() {
    local plan_id="$1"
    local plan_info=$(sqlite3 "$DB_FILE" "SELECT tasks_done, tasks_total, validated_at FROM plans WHERE id = $plan_id;")
    local tasks_done=$(echo "$plan_info" | cut -d'|' -f1)
    local tasks_total=$(echo "$plan_info" | cut -d'|' -f2)
    local validated_at=$(echo "$plan_info" | cut -d'|' -f3)

    if [[ -z "$tasks_total" || "$tasks_total" -eq 0 ]]; then
        log_error "Cannot complete plan $plan_id: no tasks"
        exit 1
    fi
    if [[ "$tasks_done" -lt "$tasks_total" ]]; then
        log_error "Cannot complete plan $plan_id: $tasks_done/$tasks_total tasks done"
        exit 1
    fi
    if [[ -z "$validated_at" ]]; then
        log_error "Cannot complete plan $plan_id: Thor validation required"
        exit 1
    fi

    sqlite3 "$DB_FILE" "UPDATE plans SET status = 'done', completed_at = datetime('now') WHERE id = $plan_id;"

    local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, $version, 'completed', 'Plan completed', 'executor');
    "
    log_info "Plan $plan_id completed!"
}

# Get worktree path for a plan
# Usage: get-worktree <plan_id>
cmd_get_worktree() {
    local plan_id="$1"
    local wt_path
    wt_path=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id = $plan_id;")
    if [[ -z "$wt_path" ]]; then
        log_error "No worktree_path set for plan $plan_id"
        exit 1
    fi
    echo "$wt_path"
}

# Set worktree path for a plan
# Usage: set-worktree <plan_id> <path>
cmd_set_worktree() {
    local plan_id="$1"
    local wt_path="$2"
    local safe_path="$(sql_escape "$wt_path")"
    sqlite3 "$DB_FILE" "UPDATE plans SET worktree_path = '$safe_path' WHERE id = $plan_id;"
    log_info "Set worktree for plan $plan_id: $wt_path"
}
