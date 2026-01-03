#!/bin/bash
# Send a message to all Claude workers in tmux
# Usage: tmux-send-all.sh "message"

SESSION="claude-workers"
MESSAGE="$1"

if [ -z "$MESSAGE" ]; then
    echo "Usage: tmux-send-all.sh \"message\""
    exit 1
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Error: Session '$SESSION' not found"
    exit 1
fi

# Get all Claude windows
for window in $(tmux list-windows -t "$SESSION" -F "#W" | grep -E "^Claude-"); do
    echo "Sending to $window..."
    tmux send-keys -t "$SESSION:$window" "$MESSAGE" Enter
done

echo "Message sent to all workers"
