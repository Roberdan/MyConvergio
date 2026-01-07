#!/bin/bash
# Plan DB CLI - Single source of truth for plan management
# Usage: plan-db.sh <command> [args]
#
# Commands:
#   list <project_id>              - List plans for project
#   create <project_id> <name>     - Create new plan
#   start <plan_id>                - Start plan execution
#   add-wave <plan_id> <id> <name> - Add wave to plan
#   add-task <wave_id> <id> <title> - Add task to wave
#   update-task <task_id> <status> - Update task status
#   update-wave <wave_id> <status> - Update wave status
#   complete <plan_id>             - Mark plan as done
#   validate <plan_id>             - Thor validates plan
#   validate-fxx <plan_id>         - Validate F-xx requirements
#   kanban                         - Show kanban board
#   status [project_id]            - Quick status
#   sync <plan_id>                 - Fix counters
#   json <plan_id>                 - Get plan as JSON

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modules
source "$SCRIPT_DIR/lib/plan-db-core.sh"
source "$SCRIPT_DIR/lib/plan-db-crud.sh"
source "$SCRIPT_DIR/lib/plan-db-validate.sh"
source "$SCRIPT_DIR/lib/plan-db-display.sh"

# Initialize DB
init_db

# Dispatch
case "${1:-help}" in
    list)        cmd_list "${2:?project_id required}" ;;
    create)      cmd_create "${2:?project_id required}" "${3:?name required}" ;;
    start)       cmd_start "${2:?plan_id required}" ;;
    add-wave)    cmd_add_wave "${2:?plan_id required}" "${3:?wave_id required}" "${4:?name required}" "${@:5}" ;;
    add-task)    cmd_add_task "${2:?wave_id required}" "${3:?task_id required}" "${4:?title required}" "${5:-P1}" "${6:-feature}" "${7:-}" ;;
    update-task) cmd_update_task "${2:?task_id required}" "${3:?status required}" "${@:4}" ;;
    update-wave) cmd_update_wave "${2:?wave_id required}" "${3:?status required}" ;;
    complete)    cmd_complete "${2:?plan_id required}" ;;
    validate)    cmd_validate "${2:?plan_id required}" "${3:-thor}" ;;
    validate-fxx) cmd_validate_fxx "${2:?plan_id required}" ;;
    kanban)      cmd_kanban ;;
    kanban-json) cmd_kanban_json ;;
    json)        cmd_json "${2:?plan_id required}" ;;
    status)      cmd_status "${2:-}" ;;
    sync)        cmd_sync "${2:?plan_id required}" ;;
    *)
        echo "Plan DB CLI - Task/Wave/Plan Management"
        echo ""
        echo "Usage: plan-db.sh <command> [args]"
        echo ""
        echo "CRUD:"
        echo "  list <project_id>              List plans"
        echo "  create <project_id> <name>     Create plan"
        echo "  start <plan_id>                Start execution"
        echo "  add-wave <plan_id> <id> <name> [--depends-on id] [--estimated-hours N]"
        echo "  add-task <wave_id> <id> <title> [P0-P3] [feature|bug|chore]"
        echo "  update-task <task_id> <status> [notes] [--tokens N]"
        echo "  update-wave <wave_id> <status>"
        echo "  complete <plan_id>             Mark done"
        echo ""
        echo "Validation:"
        echo "  validate <plan_id> [by]        Thor validates (counters, orphans)"
        echo "  validate-fxx <plan_id>         Validate F-xx from markdown"
        echo "  sync <plan_id>                 Fix out-of-sync counters"
        echo ""
        echo "Display:"
        echo "  kanban                         Kanban board"
        echo "  status [project_id]            Quick status"
        echo "  json <plan_id>                 Plan as JSON"
        echo "  kanban-json                    Kanban as JSON"
        ;;
esac
