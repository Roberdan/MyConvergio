#!/bin/bash
# Multi-Worker Orchestrator - Run FROM Kitty terminal
# Multi-Worker Orchestrator - Run FROM Kitty terminal
# Usage: orchestrate.sh <plan-file> [num-workers] [--engine claude|copilot|mixed] [--use-delegate]
#
# Prerequisites:
#   1. Run from inside Kitty terminal
#   2. Kitty config: allow_remote_control yes
#   3. wildClaude alias (for claude engine)
#   4. copilot CLI + GH_TOKEN (for copilot engine)
#   5. [--use-delegate]: When enabled, each worker tab runs 'delegate.sh $TASK_ID' instead of hardcoded CLI. Default: off (backward compatible).
#   6. This flag is backward compatible and does not affect default behavior unless specified.
#
# Example:
#   orchestrate.sh plan.yaml 4 --engine claude --use-delegate

# Version: 1.1.0
set -euo pipefail

PLAN=""
NUM_WORKERS=4
ENGINE="claude"
DIR="$(pwd)"

# Parse args (positional + flags)
USE_DELEGATE=0
while [[ $# -gt 0 ]]; do
	case $1 in
	--engine)
		ENGINE="$2"
		shift 2
		;;
	--cwd)
		DIR="$2"
		shift 2
		;;
	--use-delegate)
		USE_DELEGATE=1
		shift
		;;
	--*) shift 2 ;;
	*)
		if [[ -z "$PLAN" ]]; then
			PLAN="$1"
		else NUM_WORKERS="$1"; fi
		shift
		;;
	esac
done

[[ -z "$PLAN" ]] && {
	echo "Usage: orchestrate.sh <plan-file> [num-workers] [--engine claude|copilot|mixed]" >&2
	exit 1
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[ORCHESTRATOR]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() {
	echo -e "${RED}[✗]${NC} $1"
	exit 1
}

# Verify Kitty + resolve commands
check_kitty() {
	[[ -z "$KITTY_PID" ]] && error "Must run from inside Kitty terminal"
	kitty @ ls &>/dev/null || error "Kitty remote control not enabled (allow_remote_control yes)"
	success "Kitty remote control active"
}

check_wildclaude() {
	CLAUDE_CMD="claude --dangerously-skip-permissions"
	command -v wildClaude &>/dev/null && CLAUDE_CMD="wildClaude"
	success "Claude: $CLAUDE_CMD"
}

# Worker lifecycle
launch_worker() {
	local name="$1" task="$2"
	log "Launching $name..."
	if [[ "$USE_DELEGATE" == "1" ]]; then
		kitty @ launch --type=tab --title="$name" --cwd="$DIR" --keep-focus zsh -ic "./scripts/delegate.sh '$task' # --use-delegate flag enabled"
		# When --use-delegate is enabled, each worker tab runs 'delegate.sh $TASK_ID' instead of hardcoded CLI.
	else
		kitty @ launch --type=tab --title="$name" --cwd="$DIR" --keep-focus zsh -ic "$CLAUDE_CMD"
		sleep 3
		kitty @ send-text --match "title:^${name}$" "$task
"
	fi
	success "$name launched"
}

read_worker() { kitty @ get-text --match "title:^${1}$" --extent=screen 2>/dev/null; }

is_complete() {
	local output
	output=$(read_worker "$1")
	echo "$output" | grep -qE "^DONE$|^### WORKER DONE ###$"
}

has_error() {
	local output
	output=$(read_worker "$1")
	echo "$output" | grep -qiE "error:|failed|FAILED"
}

# Monitor all workers
monitor_workers() {
	local workers=("$@")

	local max_wait="${ORCHESTRATE_TIMEOUT:-3600}"
	local start_time
	start_time=$(date +%s)

	log "Monitoring ${#workers[@]} workers... (timeout: ${max_wait}s)"
	echo ""

	while true; do
		local elapsed=$(($(date +%s) - start_time))
		if [[ $elapsed -gt $max_wait ]]; then
			echo ""
			error "Timeout after ${max_wait}s waiting for workers"
			break
		fi

		local all_done=true
		local status_line=""

		for worker in "${workers[@]}"; do
			if is_complete "$worker"; then
				status_line+="${GREEN}✓${NC} $worker  "
			elif has_error "$worker"; then
				status_line+="${RED}✗${NC} $worker  "
			else
				status_line+="${YELLOW}⋯${NC} $worker  "
				all_done=false
			fi
		done

		echo -ne "\r$status_line"

		if $all_done; then
			echo ""
			success "All workers completed!"
			break
		fi

		sleep 10
	done
}

# Copilot worker (yolo mode — full autonomy, no confirmations)
launch_copilot_worker() {
	local name="$1" task="$2" model="${3:-claude-opus-4-6}"
	log "Launching Copilot: $name..."
	kitty @ launch --type=tab --title="$name" --cwd="$DIR" --keep-focus \
		zsh -ic "copilot --yolo --add-dir '$DIR' --model $model -p '$(echo "$task" | sed "s/'/'\\\\''/g")'"
	success "$name launched"
}

# Mixed mode: resolve engine by task metadata
resolve_engine() {
	echo "$1" | grep -qi "codex:.*true\|copilot:.*true" && echo "copilot" || echo "claude"
}

# Main
main() {
	log "=== ORCHESTRATOR: $ENGINE | $NUM_WORKERS workers | $PLAN ==="

	check_kitty

	if [[ "$ENGINE" == "claude" || "$ENGINE" == "mixed" ]]; then
		check_wildclaude
	fi
	if [[ "$ENGINE" == "copilot" || "$ENGINE" == "mixed" ]]; then
		command -v copilot &>/dev/null || error "copilot CLI not installed"
		[[ -n "${GH_TOKEN:-}${COPILOT_TOKEN:-}" ]] || error "GH_TOKEN or COPILOT_TOKEN required"
		success "Copilot CLI available"
	fi

	echo ""
	log "Launching workers..."
	echo ""

	declare -a WORKERS
	for i in $(seq 2 $((NUM_WORKERS + 1))); do
		local task="Leggi $PLAN - sei WORKER $i. Esegui TUTTI i task assegnati a te. Quando hai finito scrivi DONE."
		local worker_type="$ENGINE"

		if [[ "$ENGINE" == "mixed" ]]; then
			worker_type=$(resolve_engine "$task")
		fi

		local prefix="Claude"
		[[ "$worker_type" == "copilot" ]] && prefix="Copilot"
		local worker_name="${prefix}-${i}"

		if [[ "$worker_type" == "copilot" ]]; then
			launch_copilot_worker "$worker_name" "$task"
		else
			launch_worker "$worker_name" "$task"
		fi

		WORKERS+=("$worker_name")
		sleep 2
	done

	log "All ${#WORKERS[@]} workers launched. Cmd+Shift+L for grid view."
	monitor_workers "${WORKERS[@]}"
	log "Final verification..."
	local verify_output
	if [[ -x "./scripts/ci-summary.sh" ]]; then
		verify_output=$(./scripts/ci-summary.sh --quick 2>&1) || {
			warn "Verification failed:"
			echo "$verify_output" | tail -5
		}
	else
		verify_output=$(npm run lint 2>&1 && npm run typecheck 2>&1 && npm run build 2>&1) || {
			warn "Verification failed:"
			echo "$verify_output" | tail -5
		}
	fi
	success "Orchestration complete!"
}

main
