#!/bin/bash
# Monitor running Claude/Copilot workers in Kitty tabs
# Usage: claude-monitor.sh [refresh-seconds]

# Version: 1.1.0
set -euo pipefail

REFRESH="${1:-5}"

if [ -z "$KITTY_PID" ]; then
	echo "Error: Run from inside Kitty terminal"
	exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

while true; do
	clear
	echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
	echo -e "${CYAN}  WORKER STATUS  $(date '+%H:%M:%S')${NC}"
	echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
	echo ""

	# Match both Claude-N and Copilot-N tabs
	while IFS= read -r tab; do
		[[ -z "$tab" ]] && continue
		output=""
		output=$(kitty @ get-text --match "title:$tab" --extent=screen 2>/dev/null | tail -10)

		# Worker type indicator
		type_color="$CYAN"
		[[ "$tab" == Copilot-* ]] && type_color="$MAGENTA"

		# Determine status
		status=""
		if echo "$output" | grep -qE "DONE|complete|All.*tasks"; then
			status="${GREEN}COMPLETE${NC}"
		elif echo "$output" | grep -qiE "error:|failed|FAILED|BLOCKED"; then
			status="${RED}ERROR${NC}"
		elif echo "$output" | grep -qE "Working|in_progress|Running|plan-db"; then
			status="${YELLOW}WORKING${NC}"
		elif [[ -z "$output" ]] || echo "$output" | grep -qE "Approve|confirm|y/n"; then
			status="${RED}STUCK${NC}"
		else
			status="${CYAN}ACTIVE${NC}"
		fi

		echo -e "  ${type_color}$tab${NC}: $status"

		last_line=""
		last_line=$(echo "$output" | grep -v "^$" | tail -1 | cut -c1-60)
		[[ -n "$last_line" ]] && echo -e "    $last_line"
		echo ""
	done < <(kitty @ ls 2>/dev/null | grep -oE '"title": "(Claude|Copilot)-[0-9]+"' | grep -oE '(Claude|Copilot)-[0-9]+')

	# DB-backed progress if available
	DB="$HOME/.claude/data/dashboard.db"
	if [[ -f "$DB" ]]; then
		active=0
		done_t=0
		active=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='in_progress';" 2>/dev/null || echo 0)
		done_t=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='done' AND completed_at > datetime('now','-1 hour');" 2>/dev/null || echo 0)
		[[ "$active" -gt 0 || "$done_t" -gt 0 ]] && echo -e "  ${YELLOW}DB: ${active} active, ${done_t} done (1h)${NC}"
	fi

	echo ""
	echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
	echo "  Ctrl+C to stop | Refresh: ${REFRESH}s"

	sleep "$REFRESH"
done
