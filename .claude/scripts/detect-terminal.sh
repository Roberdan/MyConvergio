#!/bin/bash
# Detect terminal type for orchestration
# Returns: kitty, tmux, tmux-external, or plain

# Version: 1.0.0
if [ -n "$KITTY_PID" ]; then
    echo "kitty"
elif [ -n "$TMUX" ]; then
    echo "tmux"
elif command -v tmux &>/dev/null && tmux list-sessions &>/dev/null 2>&1; then
    echo "tmux-external"
else
    echo "plain"
fi
