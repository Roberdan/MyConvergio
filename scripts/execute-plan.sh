#!/bin/bash
set -euo pipefail
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

# Version: 2.1.0 - PATH hardening, process cleanup, wave-stop-on-fail
set -euo pipefail

# PATH hardening: ensure all tools are findable in non-login SSH shells
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:$HOME/.claude/scripts:$PATH"

EXECUTE_PLAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${HOME}/.claude/data/dashboard.db"
LOG_DIR="${HOME}/.claude/logs/execute-plan"

# Track child processes for cleanup on exit/signal
_EXEC_CHILD_PIDS=()
_exec_cleanup() {
	if [[ ${#_EXEC_CHILD_PIDS[@]} -gt 0 ]]; then
		for pid in "${_EXEC_CHILD_PIDS[@]}"; do
			kill -9 "$pid" 2>/dev/null || true
			pkill -9 -P "$pid" 2>/dev/null || true
		done
	fi
	# Kill any remaining copilot processes spawned by this executor
	pkill -9 -P $$ 2>/dev/null || true
}
trap _exec_cleanup EXIT INT TERM

# Source shared libraries
source "${EXECUTE_PLAN_DIR}/lib/common.sh"
source "${EXECUTE_PLAN_DIR}/lib/execute-plan-engine.sh"

# Override log function for executor-specific prefix
log() { echo -e "${BLUE}[EXECUTOR]${NC} $1"; }

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
  --engine <engine>         auto|claude|copilot|opencode (default: auto)
  --model <model>           Model override (e.g. claude-opus-4-6, gpt-5.3-codex)
  --timeout <seconds>       Per-task timeout in seconds (default: 900)
  --dry-run                 Show what would be executed without running
  --help                    Show this help

  Engine 'auto' picks first authenticated CLI: claude > copilot > opencode

EXAMPLES:
  execute-plan.sh 180
  execute-plan.sh 180 --from T1-03
  execute-plan.sh 180 --engine copilot --model gpt-5.3-codex
EOF
	exit 0
fi

FROM_TASK=""
ENGINE="auto"
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

# Enforce execution_host: one plan = one machine
PLAN_HOST=$(sqlite3 "$DB_FILE" "SELECT execution_host FROM plans WHERE id=$PLAN_ID;" 2>/dev/null || echo "")
if [[ -n "$PLAN_HOST" && "$PLAN_HOST" != "$(hostname -s)" ]]; then
	# Check peer name from peers.conf
	local_peer=""
	if [[ -f "${CLAUDE_HOME:-$HOME/.claude}/config/peers.conf" ]]; then
		source "${EXECUTE_PLAN_DIR}/lib/peers.sh" 2>/dev/null || true
		peers_load 2>/dev/null || true
		local_peer="$(peers_self 2>/dev/null || echo "")"
	fi
	if [[ "$PLAN_HOST" != "$local_peer" && "$PLAN_HOST" != "local" ]]; then
		error "Plan $PLAN_ID is assigned to '$PLAN_HOST', not this machine ('${local_peer:-$(hostname -s)}')"
		error "Use: ssh $PLAN_HOST 'execute-plan.sh $PLAN_ID'"
		exit 1
	fi
fi

# ============================================================================
# Engine availability checks
# ============================================================================
DELEGATE_SH="${EXECUTE_PLAN_DIR}/delegate.sh"
COPILOT_WORKER="${EXECUTE_PLAN_DIR}/copilot-worker.sh"

check_engine() {
	# Auto-detect: pick the first available authenticated engine
	if [[ "$ENGINE" == "auto" ]]; then
		if command -v claude &>/dev/null && claude auth status 2>/dev/null | grep -q '"loggedIn": true'; then
			ENGINE="claude"
			log "Auto-detected engine: claude"
		elif command -v copilot &>/dev/null && (gh auth status &>/dev/null 2>&1 || [[ -n "${GH_TOKEN:-}" ]]); then
			ENGINE="copilot"
			log "Auto-detected engine: copilot (claude not authenticated)"
		elif command -v opencode &>/dev/null; then
			ENGINE="opencode"
			log "Auto-detected engine: opencode (claude/copilot unavailable)"
		else
			error "No authenticated engine found. Run 'claude login', 'gh auth login', or install opencode."
			exit 1
		fi
	fi
	case "$ENGINE" in
	claude)
		if ! command -v claude &>/dev/null; then
			error "claude CLI not found (install or use --engine copilot|opencode)"
			exit 1
		fi
		if ! claude auth status 2>/dev/null | grep -q '"loggedIn": true'; then
			warn "Claude not authenticated — falling back to copilot"
			ENGINE="copilot"
			check_engine
			return
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
		error "Unknown engine: $ENGINE. Use: auto|claude|copilot|opencode"
		exit 1
		;;
	esac
}

check_engine

# ============================================================================
# Preflight: verify required tools, auto-install if possible
# ============================================================================
_preflight_check() {
	local missing=() fixed=()
	for cmd in git sqlite3 node; do
		command -v "$cmd" &>/dev/null || missing+=("$cmd")
	done
	if ! command -v pnpm &>/dev/null; then
		warn "pnpm missing — auto-installing..."
		npm install -g pnpm &>/dev/null && fixed+=("pnpm") || missing+=("pnpm")
		export PATH="$HOME/.npm-global/bin:$PATH"
	fi
	if ! command -v ruff &>/dev/null; then
		warn "ruff missing — auto-installing..."
		(curl -LsSf https://astral.sh/ruff/install.sh | sh) &>/dev/null && fixed+=("ruff") || missing+=("ruff")
		export PATH="$HOME/.local/bin:$PATH"
	fi
	[[ ${#fixed[@]} -gt 0 ]] && log "Auto-installed: ${fixed[*]}"
	if [[ ${#missing[@]} -gt 0 ]]; then
		error "Missing required tools: ${missing[*]}"
		exit 1
	fi
}
_preflight_check

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

# Initialize resume logic if needed
[[ -n "$FROM_TASK" ]] && init_resume "$FROM_TASK"

# ============================================================================
# Main execution
# ============================================================================
execute_plan_waves
exit $?
