#!/bin/bash
set -euo pipefail
# Real-time execution monitor for plan tasks
# Usage: execution-monitor.sh [plan_id] [refresh_seconds]
# Works in any terminal (not just Kitty)

# Version: 1.1.0
set -euo pipefail

PLAN_ID="${1:-}"
REFRESH="${2:-3}"
DB="$HOME/.claude/data/dashboard.db"
API="${DASHBOARD_API:-http://localhost:31415/api}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:31415}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Progress bar function
progress_bar() {
	local done=$1
	local total=$2
	local width=20
	[ "$total" -eq 0 ] && total=1
	local pct=$((done * 100 / total))
	local filled=$((done * width / total))
	local empty=$((width - filled))
	printf "%s%s %d%%" "$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))" "$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))" "$pct"
}

# Check database
if [ ! -f "$DB" ]; then
	echo -e "${RED}Error: Database not found at $DB${NC}"
	exit 1
fi

# Get latest plan if not specified
if [ -z "$PLAN_ID" ]; then
	PLAN_ID=$(sqlite3 "$DB" "SELECT id FROM plans WHERE status='doing' ORDER BY id DESC LIMIT 1;" 2>/dev/null)
	[ -z "$PLAN_ID" ] && PLAN_ID=$(sqlite3 "$DB" "SELECT id FROM plans ORDER BY id DESC LIMIT 1;" 2>/dev/null)
fi

if [ -z "$PLAN_ID" ]; then
	echo -e "${RED}Error: No plan found. Usage: $0 [plan_id]${NC}"
	exit 1
fi

# Main monitoring loop
while true; do
	clear

	# Get plan info
	PLAN_INFO=$(sqlite3 -separator '|' "$DB" \
		"SELECT name, status, tasks_done, tasks_total, project_id FROM plans WHERE id=$PLAN_ID;" 2>/dev/null)

	if [ -z "$PLAN_INFO" ]; then
		echo -e "${RED}Error: Plan $PLAN_ID not found${NC}"
		exit 1
	fi

	PLAN_NAME=$(echo "$PLAN_INFO" | cut -d'|' -f1)
	PLAN_STATUS=$(echo "$PLAN_INFO" | cut -d'|' -f2)
	TASKS_DONE=$(echo "$PLAN_INFO" | cut -d'|' -f3)
	TASKS_TOTAL=$(echo "$PLAN_INFO" | cut -d'|' -f4)
	PROJECT_ID=$(echo "$PLAN_INFO" | cut -d'|' -f5)

	# Header
	echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
	echo -e "${CYAN}  ${BOLD}EXECUTION MONITOR${NC}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
	echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
	echo ""

	# Plan status
	case "$PLAN_STATUS" in
	"doing") STATUS_COLOR="${YELLOW}🔄 IN FLIGHT${NC}" ;;
	"done") STATUS_COLOR="${GREEN}✅ COMPLETE${NC}" ;;
	"todo") STATUS_COLOR="${BLUE}⏳ PENDING${NC}" ;;
	*) STATUS_COLOR="${NC}$PLAN_STATUS${NC}" ;;
	esac

	echo -e "  ${BOLD}Plan:${NC} $PLAN_NAME (ID: $PLAN_ID)"
	echo -e "  ${BOLD}Project:${NC} $PROJECT_ID"
	echo -e "  ${BOLD}Status:${NC} $STATUS_COLOR"
	echo -e "  ${BOLD}Progress:${NC} $(progress_bar $TASKS_DONE $TASKS_TOTAL) ($TASKS_DONE/$TASKS_TOTAL)"
	echo ""

	# Waves section
	echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
	echo -e "  ${BOLD}WAVES${NC}"
	echo ""

	sqlite3 -separator '|' "$DB" \
		"SELECT wave_id, name, status, tasks_done, tasks_total FROM waves WHERE plan_id=$PLAN_ID ORDER BY position;" 2>/dev/null |
		while IFS='|' read -r WAVE_ID WAVE_NAME WAVE_STATUS WAVE_DONE WAVE_TOTAL; do
			case "$WAVE_STATUS" in
			"done") W_ICON="${GREEN}✓${NC}" ;;
			"doing") W_ICON="${YELLOW}→${NC}" ;;
			*) W_ICON="${BLUE}○${NC}" ;;
			esac
			echo -e "  $W_ICON ${BOLD}$WAVE_ID${NC}: $WAVE_NAME ($WAVE_DONE/$WAVE_TOTAL)"
		done
	echo ""

	# Active/Recent tasks
	echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
	echo -e "  ${BOLD}RECENT TASKS${NC}"
	echo ""

	# Show in_progress tasks first, then recent done tasks
	sqlite3 -separator '|' "$DB" "
        SELECT task_id, title, status, tokens,
               COALESCE(started_at, '') as started,
               COALESCE(completed_at, '') as completed
        FROM tasks
        WHERE plan_id=$PLAN_ID
        ORDER BY
            CASE status WHEN 'in_progress' THEN 0 ELSE 1 END,
            COALESCE(completed_at, started_at) DESC
        LIMIT 8;
    " 2>/dev/null |
		while IFS='|' read -r TASK_ID TITLE STATUS TOKENS STARTED COMPLETED; do
			# Truncate title
			SHORT_TITLE=$(echo "$TITLE" | cut -c1-40)
			[ ${#TITLE} -gt 40 ] && SHORT_TITLE="${SHORT_TITLE}..."

			case "$STATUS" in
			"done")
				T_ICON="${GREEN}✓${NC}"
				TOKEN_INFO="${CYAN}${TOKENS}t${NC}"
				;;
			"in_progress")
				T_ICON="${YELLOW}▶${NC}"
				TOKEN_INFO="${YELLOW}running${NC}"
				;;
			"blocked")
				T_ICON="${RED}✗${NC}"
				TOKEN_INFO="${RED}blocked${NC}"
				;;
			*)
				T_ICON="${BLUE}○${NC}"
				TOKEN_INFO=""
				;;
			esac

			printf "  %b %-8s %s" "$T_ICON" "$TASK_ID" "$SHORT_TITLE"
			[ -n "$TOKEN_INFO" ] && printf " [%b]" "$TOKEN_INFO"
			echo ""
		done
	echo ""

	# Token usage
	TOTAL_TOKENS=$(sqlite3 "$DB" "SELECT COALESCE(SUM(tokens), 0) FROM tasks WHERE plan_id=$PLAN_ID;" 2>/dev/null)
	echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
	echo -e "  ${BOLD}Tokens Used:${NC} ${TOTAL_TOKENS}"

	# Dashboard link
	echo -e "  ${BOLD}Dashboard:${NC} ${DASHBOARD_URL}?project=$PROJECT_ID&plan=$PLAN_ID"
	echo ""

	# Footer
	echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
	echo -e "  Refresh: ${REFRESH}s | Press ${BOLD}Ctrl+C${NC} to exit | ${BOLD}q${NC}+Enter to quit"

	# Non-blocking read for quit
	read -t "$REFRESH" -n1 key 2>/dev/null
	[ "$key" = "q" ] && break
done

echo -e "\n${GREEN}Monitor stopped${NC}"
