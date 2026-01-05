#!/bin/bash
# Executor Tracking Helper Functions
# Source this file in your shell to use tracking functions
# Usage: source ~/.claude/scripts/executor-tracking.sh

# Configuration
export DASHBOARD_API="http://localhost:31415/api"
export EXECUTOR_PROJECT=""
export EXECUTOR_TASK_ID=""
export EXECUTOR_SESSION_ID=""
export HEARTBEAT_PID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize executor tracking for a task
# Usage: executor_start <project> <task_id>
executor_start() {
  local project=$1
  local task_id=$2

  if [ -z "$project" ] || [ -z "$task_id" ]; then
    echo -e "${RED}❌ Usage: executor_start <project> <task_id>${NC}"
    return 1
  fi

  export EXECUTOR_PROJECT="$project"
  export EXECUTOR_TASK_ID="$task_id"
  export EXECUTOR_SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

  echo -e "${BLUE}🚀 Starting executor tracking...${NC}"
  echo -e "  Project: ${GREEN}${project}${NC}"
  echo -e "  Task: ${GREEN}${task_id}${NC}"
  echo -e "  Session: ${GREEN}${EXECUTOR_SESSION_ID}${NC}"

  # Call dashboard API to register task start
  local response=$(curl -s -X POST "${DASHBOARD_API}/project/${project}/task/${task_id}/executor/start" \
    -H "Content-Type: application/json" \
    -d "{
      \"session_id\": \"${EXECUTOR_SESSION_ID}\",
      \"metadata\": {
        \"agent\": \"executor\",
        \"started_at\": \"$(date -Iseconds)\"
      }
    }" 2>&1)

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Task started and registered in dashboard${NC}"
  else
    echo -e "${YELLOW}⚠️  Dashboard API not responding${NC}"
    echo -e "   Task will run without dashboard tracking"
  fi

  # Start heartbeat in background
  executor_heartbeat_start

  # Log initial message
  executor_log "user" "Task ${task_id} started"
  executor_log "assistant" "Initializing task execution..."
}

# Start heartbeat loop in background
executor_heartbeat_start() {
  if [ -n "$HEARTBEAT_PID" ]; then
    echo -e "${YELLOW}⚠️  Heartbeat already running (PID: $HEARTBEAT_PID)${NC}"
    return 0
  fi

  (
    while true; do
      if [ -n "$EXECUTOR_PROJECT" ] && [ -n "$EXECUTOR_TASK_ID" ] && [ -n "$EXECUTOR_SESSION_ID" ]; then
        curl -s -X POST "${DASHBOARD_API}/project/${EXECUTOR_PROJECT}/task/${EXECUTOR_TASK_ID}/executor/heartbeat" \
          -H "Content-Type: application/json" \
          -d "{\"session_id\": \"${EXECUTOR_SESSION_ID}\"}" > /dev/null 2>&1
      fi
      sleep 30
    done
  ) &

  export HEARTBEAT_PID=$!
  echo -e "${GREEN}💓 Heartbeat started (PID: $HEARTBEAT_PID)${NC}"
}

# Stop heartbeat
executor_heartbeat_stop() {
  if [ -n "$HEARTBEAT_PID" ]; then
    kill $HEARTBEAT_PID 2>/dev/null
    echo -e "${GREEN}💓 Heartbeat stopped${NC}"
    export HEARTBEAT_PID=""
  fi
}

# Log a conversation message
# Usage: executor_log <role> <content> [tool_name] [tool_input_json] [tool_output_json]
executor_log() {
  local role=$1
  local content=$2
  local tool_name=${3:-""}
  local tool_input=${4:-null}
  local tool_output=${5:-null}

  if [ -z "$EXECUTOR_PROJECT" ] || [ -z "$EXECUTOR_TASK_ID" ]; then
    echo -e "${YELLOW}⚠️  Executor not initialized. Run executor_start first.${NC}"
    return 1
  fi

  # Escape content for JSON
  content=$(echo "$content" | sed 's/"/\\"/g' | tr '\n' ' ')

  local payload="{
    \"session_id\": \"${EXECUTOR_SESSION_ID}\",
    \"role\": \"${role}\",
    \"content\": \"${content}\""

  if [ -n "$tool_name" ]; then
    payload="${payload},
    \"tool_name\": \"${tool_name}\",
    \"tool_input\": ${tool_input},
    \"tool_output\": ${tool_output}"
  fi

  payload="${payload}
  }"

  curl -s -X POST "${DASHBOARD_API}/project/${EXECUTOR_PROJECT}/task/${EXECUTOR_TASK_ID}/conversation/log" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null 2>&1

  # Visual feedback
  case "$role" in
    "user")
      echo -e "${BLUE}👤 [USER]${NC} $2"
      ;;
    "assistant")
      echo -e "${GREEN}🤖 [ASSISTANT]${NC} $2"
      ;;
    "tool")
      echo -e "${YELLOW}🔧 [TOOL: $tool_name]${NC}"
      ;;
    "system")
      echo -e "${RED}⚙️  [SYSTEM]${NC} $2"
      ;;
  esac
}

# Log a tool call with input/output
# Usage: executor_log_tool <tool_name> <input_json> <output_json>
executor_log_tool() {
  local tool_name=$1
  local tool_input=$2
  local tool_output=$3

  executor_log "tool" "" "$tool_name" "$tool_input" "$tool_output"
}

# Complete task execution
# Usage: executor_complete [success|failed]
executor_complete() {
  local status=${1:-"success"}
  local success="true"

  if [ "$status" = "failed" ]; then
    success="false"
  fi

  if [ -z "$EXECUTOR_PROJECT" ] || [ -z "$EXECUTOR_TASK_ID" ]; then
    echo -e "${YELLOW}⚠️  Executor not initialized${NC}"
    return 1
  fi

  echo -e "${BLUE}🏁 Completing task...${NC}"

  # Stop heartbeat
  executor_heartbeat_stop

  # Log completion message
  if [ "$success" = "true" ]; then
    executor_log "assistant" "Task ${EXECUTOR_TASK_ID} completed successfully"
  else
    executor_log "assistant" "Task ${EXECUTOR_TASK_ID} failed"
  fi

  # Call dashboard API
  local endpoint="executor/complete"
  if [ "$success" = "false" ]; then
    endpoint="executor/failed"
  fi

  local response=$(curl -s -X POST "${DASHBOARD_API}/project/${EXECUTOR_PROJECT}/task/${EXECUTOR_TASK_ID}/${endpoint}" \
    -H "Content-Type: application/json" \
    -d "{
      \"session_id\": \"${EXECUTOR_SESSION_ID}\",
      \"success\": ${success},
      \"metadata\": {
        \"completed_at\": \"$(date -Iseconds)\"
      }
    }" 2>&1)

  if [ $? -eq 0 ]; then
    if [ "$success" = "true" ]; then
      echo -e "${GREEN}✅ Task completed and registered in dashboard${NC}"
    else
      echo -e "${RED}❌ Task failed and registered in dashboard${NC}"
    fi
  else
    echo -e "${YELLOW}⚠️  Dashboard API not responding${NC}"
  fi

  # Clear environment variables
  export EXECUTOR_PROJECT=""
  export EXECUTOR_TASK_ID=""
  export EXECUTOR_SESSION_ID=""

  echo -e "${GREEN}🎉 Executor tracking session ended${NC}"
}

# Show executor status
executor_status() {
  echo -e "${BLUE}📊 Executor Status${NC}"
  echo -e "  Project: ${GREEN}${EXECUTOR_PROJECT:-"Not set"}${NC}"
  echo -e "  Task: ${GREEN}${EXECUTOR_TASK_ID:-"Not set"}${NC}"
  echo -e "  Session: ${GREEN}${EXECUTOR_SESSION_ID:-"Not set"}${NC}"
  echo -e "  Heartbeat: ${GREEN}${HEARTBEAT_PID:-"Not running"}${NC}"

  if [ -n "$EXECUTOR_PROJECT" ] && [ -n "$EXECUTOR_TASK_ID" ]; then
    echo -e "  Dashboard: ${BLUE}http://localhost:31415?project=${EXECUTOR_PROJECT}&task=${EXECUTOR_TASK_ID}${NC}"
  fi
}

# Example usage function
executor_example() {
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║         Executor Tracking - Example Usage                     ║
╚════════════════════════════════════════════════════════════════╝

1. Source this file in your shell:
   source ~/.claude/scripts/executor-tracking.sh

2. Start tracking a task:
   executor_start "myproject" "T01"

3. Log messages during execution:
   executor_log "user" "Analyzing requirements..."
   executor_log "assistant" "Found 3 files to modify"

4. Log tool calls:
   executor_log_tool "Read" '{"file_path":"src/index.ts"}' '{"content":"..."}'

5. Check status:
   executor_status

6. Complete the task:
   executor_complete success
   # or
   executor_complete failed

───────────────────────────────────────────────────────────────

💡 Pro Tip: Use in your .zshrc or .bashrc to auto-load:
   # Auto-load executor tracking
   source ~/.claude/scripts/executor-tracking.sh

📊 View live in dashboard:
   http://localhost:31415

EOF
}

# Auto-display usage on load
if [ -z "$EXECUTOR_QUIET" ]; then
  echo -e "${GREEN}✅ Executor tracking functions loaded${NC}"
  echo -e "   Run ${BLUE}executor_example${NC} to see usage examples"
  echo -e "   Run ${BLUE}executor_status${NC} to check current status"
fi
