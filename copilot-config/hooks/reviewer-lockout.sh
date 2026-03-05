#!/usr/bin/env bash
# reviewer-lockout.sh — preToolUse hook
# Blocks edit on files rejected 2+ times by Thor for the same task.
# First rejection = normal retry. Second+ = lockout (different agent needed).
# Version: 1.0.0

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // .tool_name // ""' 2>/dev/null)

# Only check on edit/write operations
case "$TOOL_NAME" in
    edit|Edit|write|Write|multiEdit|MultiEdit) ;;
    *) exit 0 ;;
esac

# Get file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.toolInput.path // .tool_input.path // .toolArgs.path // ""' 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

# Check if we're in a plan context
PLAN_ID="${PLAN_ID:-}"
if [[ -z "$PLAN_ID" ]] && [[ -f "$HOME/.claude/active-plan" ]]; then
    PLAN_ID=$(cat "$HOME/.claude/active-plan" 2>/dev/null)
fi
[[ -z "$PLAN_ID" ]] && exit 0

# Check current task
TASK_ID="${TASK_ID:-}"
[[ -z "$TASK_ID" ]] && exit 0

DB="${DASHBOARD_DB:-$HOME/.claude/data/dashboard.db}"
[[ ! -f "$DB" ]] && exit 0

# Count critical rejections for this file+task combination
REJECTION_COUNT=$(sqlite3 "$DB" "
    SELECT COUNT(*) FROM plan_learnings
    WHERE plan_id = $PLAN_ID
    AND task_id = '$TASK_ID'
    AND severity = 'critical'
    AND (detail LIKE '%${FILE_PATH}%' OR title LIKE '%${FILE_PATH}%')
;" 2>/dev/null || echo "0")

# Allow first rejection (normal retry), block on 2+
if [[ "$REJECTION_COUNT" -ge 2 ]]; then
    jq -n '{
        "decision": "deny",
        "message": "Reviewer lockout: \(.file) rejected \(.count)x by Thor for task \(.task). A different agent must handle revision.",
        "file": $file,
        "count": $count,
        "task": $task
    }' --arg file "$FILE_PATH" --argjson count "$REJECTION_COUNT" --arg task "$TASK_ID"
    exit 0
fi

# Allow
exit 0
