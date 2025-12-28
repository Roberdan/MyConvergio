#!/bin/bash
# Launch N parallel Claude instances in Kitty tabs
# Usage: claude-parallel.sh [num] [directory]
#
# REQUIRES: Kitty terminal with remote control enabled
# See: scripts/orchestration/README.md

NUM="${1:-4}"
DIR="${2:-$(pwd)}"

if [ -z "$KITTY_PID" ]; then
    echo "❌ Error: Run from inside Kitty terminal (not Warp/iTerm)"
    echo ""
    echo "This script requires Kitty terminal with remote control."
    echo "See: scripts/orchestration/README.md"
    exit 1
fi

echo "Launching $NUM Claude instances in $DIR"

for i in $(seq 1 $NUM); do
    echo "  → Claude-$i"
    kitty @ launch --type=tab --title="Claude-$i" --cwd="$DIR" --keep-focus \
        zsh -ic "wildClaude"
done

echo ""
echo "Done! Use Cmd+1/2/3/4 to switch tabs"
echo "Or Cmd+Shift+L for grid layout"
