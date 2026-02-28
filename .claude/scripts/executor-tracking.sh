#!/bin/bash
# Executor Tracking Helper Functions
# Source: source ~/.claude/scripts/executor-tracking.sh
# Version: 2.0.0 — removed web dashboard API, local logging only

export DB="$HOME/.claude/data/dashboard.db"
export EXECUTOR_PROJECT="" EXECUTOR_TASK_ID="" EXECUTOR_SESSION_ID=""

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/executor-tracking-lib.sh" 2>/dev/null || true

executor_start() {
	local project=$1 task_id=$2
	[ -z "$project" ] || [ -z "$task_id" ] && {
		echo -e "${RED}Usage: executor_start <project> <task_id>${NC}"
		return 1
	}
	export EXECUTOR_PROJECT="$project" EXECUTOR_TASK_ID="$task_id"
	export EXECUTOR_SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
	echo -e "${BLUE}Starting executor...${NC} Project: ${GREEN}${project}${NC} Task: ${GREEN}${task_id}${NC}"
}

executor_log() {
	local role=$1 content=$2
	[ -z "$EXECUTOR_PROJECT" ] && {
		echo -e "${YELLOW}Not initialized. Run executor_start first.${NC}"
		return 1
	}
	case "$role" in
	"user") echo -e "${BLUE}[USER]${NC} $2" ;;
	"assistant") echo -e "${GREEN}[ASSISTANT]${NC} $2" ;;
	"tool") echo -e "${YELLOW}[TOOL: ${3:-}]${NC}" ;;
	"system") echo -e "${RED}[SYSTEM]${NC} $2" ;;
	esac
}

executor_log_tool() { executor_log "tool" "" "$1"; }

executor_complete() {
	local status=${1:-"success"}
	[ -z "$EXECUTOR_PROJECT" ] && {
		echo -e "${YELLOW}Not initialized${NC}"
		return 1
	}
	echo -e "${GREEN}Task ${status}${NC}"
	export EXECUTOR_PROJECT="" EXECUTOR_TASK_ID="" EXECUTOR_SESSION_ID=""
}

executor_status() {
	echo -e "${BLUE}Executor Status${NC}"
	echo -e "  Project: ${GREEN}${EXECUTOR_PROJECT:-Not set}${NC}"
	echo -e "  Task: ${GREEN}${EXECUTOR_TASK_ID:-Not set}${NC}"
	echo -e "  Session: ${GREEN}${EXECUTOR_SESSION_ID:-Not set}${NC}"
	[ -n "$EXECUTOR_PROJECT" ] && echo -e "  View: piani -p \$PLAN_ID"
}

executor_help() {
	cat <<'EOF'
EXECUTOR TRACKING - Usage:

  source ~/.claude/scripts/executor-tracking.sh

  executor_start "project" "T01"    # Start tracking
  executor_log "user" "message"     # Log user message
  executor_log "assistant" "msg"    # Log assistant message
  executor_log_tool "Read"          # Log tool call
  executor_status                   # Check status
  executor_complete success         # Complete (or: failed)

Dashboard: piani (terminal)
EOF
}

[ -z "$EXECUTOR_QUIET" ] && echo -e "${GREEN}Executor functions loaded${NC} - Run ${BLUE}executor_help${NC} for usage"
