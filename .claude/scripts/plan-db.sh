#!/bin/bash
# Plan DB CLI - Single source of truth for plan management
# EXCEPTION: File exceeds 300 lines (567) - Essential CLI tool with 13 commands
# Splitting would require source files which adds complexity for shell scripts
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

# Add wave to plan with Gantt support
# Usage: add-wave <plan_id> <wave_id> <name> [--planned-start "YYYY-MM-DD HH:MM"] [--planned-end "..."] [--estimated-hours N] [--depends-on wave_id] [--assignee name]
cmd_add_wave() {
    local plan_id="$1"
    local wave_id="$2"
    local name="$3"
    shift 3

    # Defaults
    local assignee=""
    local planned_start=""
    local planned_end=""
    local estimated_hours="8"
    local depends_on=""

    # Parse optional flags (temporarily disable unbound check for safe parameter access)
    set +u
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --assignee)
                if [[ -z "${2}" ]]; then log_error "Missing value for --assignee"; set -u; exit 1; fi
                assignee="$2"; shift 2 ;;
            --planned-start)
                if [[ -z "${2}" ]]; then log_error "Missing value for --planned-start"; set -u; exit 1; fi
                planned_start="$2"; shift 2 ;;
            --planned-end)
                if [[ -z "${2}" ]]; then log_error "Missing value for --planned-end"; set -u; exit 1; fi
                planned_end="$2"; shift 2 ;;
            --estimated-hours)
                if [[ -z "${2}" ]]; then log_error "Missing value for --estimated-hours"; set -u; exit 1; fi
                estimated_hours="$2"; shift 2 ;;
            --depends-on)
                if [[ -z "${2}" ]]; then log_error "Missing value for --depends-on"; set -u; exit 1; fi
                depends_on="$2"; shift 2 ;;
            *) assignee="$1"; shift ;;  # Backwards compat: positional assignee
        esac
    done
    set -u

    # Get project_id from plan
    local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")
    local position=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(position), 0) + 1 FROM waves WHERE plan_id = $plan_id;")

    # Build INSERT with optional Gantt fields
    local start_val="NULL"
    local end_val="NULL"
    local depends_val="NULL"
    [[ -n "$planned_start" ]] && start_val="'$planned_start'"
    [[ -n "$planned_end" ]] && end_val="'$planned_end'"
    [[ -n "$depends_on" ]] && depends_val="'$depends_on'"

    sqlite3 "$DB_FILE" "
        INSERT INTO waves (project_id, plan_id, wave_id, name, status, assignee, position, estimated_hours, planned_start, planned_end, depends_on)
        VALUES ('$project_id', $plan_id, '$wave_id', '$name', 'pending', '$assignee', $position, $estimated_hours, $start_val, $end_val, $depends_val);
    "

    local db_wave_id=$(sqlite3 "$DB_FILE" "SELECT id FROM waves WHERE plan_id=$plan_id AND wave_id='$wave_id';")
    log_info "Added wave: $name (ID: $db_wave_id, depends: ${depends_on:-none})"
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

        # Get wave_id (TEXT like "W3") and project_id to find the wave
        local wave_id_text=$(sqlite3 "$DB_FILE" "SELECT wave_id FROM tasks WHERE id = $task_id;")
        local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM tasks WHERE id = $task_id;")

        # Update wave done count using project_id + wave_id (TEXT)
        sqlite3 "$DB_FILE" "UPDATE waves SET tasks_done = tasks_done + 1 WHERE project_id = '$project_id' AND wave_id = '$wave_id_text';"

        # Get wave's DB id for plan lookup
        local wave_db_id=$(sqlite3 "$DB_FILE" "SELECT id FROM waves WHERE project_id = '$project_id' AND wave_id = '$wave_id_text';")

        # Update plan done count
        local plan_id=$(sqlite3 "$DB_FILE" "SELECT plan_id FROM waves WHERE id = $wave_db_id;")
        sqlite3 "$DB_FILE" "UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = $plan_id;"

        # Check if wave is complete
        local wave_done=$(sqlite3 "$DB_FILE" "SELECT tasks_done = tasks_total FROM waves WHERE id = $wave_db_id;")
        if [[ "$wave_done" == "1" ]]; then
            sqlite3 "$DB_FILE" "UPDATE waves SET status = 'done', completed_at = datetime('now') WHERE id = $wave_db_id;"
            log_info "Wave $wave_id_text completed!"
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

# Thor validates plan - ACTUAL validation checks
cmd_validate() {
    local plan_id="$1"
    local validated_by="${2:-thor}"
    local errors=0
    local warnings=0

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}           THOR VALIDATION - Plan $plan_id                      ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Get project_id for this plan
    local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")

    # Check 1: Counter sync - waves
    echo -e "${YELLOW}[1/5] Checking wave counter sync...${NC}"
    local wave_issues=$(sqlite3 "$DB_FILE" "
        SELECT w.wave_id, w.tasks_done, w.tasks_total,
               (SELECT COUNT(*) FROM tasks t WHERE t.project_id = w.project_id AND t.wave_id = w.wave_id AND t.status = 'done') as actual_done,
               (SELECT COUNT(*) FROM tasks t WHERE t.project_id = w.project_id AND t.wave_id = w.wave_id) as actual_total
        FROM waves w WHERE w.plan_id = $plan_id
        AND (w.tasks_done != (SELECT COUNT(*) FROM tasks t WHERE t.project_id = w.project_id AND t.wave_id = w.wave_id AND t.status = 'done')
             OR w.tasks_total != (SELECT COUNT(*) FROM tasks t WHERE t.project_id = w.project_id AND t.wave_id = w.wave_id));
    ")
    if [ -n "$wave_issues" ]; then
        echo -e "${RED}  ERROR: Wave counters out of sync:${NC}"
        echo "$wave_issues"
        ((errors++))
    else
        echo -e "${GREEN}  OK: All wave counters synced${NC}"
    fi

    # Check 2: Orphan tasks (tasks with no valid wave)
    echo -e "${YELLOW}[2/5] Checking for orphan tasks...${NC}"
    local orphans=$(sqlite3 "$DB_FILE" "
        SELECT t.id, t.task_id, t.wave_id FROM tasks t
        WHERE t.project_id = '$project_id'
        AND NOT EXISTS (SELECT 1 FROM waves w WHERE w.project_id = t.project_id AND w.wave_id = t.wave_id AND w.plan_id = $plan_id);
    ")
    if [ -n "$orphans" ]; then
        echo -e "${RED}  ERROR: Orphan tasks found (no valid wave):${NC}"
        echo "$orphans"
        ((errors++))
    else
        echo -e "${GREEN}  OK: No orphan tasks${NC}"
    fi

    # Check 3: Incomplete tasks in "done" waves
    echo -e "${YELLOW}[3/5] Checking for incomplete tasks in done waves...${NC}"
    local incomplete=$(sqlite3 "$DB_FILE" "
        SELECT w.wave_id, t.task_id, t.status FROM tasks t
        JOIN waves w ON t.project_id = w.project_id AND t.wave_id = w.wave_id
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

    # Check 5: Sensible dates (planned_end > planned_start)
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
        SET validated_at = datetime('now'), validated_by = '$validated_by'
        WHERE id = $plan_id;
    "

    local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
    sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by)
        VALUES ($plan_id, $version, 'validated', 'Validated by $validated_by - 0 errors', '$validated_by');
    "

    echo -e "${GREEN}VALIDATION PASSED: Plan $plan_id validated by $validated_by${NC}"
    return 0
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

# Sync counters - fixes out-of-sync wave/plan counters
cmd_sync() {
    local plan_id="$1"

    log_info "Syncing counters for plan $plan_id..."

    # Sync wave counters with actual task counts
    sqlite3 "$DB_FILE" "
        UPDATE waves SET
            tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.project_id = waves.project_id AND tasks.wave_id = waves.wave_id AND tasks.status = 'done'),
            tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.project_id = waves.project_id AND tasks.wave_id = waves.wave_id)
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
        cmd_add_wave "${2:?plan_id required}" "${3:?wave_id required}" "${4:?name required}" "${@:5}"
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
    sync)
        cmd_sync "${2:?plan_id required}"
        ;;
    *)
        echo "Usage: plan-db.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  list <project_id>              List plans for project"
        echo "  create <project_id> <name>     Create new plan"
        echo "  start <plan_id>                Start plan execution"
        echo "  add-wave <plan_id> <id> <name> [options]"
        echo "          Options: --planned-start \"YYYY-MM-DD HH:MM\""
        echo "                   --planned-end \"YYYY-MM-DD HH:MM\""
        echo "                   --estimated-hours N"
        echo "                   --depends-on wave_id"
        echo "                   --assignee name"
        echo "  add-task <wave_id> <id> <title> [priority] [type] [assignee]"
        echo "          priority: P0|P1|P2|P3  type: feature|bug|chore|doc|test"
        echo "  update-task <task_id> <status> Update task (pending|in_progress|done|blocked)"
        echo "  update-wave <wave_id> <status> Update wave status"
        echo "  complete <plan_id>             Mark plan as done"
        echo "  validate <plan_id> [by]        Thor validates plan"
        echo "  kanban                         Show kanban board"
        echo "  json <plan_id>                 Get plan as JSON"
        echo "  kanban-json                    Get kanban as JSON"
        echo "  sync <plan_id>                 Fix out-of-sync wave/plan counters"
        ;;
esac
