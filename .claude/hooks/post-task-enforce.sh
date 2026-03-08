#!/usr/bin/env bash
# post-task-enforce.sh — PostToolUse hook
# After plan-db-safe.sh completes, reminds/enforces checkpoint + Thor.
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)

[ "$TOOL_NAME" != "Bash" ] && [ "$TOOL_NAME" != "bash" ] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // .toolArgs.command // ""' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# After plan-db-safe.sh update-task done → remind to checkpoint + Thor
if echo "$COMMAND" | grep -qE "plan-db-safe\.sh.*update-task.*done"; then
    TASK_ID=$(echo "$COMMAND" | grep -oE '[0-9]+' | head -1)
    PLAN_ID=$(echo "$COMMAND" | grep -oE '[0-9]+' | head -2 | tail -1)

    # Auto-run checkpoint if plan_id is available
    if [ -n "$PLAN_ID" ] && command -v plan-checkpoint.sh >/dev/null 2>&1; then
        plan-checkpoint.sh save "$PLAN_ID" 2>/dev/null
    fi

    cat <<EOF
{"decision":"allow","notification":"MANDATORY NEXT STEPS after task $TASK_ID done:\n1. plan-checkpoint.sh save {plan_id}\n2. plan-db.sh validate-task $TASK_ID {plan_id}\n3. Then launch next task or Thor wave validation\nDO NOT SKIP THESE STEPS."}
EOF
    exit 0
fi

exit 0
