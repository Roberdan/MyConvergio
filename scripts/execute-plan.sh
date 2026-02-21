#!/bin/bash
# execute-plan.sh - Standalone plan executor callable from any CLI
# Usage: execute-plan.sh <plan_id> [--from T1-03] [--engine copilot|claude|opencode] [--model <model>]
#
# Iterates waves sequentially. Within each wave, executes tasks via:
#   1. delegate.sh (preferred, if available)
#   2. copilot-worker.sh (if engine=copilot)
#   3. claude --dangerously-skip-permissions (if engine=claude)
#   4. opencode (if engine=opencode)
# Handles Thor per-task and per-wave validation. Supports resume via --from.
#
# References: F-01 (universal CLI invocation), F-22 (engine routing)

# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${HOME}/.claude/data/dashboard.db"
LOG_DIR="${HOME}/.claude/logs/execute-plan"

# ============================================================================
# Colors
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[EXECUTOR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
step() { echo -e "${CYAN}  -->${NC} $1"; }

# ============================================================================
# Args
# ============================================================================
PLAN_ID="${1:-}"

# Handle --help as first argument (before consuming as plan_id)
if [[ "$PLAN_ID" == "--help" || "$PLAN_ID" == "-h" ]]; then
	cat <<'EOF'
Usage: execute-plan.sh <plan_id> [OPTIONS]

OPTIONS:
  --from <task_id>          Resume from specific task (e.g. T1-03)
  --engine <engine>         Execution engine: claude|copilot|opencode (default: claude)
  --model <model>           Model override (e.g. claude-opus-4-6, gpt-5.3-codex)
  --timeout <seconds>       Per-task timeout in seconds (default: 900)
  --dry-run                 Show what would be executed without running
  --help                    Show this help

EXAMPLES:
  execute-plan.sh 180
  execute-plan.sh 180 --from T1-03
  execute-plan.sh 180 --engine copilot --model gpt-5.3-codex
  execute-plan.sh 180 --engine opencode --model claude-opus-4-6
EOF
	exit 0
fi

FROM_TASK=""
ENGINE="claude"
MODEL=""
DRY_RUN=0
TASK_TIMEOUT=900

shift || true

while [[ $# -gt 0 ]]; do
	case $1 in
	--from)
		FROM_TASK="${2:-}"
		shift 2
		;;
	--engine)
		ENGINE="${2:-claude}"
		shift 2
		;;
	--model)
		MODEL="${2:-}"
		shift 2
		;;
	--timeout)
		TASK_TIMEOUT="${2:-900}"
		shift 2
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	--help | -h)
		cat <<'EOF'
Usage: execute-plan.sh <plan_id> [OPTIONS]

OPTIONS:
  --from <task_id>          Resume from specific task (e.g. T1-03)
  --engine <engine>         Execution engine: claude|copilot|opencode (default: claude)
  --model <model>           Model override (e.g. claude-opus-4-6, gpt-5.3-codex)
  --timeout <seconds>       Per-task timeout in seconds (default: 900)
  --dry-run                 Show what would be executed without running
  --help                    Show this help

EXAMPLES:
  execute-plan.sh 180
  execute-plan.sh 180 --from T1-03
  execute-plan.sh 180 --engine copilot --model gpt-5.3-codex
  execute-plan.sh 180 --engine opencode --model claude-opus-4-6
EOF
		exit 0
		;;
	*) shift ;;
	esac
done

# ============================================================================
# Validation
# ============================================================================
if [[ -z "$PLAN_ID" ]]; then
	error "plan_id required"
	echo "Usage: execute-plan.sh <plan_id> [--from T1-03] [--engine claude|copilot|opencode]" >&2
	exit 1
fi

if [[ ! -f "$DB_FILE" ]]; then
	error "Database not found: $DB_FILE"
	exit 1
fi

# Verify plan exists
PLAN_NAME=$(sqlite3 "$DB_FILE" "SELECT name FROM plans WHERE id=$PLAN_ID;" 2>/dev/null || echo "")
if [[ -z "$PLAN_NAME" ]]; then
	error "Plan $PLAN_ID not found in DB"
	exit 1
fi

# ============================================================================
# Engine availability checks
# ============================================================================
DELEGATE_SH="${SCRIPT_DIR}/delegate.sh"
COPILOT_WORKER="${SCRIPT_DIR}/copilot-worker.sh"

check_engine() {
	case "$ENGINE" in
	claude)
		if ! command -v claude &>/dev/null; then
			error "claude CLI not found (install or use --engine copilot|opencode)"
			exit 1
		fi
		;;
	copilot)
		if ! command -v copilot &>/dev/null; then
			error "copilot CLI not found"
			exit 1
		fi
		if [[ -z "${GH_TOKEN:-}" && -z "${COPILOT_TOKEN:-}" ]]; then
			if ! gh auth status &>/dev/null 2>&1; then
				error "No auth: set GH_TOKEN, COPILOT_TOKEN, or run 'gh auth login'"
				exit 1
			fi
		fi
		;;
	opencode)
		if ! command -v opencode &>/dev/null; then
			error "opencode CLI not found"
			exit 1
		fi
		;;
	*)
		error "Unknown engine: $ENGINE. Use: claude|copilot|opencode"
		exit 1
		;;
	esac
}

if [[ "$DRY_RUN" -eq 0 ]]; then
	check_engine
fi

# ============================================================================
# Setup logging
# ============================================================================
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/plan-${PLAN_ID}-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

log "=== PLAN EXECUTOR: plan=$PLAN_ID engine=$ENGINE ==="
[[ -n "$MODEL" ]] && log "Model override: $MODEL"
[[ -n "$FROM_TASK" ]] && log "Resume from task: $FROM_TASK"
[[ "$DRY_RUN" -eq 1 ]] && warn "DRY RUN MODE — no tasks will be executed"
log "Log: $LOG_FILE"
echo ""

# ============================================================================
# DB helpers
# ============================================================================
db_query() {
	sqlite3 -cmd ".timeout 5000" "$DB_FILE" "$@"
}

get_waves() {
	db_query "SELECT id, wave_id, name, status FROM waves WHERE plan_id=$PLAN_ID ORDER BY id;"
}

get_wave_tasks() {
	local wave_db_id="$1"
	db_query "SELECT id, task_id, status, title FROM tasks
		WHERE wave_id_fk=$wave_db_id
		ORDER BY id;"
}

# ============================================================================
# Generate task prompt for execution
# ============================================================================
build_task_prompt() {
	local task_db_id="$1"
	# Use existing prompt generator if available
	if [[ -x "${SCRIPT_DIR}/copilot-task-prompt.sh" ]]; then
		"${SCRIPT_DIR}/copilot-task-prompt.sh" "$task_db_id" 2>/dev/null
	else
		# Fallback: query DB directly
		db_query "SELECT 'Task ID: '||task_id||char(10)||
			'Title: '||title||char(10)||
			'Description: '||COALESCE(description,'')||char(10)||
			'Test Criteria: '||COALESCE(test_criteria,'')
			FROM tasks WHERE id=$task_db_id;"
	fi
}

# ============================================================================
# Execute a single task via the selected engine
# ============================================================================
run_task() {
	local task_db_id="$1"
	local task_code="$2"

	# Get worktree for this task's plan
	local worktree
	worktree=$(db_query "SELECT COALESCE(p.worktree_path,'')
		FROM tasks t JOIN plans p ON t.plan_id=p.id
		WHERE t.id=$task_db_id;")
	worktree="${worktree/#\~/$HOME}"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		step "DRY-RUN: would execute $task_code via $ENGINE"
		return 0
	fi

	# Build the prompt
	local prompt
	prompt="$(build_task_prompt "$task_db_id")"

	local exit_code=0

	# --- Strategy 1: delegate.sh (preferred) ---
	if [[ -x "$DELEGATE_SH" ]]; then
		step "Executing via delegate.sh (engine: $ENGINE)"
		local model_flag=""
		[[ -n "$MODEL" ]] && model_flag="--model $MODEL"
		# delegate.sh accepts: delegate.sh <task_db_id> [--engine <e>] [--model <m>]
		timeout "$TASK_TIMEOUT" "$DELEGATE_SH" "$task_db_id" \
			--engine "$ENGINE" $model_flag || exit_code=$?
		return $exit_code
	fi

	# --- Strategy 2: engine-specific fallback ---
	case "$ENGINE" in

	copilot)
		step "Executing via copilot-worker.sh"
		local model_arg="${MODEL:-}"
		if [[ -x "$COPILOT_WORKER" ]]; then
			local worker_args=("$task_db_id")
			[[ -n "$model_arg" ]] && worker_args+=(--model "$model_arg")
			worker_args+=(--timeout "$TASK_TIMEOUT")
			timeout "$TASK_TIMEOUT" "$COPILOT_WORKER" "${worker_args[@]}" || exit_code=$?
		else
			# Direct copilot invocation
			local model_flag=""
			[[ -n "$MODEL" ]] && model_flag="--model $MODEL"
			local dir_flag=""
			[[ -n "$worktree" && -d "$worktree" ]] && dir_flag="--add-dir $worktree"
			timeout "$TASK_TIMEOUT" copilot \
				--allow-all \
				--no-ask-user \
				$dir_flag \
				$model_flag \
				-p "$prompt" || exit_code=$?
		fi
		;;

	opencode)
		step "Executing via opencode"
		local model_flag=""
		[[ -n "$MODEL" ]] && model_flag="--model $MODEL"
		local cwd_flag=""
		[[ -n "$worktree" && -d "$worktree" ]] && cwd_flag="--cwd $worktree"
		timeout "$TASK_TIMEOUT" opencode \
			$cwd_flag \
			$model_flag \
			--prompt "$prompt" || exit_code=$?
		;;

	claude | *)
		step "Executing via claude CLI"
		local model_flag=""
		[[ -n "$MODEL" ]] && model_flag="--model $MODEL"
		local cwd_flag=""
		[[ -n "$worktree" && -d "$worktree" ]] && cwd_flag="--cwd $worktree"
		timeout "$TASK_TIMEOUT" claude \
			--dangerously-skip-permissions \
			$cwd_flag \
			$model_flag \
			-p "$prompt" || exit_code=$?
		;;
	esac

	return $exit_code
}

# ============================================================================
# Thor per-task validation
# ============================================================================
validate_task() {
	local task_db_id="$1"
	local task_code="$2"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		step "DRY-RUN: would validate task $task_code via Thor"
		return 0
	fi

	step "Thor per-task validation: $task_code"
	if "${SCRIPT_DIR}/plan-db.sh" validate-task "$task_db_id" "$PLAN_ID" "execute-plan" 2>&1; then
		success "Thor: task $task_code PASS"
		return 0
	else
		warn "Thor: task $task_code REJECTED"
		return 1
	fi
}

# ============================================================================
# Thor per-wave validation
# ============================================================================
validate_wave() {
	local wave_db_id="$1"
	local wave_code="$2"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		step "DRY-RUN: would validate wave $wave_code via Thor"
		return 0
	fi

	step "Thor per-wave validation: $wave_code"
	if "${SCRIPT_DIR}/plan-db.sh" validate-wave "$wave_db_id" "execute-plan" 2>&1; then
		success "Thor: wave $wave_code PASS"
		return 0
	else
		warn "Thor: wave $wave_code REJECTED"
		return 1
	fi
}

# ============================================================================
# Resume logic: find tasks to skip
# ============================================================================
SKIP_UNTIL_TASK=""
if [[ -n "$FROM_TASK" ]]; then
	SKIP_UNTIL_TASK="$FROM_TASK"
	log "Resume mode: skipping tasks before $FROM_TASK"
fi

should_skip_task() {
	local task_code="$1"
	if [[ -n "$SKIP_UNTIL_TASK" ]]; then
		if [[ "$task_code" == "$SKIP_UNTIL_TASK" ]]; then
			# Found the start task — stop skipping
			SKIP_UNTIL_TASK=""
			return 1 # do NOT skip this task
		fi
		return 0 # skip
	fi
	return 1 # do NOT skip
}

# ============================================================================
# Main execution loop
# ============================================================================
TOTAL_TASKS=0
DONE_TASKS=0
SKIPPED_TASKS=0
FAILED_TASKS=0

while IFS='|' read -r wave_db_id wave_code wave_name wave_status; do
	echo ""
	log "=== Wave: $wave_code - $wave_name (status: $wave_status) ==="

	# Skip already-completed waves (unless --from forces re-entry)
	if [[ "$wave_status" == "done" && -z "$FROM_TASK" ]]; then
		success "Wave $wave_code already done — skipping"
		continue
	fi

	# Track whether any tasks ran in this wave
	wave_had_tasks=0
	wave_failed=0

	while IFS='|' read -r task_db_id task_code task_status task_title; do
		TOTAL_TASKS=$((TOTAL_TASKS + 1))

		# Resume: skip tasks before --from target
		if should_skip_task "$task_code"; then
			step "Skipping $task_code (before resume point)"
			SKIPPED_TASKS=$((SKIPPED_TASKS + 1))
			continue
		fi

		# Skip already-done tasks
		if [[ "$task_status" == "done" && -z "$FROM_TASK" ]]; then
			step "$task_code: already done — skipping"
			DONE_TASKS=$((DONE_TASKS + 1))
			continue
		fi

		# Skip blocked tasks
		if [[ "$task_status" == "blocked" ]]; then
			warn "$task_code: blocked — skipping"
			FAILED_TASKS=$((FAILED_TASKS + 1))
			wave_failed=$((wave_failed + 1))
			continue
		fi

		wave_had_tasks=1
		step "Executing $task_code: $(echo "$task_title" | cut -c1-60)"

		# Run the task
		task_exit=0
		run_task "$task_db_id" "$task_code" || task_exit=$?

		if [[ "$DRY_RUN" -eq 1 ]]; then
			DONE_TASKS=$((DONE_TASKS + 1))
			continue
		fi

		# Verify task status after execution
		new_status=$(db_query "SELECT status FROM tasks WHERE id=$task_db_id;")

		if [[ "$new_status" == "done" ]]; then
			# Run Thor per-task validation
			thor_exit=0
			validate_task "$task_db_id" "$task_code" || thor_exit=$?

			if [[ "$thor_exit" -ne 0 ]]; then
				warn "Task $task_code failed Thor validation — marked as needs-fix"
				FAILED_TASKS=$((FAILED_TASKS + 1))
				wave_failed=$((wave_failed + 1))
			else
				success "Task $task_code complete and validated"
				DONE_TASKS=$((DONE_TASKS + 1))
			fi
		else
			warn "Task $task_code ended with status=$new_status (exit=$task_exit)"
			FAILED_TASKS=$((FAILED_TASKS + 1))
			wave_failed=$((wave_failed + 1))
		fi

	done < <(get_wave_tasks "$wave_db_id")

	# Per-wave Thor validation (only if tasks ran and none failed)
	if [[ "$wave_had_tasks" -eq 1 && "$wave_failed" -eq 0 ]]; then
		echo ""
		thor_wave_exit=0
		validate_wave "$wave_db_id" "$wave_code" || thor_wave_exit=$?

		if [[ "$thor_wave_exit" -ne 0 ]]; then
			warn "Wave $wave_code failed Thor validation — stopping execution"
			error "Fix wave issues before continuing. Resume with: execute-plan.sh $PLAN_ID --from <first-failed-task>"
			break
		fi
	elif [[ "$wave_failed" -gt 0 ]]; then
		warn "Wave $wave_code had $wave_failed failed task(s) — skipping wave Thor validation"
	fi

done < <(get_waves)

# ============================================================================
# Summary
# ============================================================================
echo ""
log "=== EXECUTION SUMMARY ==="
log "  Total tasks:   $TOTAL_TASKS"
log "  Done:          $DONE_TASKS"
log "  Skipped:       $SKIPPED_TASKS"
log "  Failed:        $FAILED_TASKS"
log "  Log:           $LOG_FILE"
echo ""

if [[ "$FAILED_TASKS" -gt 0 ]]; then
	warn "$FAILED_TASKS task(s) failed or blocked"
	warn "Check log: $LOG_FILE"
	warn "Resume with: execute-plan.sh $PLAN_ID --from <task_id> --engine $ENGINE"
	exit 1
else
	success "Plan $PLAN_ID execution complete"
	exit 0
fi
