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
#   get-worktree <plan_id>         - Get worktree path for plan
#   set-worktree <plan_id> <path>  - Set worktree path for plan
#   validate <plan_id>             - Thor validates plan (bulk)
#   validate-task <task_id> [plan]  - Thor validates single task
#   validate-wave <wave_db_id>     - Thor validates all done tasks in wave
#   validate-fxx <plan_id>         - Validate F-xx requirements
#   kanban                         - Show kanban board
#   status [project_id]            - Quick status
#   sync <plan_id>                 - Fix counters
#   json <plan_id>                 - Get plan as JSON

# Version: 1.2.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modules
source "$SCRIPT_DIR/lib/plan-db-core.sh"
source "$SCRIPT_DIR/lib/plan-db-crud.sh"
source "$SCRIPT_DIR/lib/plan-db-validate.sh"
source "$SCRIPT_DIR/lib/plan-db-display.sh"
source "$SCRIPT_DIR/lib/plan-db-import.sh"
source "$SCRIPT_DIR/lib/plan-db-drift.sh"
source "$SCRIPT_DIR/lib/plan-db-conflicts.sh"
source "$SCRIPT_DIR/lib/plan-db-cluster.sh"
source "$SCRIPT_DIR/lib/plan-db-remote.sh"
source "$SCRIPT_DIR/lib/plan-db-delegate.sh"

# Host identification for cross-machine tracking
export PLAN_DB_HOST="${PLAN_DB_HOST:-$(hostname -s 2>/dev/null || hostname)}"

# Initialize DB
init_db

# Dispatch
case "${1:-help}" in
  delegation-report) cmd_delegation_report "${@:2}" ;;
  delegation-log) cmd_delegation_log "${@:2}" ;;
  delegation-cost) cmd_delegation_cost "${@:2}" ;;
list) cmd_list "${2:?project_id required}" ;;
create) cmd_create "${2:?project_id required}" "${3:?name required}" "${@:4}" ;;
start) cmd_start "${2:?plan_id required}" "${3:-}" ;;
add-wave) cmd_add_wave "${2:?plan_id required}" "${3:?wave_id required}" "${4:?name required}" "${@:5}" ;;
add-task) cmd_add_task "${2:?wave_id required}" "${3:?task_id required}" "${4:?title required}" "${@:5}" ;;
update-task)
	# GUARD: block direct 'done' — must use plan-db-safe.sh for auto-validation
	if [[ "${3:-}" == "done" && "${PLAN_DB_SAFE_CALLER:-}" != "1" ]]; then
		echo "ERROR: Use plan-db-safe.sh (not plan-db.sh) to mark tasks done." >&2
		echo "       plan-db-safe.sh auto-validates with Thor. Direct done = skipped Thor." >&2
		echo "       Override: PLAN_DB_SAFE_CALLER=1 plan-db.sh update-task $2 done ..." >&2
		exit 1
	fi
	cmd_update_task "${2:?task_id required}" "${3:?status required}" "${@:4}"
	;;
update-wave) cmd_update_wave "${2:?wave_id required}" "${3:?status required}" ;;
complete) cmd_complete "${2:?plan_id required}" "${3:-}" ;;
get-worktree) cmd_get_worktree "${2:?plan_id required}" ;;
set-worktree) cmd_set_worktree "${2:?plan_id required}" "${3:?path required}" ;;
validate) cmd_validate "${2:?plan_id required}" "${3:-thor}" ;;
validate-task)
	shift 1
	cmd_validate_task "$@"
	;;
validate-wave) cmd_validate_wave "${2:?wave_db_id required}" "${3:-thor}" ;;
validate-fxx) cmd_validate_fxx "${2:?plan_id required}" ;;
kanban) cmd_kanban ;;
kanban-json) cmd_kanban_json ;;
json) cmd_json "${2:?plan_id required}" ;;
status) cmd_status "${2:-}" ;;
check-readiness) cmd_check_readiness "${2:?plan_id required}" ;;
evaluate-wave) cmd_evaluate_wave "${2:?wave_db_id required}" ;;
sync) cmd_sync "${2:?plan_id required}" ;;
update-desc) sqlite3 "$DB_FILE" "UPDATE plans SET description = '$(sql_escape "${3:?description required}")' WHERE id = ${2:?plan_id required};" && echo "Description updated for plan #$2" ;;
update-summary) sqlite3 "$DB_FILE" "UPDATE plans SET human_summary = '$(sql_escape "${3:?summary required}")' WHERE id = ${2:?plan_id required};" && echo "Summary updated for plan #$2" ;;
import) cmd_import "${2:?plan_id required}" "${3:?spec_file required}" ;;
render) cmd_render "${2:?plan_id required}" ;;
get-context) cmd_get_context "${2:?plan_id required}" ;;
drift-check) cmd_check_drift "${2:?plan_id required}" ;;
conflict-check) cmd_check_conflicts "${2:?plan_id required}" ;;
conflict-check-spec) cmd_check_conflicts_spec "${2:?project_id required}" "${3:?spec_file required}" ;;
rebase-plan) cmd_rebase_plan "${2:?plan_id required}" ;;
where) cmd_where "${2:-}" ;;
claim) cmd_claim "${2:?plan_id required}" "${3:-}" ;;
release) cmd_release "${2:?plan_id required}" ;;
heartbeat) cmd_heartbeat ;;
remote-status) cmd_remote_status "${2:-}" ;;
cluster-status) cmd_cluster_status ;;
cluster-tasks) cmd_cluster_tasks ;;
token-report) cmd_token_report ;;
autosync) "$SCRIPT_DIR/plan-db-autosync.sh" "${2:-status}" ;;
# Concurrency control (delegate to standalone scripts)
lock) "$SCRIPT_DIR/file-lock.sh" "${@:2}" ;;
stale-check) "$SCRIPT_DIR/stale-check.sh" "${@:2}" ;;
wave-overlap) "$SCRIPT_DIR/wave-overlap.sh" "${@:2}" ;;
merge-queue) "$SCRIPT_DIR/merge-queue.sh" "${@:2}" ;;
*)
	echo "[ERROR] Unknown command: '${1:-}'" >&2
	echo "" >&2
	echo "Plan DB CLI - Task/Wave/Plan Management"
	echo ""
	echo "Usage: plan-db.sh <command> [args]"
	echo ""
	echo "CRUD:"
	echo "  list <project_id>              List plans"
	echo "  create <project_id> <name> [--source-file path] [--markdown-path path] [--auto-worktree]"
	echo "  start <plan_id>                Start execution"
	echo "  add-wave <plan_id> <id> <name> [--depends-on id] [--estimated-hours N]"
	echo "  add-task <wave_id> <id> <title> [P0-P3] [type] [--description 'text'] [--test-criteria 'json']"
	echo "  update-task <task_id> <status> [notes] [--tokens N]"
	echo "  update-wave <wave_id> <status>"
	echo "  update-desc <plan_id> <desc>   Set plan description (agent-facing)"
	echo "  update-summary <plan_id> <txt> Set human-readable summary (shown in dashboard)"
	echo "  complete <plan_id>             Mark done"
	echo "  get-worktree <plan_id>         Get worktree path for plan"
	echo "  set-worktree <plan_id> <path>  Set worktree path for plan"
	echo ""
	echo "Validation:"
	echo "  check-readiness <plan_id>      BLOCKS if metadata missing (run before /execute)"
	echo "  evaluate-wave <wave_db_id>     Check wave preconditions (returns JSON)"
	echo "  validate <plan_id> [by]        Thor validates plan (counters, orphans, bulk)"
	echo "  validate-task <task_id> [plan_id] [by]  Validate single task (per-task Thor gate)"
	echo "  validate-wave <wave_db_id> [by]         Validate all done tasks in wave"
	echo "  validate-fxx <plan_id>         Validate F-xx from markdown"
	echo "  drift-check <plan_id>          Check plan staleness vs main (JSON report)"
	echo "  conflict-check <plan_id>       Cross-plan file overlap detection (JSON)"
	echo "  conflict-check-spec <proj> <spec.json>  Pre-import conflict check"
	echo "  rebase-plan <plan_id>          Rebase plan worktree onto latest main"
	echo "  sync <plan_id>                 Fix out-of-sync counters"
	echo ""
	echo "Cluster:"
	echo "  claim <plan_id> [--force]      Claim plan for this host"
	echo "  release <plan_id>              Release plan from this host"
	echo "  heartbeat                      Write heartbeat for this host"
	echo "  remote-status [project_id]     Show status from remote host"
	echo "  cluster-status                 Unified view of all hosts"
	echo "  cluster-tasks                  In-progress tasks across hosts"
	echo "  token-report                   Per-project token/cost by host"
	echo "  autosync [start|stop|status]   Auto-sync daemon"
	echo "  where [plan_id]                Show execution host for plans"
	echo ""
	echo "Bulk:"
	echo "  import <plan_id> <spec.json>   Bulk import waves+tasks from JSON spec"
	echo "  render <plan_id>               Generate markdown from DB (single source of truth)"
	echo "  get-context <plan_id>          Full plan+tasks JSON for execution (1 call)"
	echo ""
	echo "Display:"
	echo "  kanban                         Kanban board"
	echo "  status [project_id]            Quick status"
	echo "  json <plan_id>                 Plan as JSON"
	echo "  kanban-json                    Kanban as JSON"
	echo ""
	echo "Concurrency:"
	echo "  lock acquire|release|check|list|cleanup  File-level locking"
	echo "  stale-check snapshot|check|diff|cleanup  Stale context detection"
	echo "  wave-overlap check-wave|check-plan|check-spec  Intra-wave overlap"
	echo "  merge-queue enqueue|process|status|cancel  Sequential merge queue"
	echo ""
	echo "Task statuses: pending | in_progress | done | blocked | skipped"
	echo "Plan statuses: todo | doing | done | archived"
	exit 1
	;;
esac
