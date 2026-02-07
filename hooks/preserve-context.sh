#!/bin/bash
# PreCompact hook - preserve critical context before compaction
# Extracts active plan ID, F-xx requirements, current task
set -euo pipefail

source ~/.claude/hooks/lib/common.sh 2>/dev/null || true

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0

# Extract active plan ID from recent messages
PLAN_ID=""
PLAN_ID=$(jq -r '
  [.[] | select(.type == "human") | .message // empty | strings]
  | reverse | .[:20] | join(" ")
  | capture("plan[_-]?(?<id>[0-9]+)") | .id // empty
' "$TRANSCRIPT_PATH" 2>/dev/null || echo "")

# Get current in-progress task from dashboard DB
CURRENT_TASK=""
if check_dashboard && [ -n "$PLAN_ID" ]; then
  CURRENT_TASK=$(sqlite3 "$DASHBOARD_DB" \
    "SELECT task_id || ': ' || title FROM tasks WHERE plan_id = '$PLAN_ID' AND status = 'in_progress' LIMIT 1;" \
    2>/dev/null || echo "")
fi

# Extract F-xx requirements mentioned in conversation
FXX_LIST=""
FXX_LIST=$(jq -r '
  [.[] | .message // empty | strings] | join(" ")
' "$TRANSCRIPT_PATH" 2>/dev/null \
  | grep -oE 'F-[0-9]+' | sort -u | tr '\n' ', ' | sed 's/,$//' || echo "")

# Build preserved context
PRESERVED=""
[ -n "$PLAN_ID" ] && PRESERVED="Active Plan: $PLAN_ID"
[ -n "$CURRENT_TASK" ] && PRESERVED="${PRESERVED:+$PRESERVED\n}Current Task: $CURRENT_TASK"
[ -n "$FXX_LIST" ] && PRESERVED="${PRESERVED:+$PRESERVED\n}F-xx Requirements: $FXX_LIST"

# Nothing to preserve
[ -z "$PRESERVED" ] && exit 0

jq -n --arg ctx "## Preserved Context (pre-compaction)\n$PRESERVED" \
  '{"additionalContext": $ctx}'
