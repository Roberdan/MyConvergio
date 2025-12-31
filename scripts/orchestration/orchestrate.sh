#!/bin/bash
# Full orchestration script - auto-detects terminal and launches workers
# Usage: orchestrate.sh [num_workers] [plan_file]
#
# This script:
# 1. Detects if running in Kitty or needs tmux
# 2. Launches Claude workers
# 3. Optionally sends a plan file to each worker

NUM="${1:-4}"
PLAN="${2:-}"
DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[ORCHESTRATE]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Detect terminal
TERMINAL=$("$SCRIPT_DIR/detect-terminal.sh")
log "Detected terminal: $TERMINAL"

case "$TERMINAL" in
    kitty)
        log "Using Kitty remote control"
        "$SCRIPT_DIR/kitty-check.sh" || error "Kitty remote control not configured"
        "$SCRIPT_DIR/claude-parallel.sh" "$NUM"

        # Send plan if provided
        if [ -n "$PLAN" ] && [ -f "$PLAN" ]; then
            log "Sending plan to workers..."
            for i in $(seq 2 $NUM); do
                kitty @ send-text --match title:Claude-$i "Leggi $PLAN, sei CLAUDE $i. Esegui i tuoi task."
                kitty @ send-key --match title:Claude-$i Return
            done
        fi
        ;;

    tmux|tmux-external)
        log "Using tmux"
        "$SCRIPT_DIR/tmux-parallel.sh" "$NUM" "$DIR"

        # Send plan if provided
        if [ -n "$PLAN" ] && [ -f "$PLAN" ]; then
            log "Sending plan to workers..."
            sleep 3  # Wait for Claude instances to start
            for i in $(seq 2 $NUM); do
                tmux send-keys -t claude-workers:Claude-$i "Leggi $PLAN, sei CLAUDE $i. Esegui i tuoi task." Enter
            done
        fi

        echo ""
        log "Attaching to tmux session..."
        sleep 2
        tmux attach -t claude-workers
        ;;

    plain)
        error "No orchestration terminal available. Install tmux: brew install tmux"
        ;;
esac

success "Orchestration complete"
