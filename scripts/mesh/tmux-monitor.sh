#!/bin/bash
set -euo pipefail
# Monitor Claude workers in tmux session
# Usage: tmux-monitor.sh [session_name]

# Version: 1.0.0
SESSION="${1:-claude-workers}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[MONITOR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERR]${NC} $1"; }

# Check if session exists
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    error "Session '$SESSION' not found"
    echo "Available sessions:"
    tmux list-sessions 2>/dev/null || echo "  (none)"
    exit 1
fi

clear
echo "=========================================="
echo "  Claude Workers Monitor - tmux"
echo "  Session: $SESSION"
echo "=========================================="
echo ""

# List all windows
log "Windows in session:"
tmux list-windows -t "$SESSION" -F "  #I: #W (#{window_panes} pane(s))"

echo ""
log "Quick commands:"
echo "  tmux attach -t $SESSION          # Attach to session"
echo "  tmux select-window -t $SESSION:N # Switch to window N"
echo ""
echo "Send message to Claude-N:"
echo "  tmux send-keys -t $SESSION:Claude-N 'message' Enter"
echo ""

# Show last lines from each window
log "Last activity per window:"
for window in $(tmux list-windows -t "$SESSION" -F "#W"); do
    echo ""
    echo -e "${YELLOW}=== $window ===${NC}"
    tmux capture-pane -t "$SESSION:$window" -p | tail -5
done

echo ""
echo "=========================================="
echo "Press Ctrl+C to exit, or run with 'watch' for live updates:"
echo "  watch -n 5 ~/.claude/scripts/tmux-monitor.sh"
