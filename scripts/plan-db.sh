#!/bin/bash
# Plan DB CLI - Single source of truth for plan management
# Usage: plan-db.sh <command> [args]
#
# Commands:
#   list <project_id>              - List available plans for project
#   create <project_id> <name>     - Create new plan
#   start <plan_id>                - Start executing a plan
#   add-wave <plan_id> <name>      - Add wave to plan
#   add-task <wave_id> <title>     - Add task to wave
#   update-task <task_id> <status> - Update task status (executor)
#   update-wave <wave_id> <status> - Update wave status
#   complete <plan_id>             - Mark plan as done
#   validate <plan_id> <by>        - Thor validates plan
#   kanban                         - Show kanban board
#   import <project_id> <file>     - Import plan from .md file

set -euo pipefail

DB_FILE="${HOME}/.claude/data/dashboard.db"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Initialize DB if needed
init_db() {
    if [[ ! -f "$DB_FILE" ]]; then
        mkdir -p "$(dirname "$DB_FILE")"
        sqlite3 "$DB_FILE" < "$SCRIPT_DIR/init-db-v3.sql"
        log_info "Database initialized"
    fi
}

# List plans for a project
cmd_list() {
    local project_id="$1"

    echo -e "${BLUE}Plans for project: ${project_id}${NC}"
    echo ""

    sqlite3 -header -column "$DB_FILE" "
        SELECT
            id,
            name,
            CASE WHEN is_master THEN '★ MASTER' ELSE '' END as type,
            status,
            tasks_done || '/' || tasks_total as progress,
            CASE
                WHEN status = 'doing' THEN '▶ IN PROGRESS'
                WHEN status = 'done' THEN '✓ COMPLETED'
                ELSE '○ TODO'
            END as state
        FROM plans
        WHERE project_id = '$project_id'
        ORDER BY is_master DESC, status, name;
    "
}

# Create a new plan
cmd_create() {
    local project_id="$1"
    local name="$2"
    local is_master=0
    local parent_id="NULL"

    # Detect if master plan
    if [[ "$name" == *"-Main"* ]] || [[ "$name" == *"-Master"* ]]; then
        is_master=1
    fi

    # Check for parent master plan
    if [[ $is_master -eq 0 ]]; then
        local base_name="${name%%-Phase*}"
        base_name="${base_name%%-[0-9]*}"
        local master_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$project_id' AND name LIKE '${base_name}%' AND is_master=1 LIMIT 1;")
        if [[ -n "$master_id" ]]; then
            parent_id="$master_id"
        fi
    fi

    sqlite3 "$DB_FILE" "
        INSERT INTO plans (project_id, name, is_master, parent_plan_id, status)
        VALUES ('$project_id', '$name', $is_master, $parent_id, 'todo');
    "

    local plan_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$project_id' AND name='$name';")

    # Log version
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
        UPDATE plans
        SET status = 'doing', started_at = datetime('now')
        WHERE id = $plan_id;
    "

    # Log version
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
    local assignee="${4:-}"

    # Get project_id from plan
    local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")
    local position=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(position), 0) + 1 FROM waves WHERE plan_id = $plan_id;")

    sqlite3 "$DB_FILE" "
        INSERT INTO waves (project_id, plan_id, wave_id, name, status, assignee, position)
        VALUES ('$project_id', $plan_id, '$wave_id', '$name', 'pending', '$assignee', $position);
    "

    local db_wave_id=$(sqlite3 "$DB_FILE" "SELECT id FROM waves WHERE plan_id=$plan_id AND wave_id='$wave_id';")
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

    # Get project_id and wave_id string from waves table
    local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM waves WHERE id = $db_wave_id;")
    local wave_id=$(sqlite3 "$DB_FILE" "SELECT wave_id FROM waves WHERE id = $db_wave_id;")

    sqlite3 "$DB_FILE" "
        INSERT INTO tasks (project_id, wave_id, task_id, title, status, priority, type, assignee)
        VALUES ('$project_id', '$wave_id', '$task_id', '$title', 'pending', '$priority', '$type', '$assignee');
    "

    # Update wave total
    sqlite3 "$DB_FILE" "UPDATE waves SET tasks_total = tasks_total + 1 WHERE id = $db_wave_id;"

    # Update plan total
    local plan_id=$(sqlite3 "$DB_FILE" "SELECT plan_id FROM waves WHERE id = $db_wave_id;")
    sqlite3 "$DB_FILE" "UPDATE plans SET tasks_total = tasks_total + 1 WHERE id = $plan_id;"

    local db_task_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE project_id='$project_id' AND wave_id='$wave_id' AND task_id='$task_id';")
    log_info "Added task: $title (ID: $db_task_id)"
    echo "$db_task_id"
}

# Update task status (for executor)
cmd_update_task() {
    local task_id="$1"
    local status="$2"
    local notes="${3:-}"

    local old_status=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id = $task_id;")

    if [[ "$status" == "in_progress" ]]; then
        sqlite3 "$DB_FILE" "
            UPDATE tasks
            SET status = '$status', started_at = datetime('now'), notes = '$notes'
            WHERE id = $task_id;
        "
    elif [[ "$status" == "done" ]]; then
        sqlite3 "$DB_FILE" "
            UPDATE tasks
            SET status = '$status', completed_at = datetime('now'), notes = '$notes'
            WHERE id = $task_id;
        "

        # Update wave done count
        local wave_id=$(sqlite3 "$DB_FILE" "SELECT wave_id FROM tasks WHERE id = $task_id;")
        sqlite3 "$DB_FILE" "UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = $wave_id;"

        # Update plan done count
        local plan_id=$(sqlite3 "$DB_FILE" "SELECT plan_id FROM waves WHERE id = $wave_id;")
        sqlite3 "$DB_FILE" "UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = $plan_id;"

        # Check if wave is complete
        local wave_done=$(sqlite3 "$DB_FILE" "SELECT tasks_done = tasks_total FROM waves WHERE id = $wave_id;")
        if [[ "$wave_done" == "1" ]]; then
            sqlite3 "$DB_FILE" "UPDATE waves SET status = 'done', completed_at = datetime('now') WHERE id = $wave_id;"
            log_info "Wave $wave_id completed!"
        fi
    else
        sqlite3 "$DB_FILE" "
            UPDATE tasks SET status = '$status', notes = '$notes' WHERE id = $task_id;
        "
    fi

    log_info "Task $task_id: $old_status → $status"
}

# Update wave status
cmd_update_wave() {
    local wave_id="$1"
    local status="$2"

    if [[ "$status" == "in_progress" ]]; then
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', started_at = datetime('now') WHERE id = $wave_id;"
    elif [[ "$status" == "done" ]]; then
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status', completed_at = datetime('now') WHERE id = $wave_id;"
    else
        sqlite3 "$DB_FILE" "UPDATE waves SET status = '$status' WHERE id = $wave_id;"
    fi

    log_info "Wave $wave_id → $status"
}

# Complete plan
cmd_complete() {
    local plan_id="$1"

    sqlite3 "$DB_FILE" "
        UPDATE plans
        SET status = 'done', completed_at = datetime('now')
        WHERE id = $plan_id;
    "

    local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, $version, 'completed', 'Plan completed', 'executor');
    "

    log_info "Plan $plan_id completed!"
}

# Thor validates plan
cmd_validate() {
    local plan_id="$1"
    local validated_by="${2:-thor}"

    sqlite3 "$DB_FILE" "
        UPDATE plans
        SET validated_at = datetime('now'), validated_by = '$validated_by'
        WHERE id = $plan_id;
    "

    local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, $version, 'validated', 'Validated by $validated_by', '$validated_by');
    "

    log_info "Plan $plan_id validated by $validated_by"
}

# Show kanban board
cmd_kanban() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                        KANBAN BOARD                            ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}▶ DOING${NC}"
    sqlite3 -column "$DB_FILE" "
        SELECT project_name, plan_name, progress || '%' as prog,
               CASE WHEN is_master THEN '★' ELSE '' END as m
        FROM v_kanban WHERE status = 'doing';
    " || echo "  (none)"
    echo ""

    echo -e "${NC}○ TODO${NC}"
    sqlite3 -column "$DB_FILE" "
        SELECT project_name, plan_name,
               CASE WHEN is_master THEN '★' ELSE '' END as m
        FROM v_kanban WHERE status = 'todo' LIMIT 10;
    " || echo "  (none)"
    echo ""

    echo -e "${GREEN}✓ DONE (recent)${NC}"
    sqlite3 -column "$DB_FILE" "
        SELECT project_name, plan_name, completed_at
        FROM v_kanban WHERE status = 'done'
        ORDER BY completed_at DESC LIMIT 5;
    " || echo "  (none)"
}

# Get plan as JSON (for API)
cmd_json() {
    local plan_id="$1"

    sqlite3 -json "$DB_FILE" "
        SELECT
            p.id, p.name, p.status, p.is_master, p.tasks_done, p.tasks_total,
            p.created_at, p.started_at, p.completed_at, p.validated_at,
            pr.id as project_id, pr.name as project_name
        FROM plans p
        JOIN projects pr ON p.project_id = pr.id
        WHERE p.id = $plan_id;
    "
}

# Get kanban as JSON (for API)
cmd_kanban_json() {
    sqlite3 -json "$DB_FILE" "SELECT * FROM v_kanban;"
}

# Main
init_db

case "${1:-help}" in
    list)
        cmd_list "${2:?project_id required}"
        ;;
    create)
        cmd_create "${2:?project_id required}" "${3:?name required}"
        ;;
    start)
        cmd_start "${2:?plan_id required}"
        ;;
    add-wave)
        cmd_add_wave "${2:?plan_id required}" "${3:?wave_id required}" "${4:?name required}" "${5:-}"
        ;;
    add-task)
        cmd_add_task "${2:?wave_id required}" "${3:?task_id required}" "${4:?title required}" "${5:-P1}" "${6:-feature}" "${7:-}" "${8:-}"
        ;;
    update-task)
        cmd_update_task "${2:?task_id required}" "${3:?status required}" "${4:-}"
        ;;
    update-wave)
        cmd_update_wave "${2:?wave_id required}" "${3:?status required}"
        ;;
    complete)
        cmd_complete "${2:?plan_id required}"
        ;;
    validate)
        cmd_validate "${2:?plan_id required}" "${3:-thor}"
        ;;
    kanban)
        cmd_kanban
        ;;
    json)
        cmd_json "${2:?plan_id required}"
        ;;
    kanban-json)
        cmd_kanban_json
        ;;
    *)
        echo "Usage: plan-db.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  list <project_id>              List plans for project"
        echo "  create <project_id> <name>     Create new plan"
        echo "  start <plan_id>                Start plan execution"
        echo "  add-wave <plan_id> <id> <name> Add wave to plan"
        echo "  add-task <wave_id> <id> <title> [priority] [type] [assignee] [files]"
        echo "  update-task <task_id> <status> Update task (pending|in_progress|done|blocked)"
        echo "  update-wave <wave_id> <status> Update wave status"
        echo "  complete <plan_id>             Mark plan as done"
        echo "  validate <plan_id> [by]        Thor validates plan"
        echo "  kanban                         Show kanban board"
        echo "  json <plan_id>                 Get plan as JSON"
        echo "  kanban-json                    Get kanban as JSON"
        ;;
esac
