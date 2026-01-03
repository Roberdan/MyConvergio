#!/bin/bash
# Launch N parallel Claude instances in tmux windows
# Usage: tmux-parallel.sh [num] [directory]
# Works from ANY terminal (including Zed)

NUM="${1:-4}"
DIR="${2:-$(pwd)}"
SESSION="claude-workers"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[TMUX]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }

# Check tmux
if ! command -v tmux &>/dev/null; then
    echo "Error: tmux not installed. Run: brew install tmux"
    exit 1
fi

# Kill existing session if exists
tmux kill-session -t "$SESSION" 2>/dev/null

log "Creating tmux session: $SESSION"
log "Launching $NUM Claude instances in $DIR"

# Create session with first window
tmux new-session -d -s "$SESSION" -n "Claude-1" -c "$DIR"
tmux send-keys -t "$SESSION:Claude-1" "claude --dangerously-skip-permissions" Enter

# Create additional windows
for i in $(seq 2 $NUM); do
    log "  → Claude-$i"
    tmux new-window -t "$SESSION" -n "Claude-$i" -c "$DIR"
    tmux send-keys -t "$SESSION:Claude-$i" "claude --dangerously-skip-permissions" Enter
    sleep 1
done

echo ""
success "All $NUM Claude instances launched!"
echo ""
echo "Commands:"
echo "  tmux attach -t $SESSION          # Attach to session"
echo "  tmux select-window -t $SESSION:1 # Switch to window 1"
echo ""
echo "Send commands from ANY terminal:"
echo "  tmux send-keys -t $SESSION:Claude-1 'your task' Enter"
echo ""
