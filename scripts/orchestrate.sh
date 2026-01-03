#!/bin/bash
# Multi-Claude Orchestrator - Run FROM Kitty terminal
# Usage: ~/.claude/scripts/orchestrate.sh <plan-file> [num-workers]
#
# Prerequisites:
#   1. Run from inside Kitty terminal
#   2. Kitty config: allow_remote_control yes
#   3. wildClaude alias available

set -e

PLAN="${1:?Usage: orchestrate.sh <plan-file> [num-workers]}"
NUM_WORKERS="${2:-4}"
DIR="$(pwd)"

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
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Verify we're in Kitty
check_kitty() {
    if [ -z "$KITTY_PID" ]; then
        error "Must run FROM INSIDE Kitty terminal!

Open Kitty and run this script from there."
    fi

    if ! kitty @ ls &>/dev/null; then
        error "Kitty remote control not enabled!

Add to ~/.config/kitty/kitty.conf:
  allow_remote_control yes
  listen_on unix:/tmp/kitty-socket

Then restart Kitty."
    fi

    success "Kitty remote control active"
}

# Check wildClaude alias
check_wildclaude() {
    if ! command -v wildClaude &>/dev/null && ! alias wildClaude &>/dev/null; then
        warn "wildClaude alias not found, using: claude --dangerously-skip-permissions"
        CLAUDE_CMD="claude --dangerously-skip-permissions"
    else
        CLAUDE_CMD="wildClaude"
    fi
    success "Claude command: $CLAUDE_CMD"
}

# Launch a Claude worker in a new tab
launch_worker() {
    local name="$1"
    local task="$2"

    log "Launching $name..."

    # Launch in new tab with wildClaude
    kitty @ launch --type=tab --title="$name" --cwd="$DIR" --keep-focus \
        zsh -ic "$CLAUDE_CMD"

    sleep 3  # Wait for Claude to initialize

    # Send the task
    kitty @ send-text --match "title:^${name}$" "$task
"

    success "Task sent to $name"
}

# Read output from a worker
read_worker() {
    local name="$1"
    kitty @ get-text --match "title:^${name}$" --extent=screen 2>/dev/null
}

# Check if worker completed
is_complete() {
    local name="$1"
    local output=$(read_worker "$name")

    if echo "$output" | grep -qE "✅|DONE|All.*complete|tasks? complete"; then
        return 0
    fi
    return 1
}

# Check if worker has error
has_error() {
    local name="$1"
    local output=$(read_worker "$name")

    if echo "$output" | grep -qiE "error:|failed|Error:|FAILED"; then
        return 0
    fi
    return 1
}

# Monitor all workers
monitor_workers() {
    local workers=("$@")

    log "Monitoring ${#workers[@]} workers..."
    echo ""

    while true; do
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

# Parse plan file for task assignments
parse_plan() {
    local plan_file="$1"

    if [ ! -f "$plan_file" ]; then
        error "Plan file not found: $plan_file"
    fi

    # Extract CLAUDE assignments from plan
    # Format: | CLAUDE X | task description |
    grep -E "CLAUDE.[0-9]" "$plan_file" | head -$NUM_WORKERS
}

# Main
main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         MULTI-CLAUDE ORCHESTRATOR                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log "Plan: $PLAN"
    log "Workers: $NUM_WORKERS"
    log "Directory: $DIR"
    echo ""

    check_kitty
    check_wildclaude

    echo ""
    log "Launching workers..."
    echo ""

    # Define worker tasks (customize based on plan structure)
    declare -a WORKERS

    for i in $(seq 2 $((NUM_WORKERS + 1))); do
        local worker_name="Claude-$i"
        local task="Leggi $PLAN - sei CLAUDE $i. Esegui TUTTI i task assegnati a te. Quando hai finito scrivi DONE."

        launch_worker "$worker_name" "$task"
        WORKERS+=("$worker_name")

        sleep 2  # Stagger launches
    done

    echo ""
    log "All workers launched!"
    echo ""
    echo -e "${CYAN}Keyboard shortcuts:${NC}"
    echo "  Cmd+1/2/3/4  - Switch to tab"
    echo "  Cmd+Shift+L  - Grid layout (see all)"
    echo "  Cmd+Shift+.  - Tab overview"
    echo ""

    # Start monitoring
    monitor_workers "${WORKERS[@]}"

    echo ""
    log "Running final verification..."
    npm run lint && npm run typecheck && npm run build

    echo ""
    success "Orchestration complete!"
}

main "$@"
