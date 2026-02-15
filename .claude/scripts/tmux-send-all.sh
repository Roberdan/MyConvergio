#!/bin/bash
# Send a message to all Claude workers in tmux
# Usage: tmux-send-all.sh "message"

# Version: 1.1.0
set -euo pipefail

SESSION="claude-workers"
MESSAGE="${1:-}"

if [ -z "$MESSAGE" ]; then
	echo "Usage: tmux-send-all.sh \"message\""
	exit 1
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
	echo "Error: Session '$SESSION' not found"
	exit 1
fi

# Get all Claude windows
while IFS= read -r window; do
	[ -z "$window" ] && continue
	echo "Sending to $window..."
	if ! tmux send-keys -t "$SESSION:$window" "$MESSAGE" Enter 2>/dev/null; then
		echo "Warning: Failed to send to window $window" >&2
	fi
done < <(tmux list-windows -t "$SESSION" -F "#W" | grep -E "^Claude-")

echo "Message sent to all workers"
