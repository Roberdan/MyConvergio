#!/bin/bash
# Executor Tracking Helper Functions
# Source: source ~/.claude/scripts/executor-tracking.sh
# Requires: executor-tracking-lib.sh (auto-sourced)

# Configuration
# Version: 1.1.0
export DASHBOARD_API="http://localhost:31415/api"
export EXECUTOR_PROJECT="" EXECUTOR_TASK_ID="" EXECUTOR_SESSION_ID="" HEARTBEAT_PID=""

# Colors
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/executor-tracking-lib.sh" 2>/dev/null || true

# Initialize executor tracking
# Usage: executor_start <project> <task_id>
executor_start() {
	local project=$1 task_id=$2
	[ -z "$project" ] || [ -z "$task_id" ] && {
		echo -e "${RED}Usage: executor_start <project> <task_id>${NC}"
		return 1
	}

	export EXECUTOR_PROJECT="$project" EXECUTOR_TASK_ID="$task_id"
	export EXECUTOR_SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

	echo -e "${BLUE}Starting executor...${NC} Project: ${GREEN}${project}${NC} Task: ${GREEN}${task_id}${NC}"

	curl -s -X POST "${DASHBOARD_API}/project/${project}/task/${task_id}/executor/start" \
		-H "Content-Type: application/json" \
		-d "{\"session_id\":\"${EXECUTOR_SESSION_ID}\",\"metadata\":{\"agent\":\"executor\",\"started_at\":\"$(date -Iseconds)\"}}" >/dev/null 2>&1 &&
		echo -e "${GREEN}Registered in dashboard${NC}" || echo -e "${YELLOW}Dashboard offline${NC}"

	executor_heartbeat_start
	executor_log "user" "Task ${task_id} started"
}

# Heartbeat management
executor_heartbeat_start() {
	[ -n "$HEARTBEAT_PID" ] && return 0
	local hb_pidfile="/tmp/executor-heartbeat-$$.pid"
	if [ -f "$hb_pidfile" ]; then
		local existing_pid
		existing_pid=$(cat "$hb_pidfile" 2>/dev/null)
		if kill -0 "$existing_pid" 2>/dev/null; then
			echo -e "${YELLOW}Heartbeat already running (PID: $existing_pid)${NC}"
			return 0
		fi
	fi
	(
		while true; do
			[ -n "$EXECUTOR_PROJECT" ] && [ -n "$EXECUTOR_TASK_ID" ] &&
				curl -s -X POST "${DASHBOARD_API}/project/${EXECUTOR_PROJECT}/task/${EXECUTOR_TASK_ID}/executor/heartbeat" \
					-H "Content-Type: application/json" -d "{\"session_id\":\"${EXECUTOR_SESSION_ID}\"}" >/dev/null 2>&1
			sleep 30
		done
	) &
	export HEARTBEAT_PID=$!
	echo "$HEARTBEAT_PID" >"$hb_pidfile"
	trap 'kill $HEARTBEAT_PID 2>/dev/null; wait $HEARTBEAT_PID 2>/dev/null; rm -f '"$hb_pidfile"'' EXIT INT TERM
	echo -e "${GREEN}Heartbeat started (PID: $HEARTBEAT_PID)${NC}"
}

executor_heartbeat_stop() {
	[ -n "$HEARTBEAT_PID" ] && {
		kill $HEARTBEAT_PID 2>/dev/null
		export HEARTBEAT_PID=""
		echo -e "${GREEN}Heartbeat stopped${NC}"
	}
}

# Log message - Usage: executor_log <role> <content> [tool_name] [tool_input] [tool_output]
executor_log() {
	local role=$1 content=$2 tool_name=${3:-""} tool_input=${4:-null} tool_output=${5:-null}
	[ -z "$EXECUTOR_PROJECT" ] && {
		echo -e "${YELLOW}Not initialized. Run executor_start first.${NC}"
		return 1
	}

	content=$(echo "$content" | sed 's/"/\\"/g' | tr '\n' ' ')
	local payload="{\"session_id\":\"${EXECUTOR_SESSION_ID}\",\"role\":\"${role}\",\"content\":\"${content}\""
	[ -n "$tool_name" ] && payload="${payload},\"tool_name\":\"${tool_name}\",\"tool_input\":${tool_input},\"tool_output\":${tool_output}"
	payload="${payload}}"

	curl -s -X POST "${DASHBOARD_API}/project/${EXECUTOR_PROJECT}/task/${EXECUTOR_TASK_ID}/conversation/log" \
		-H "Content-Type: application/json" -d "$payload" >/dev/null 2>&1

	case "$role" in
	"user") echo -e "${BLUE}[USER]${NC} $2" ;;
	"assistant") echo -e "${GREEN}[ASSISTANT]${NC} $2" ;;
	"tool") echo -e "${YELLOW}[TOOL: $tool_name]${NC}" ;;
	"system") echo -e "${RED}[SYSTEM]${NC} $2" ;;
	esac
}

executor_log_tool() { executor_log "tool" "" "$1" "$2" "$3"; }

# Complete task - Usage: executor_complete [success|failed]
executor_complete() {
	local status=${1:-"success"} success="true" status_value="completed"
	[ "$status" = "failed" ] && {
		success="false"
		status_value="failed"
	}
	[ -z "$EXECUTOR_PROJECT" ] && {
		echo -e "${YELLOW}Not initialized${NC}"
		return 1
	}

	echo -e "${BLUE}Completing task...${NC}"
	executor_heartbeat_stop

	[ "$success" = "true" ] && executor_log "assistant" "Task ${EXECUTOR_TASK_ID} completed successfully" ||
		executor_log "assistant" "Task ${EXECUTOR_TASK_ID} failed"

	curl -s -X POST "${DASHBOARD_API}/project/${EXECUTOR_PROJECT}/task/${EXECUTOR_TASK_ID}/executor/complete" \
		-H "Content-Type: application/json" \
		-d "{\"session_id\":\"${EXECUTOR_SESSION_ID}\",\"status\":\"${status_value}\",\"metadata\":{\"completed_at\":\"$(date -Iseconds)\"}}" >/dev/null 2>&1 &&
		echo -e "${GREEN}Task ${status_value}${NC}" || echo -e "${YELLOW}Dashboard offline${NC}"

	export EXECUTOR_PROJECT="" EXECUTOR_TASK_ID="" EXECUTOR_SESSION_ID=""
	echo -e "${GREEN}Session ended${NC}"
}

# Status check
executor_status() {
	echo -e "${BLUE}Executor Status${NC}"
	echo -e "  Project: ${GREEN}${EXECUTOR_PROJECT:-Not set}${NC}"
	echo -e "  Task: ${GREEN}${EXECUTOR_TASK_ID:-Not set}${NC}"
	echo -e "  Session: ${GREEN}${EXECUTOR_SESSION_ID:-Not set}${NC}"
	echo -e "  Heartbeat: ${GREEN}${HEARTBEAT_PID:-Not running}${NC}"
	[ -n "$EXECUTOR_PROJECT" ] && echo -e "  Dashboard: ${BLUE}http://localhost:31415?project=${EXECUTOR_PROJECT}&task=${EXECUTOR_TASK_ID}${NC}"
}

# Help
executor_help() {
	cat <<'EOF'
EXECUTOR TRACKING - Usage:

  source ~/.claude/scripts/executor-tracking.sh

  executor_start "project" "T01"    # Start tracking
  executor_log "user" "message"     # Log user message
  executor_log "assistant" "msg"    # Log assistant message
  executor_log_tool "Read" '{...}' '{...}'  # Log tool call
  executor_status                   # Check status
  executor_complete success         # Complete (or: failed)

Dashboard: http://localhost:31415
EOF
}

# Quiet mode check
[ -z "$EXECUTOR_QUIET" ] && echo -e "${GREEN}Executor functions loaded${NC} - Run ${BLUE}executor_help${NC} for usage"
