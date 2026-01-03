#!/bin/bash
# Monitor running Claude instances in Kitty tabs
# Usage: claude-monitor.sh [refresh-seconds]

REFRESH="${1:-5}"

if [ -z "$KITTY_PID" ]; then
    echo "Error: Run from inside Kitty terminal"
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  CLAUDE WORKERS STATUS  $(date '+%H:%M:%S')${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    # Get all Claude tabs
    for tab in $(kitty @ ls 2>/dev/null | grep -o '"title": "Claude-[0-9]*"' | grep -o 'Claude-[0-9]*'); do
        output=$(kitty @ get-text --match "title:$tab" --extent=screen 2>/dev/null | tail -10)

        # Determine status
        if echo "$output" | grep -qE "✅|DONE|complete"; then
            status="${GREEN}✓ COMPLETE${NC}"
        elif echo "$output" | grep -qiE "error|failed"; then
            status="${RED}✗ ERROR${NC}"
        elif echo "$output" | grep -qE "Working on|in_progress|Running"; then
            status="${YELLOW}⋯ WORKING${NC}"
        else
            status="${CYAN}◉ ACTIVE${NC}"
        fi

        echo -e "  $tab: $status"

        # Show last meaningful line
        last_line=$(echo "$output" | grep -v "^$" | tail -1 | cut -c1-60)
        if [ -n "$last_line" ]; then
            echo -e "    └─ $last_line..."
        fi
        echo ""
    done

    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo "  Press Ctrl+C to stop monitoring"
    echo "  Refresh every ${REFRESH}s"

    sleep $REFRESH
done
