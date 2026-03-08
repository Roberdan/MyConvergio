#!/usr/bin/env bash
# enforce-planner-workflow.sh — PreToolUse hook for Claude Code
# Blocks ALL direct plan-db.sh create/import.
# Only planner-create.sh can create/import (it validates 3 reviews first).
# Version: 2.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)

# Block EnterPlanMode
if [ "$TOOL_NAME" = "EnterPlanMode" ]; then
    echo '{"decision":"block","reason":"BLOCKED: Use Skill(skill=\"planner\") instead of EnterPlanMode. Plan 225."}'
    exit 0
fi

# Only check Bash tool calls
if [ "$TOOL_NAME" != "Bash" ] && [ "$TOOL_NAME" != "bash" ]; then
    exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // .toolArgs.command // ""' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Allow plan-db-safe.sh (safe task-done wrapper)
echo "$COMMAND" | grep -qE "plan-db-safe\.sh" && exit 0

# Allow planner-create.sh (gated wrapper with review enforcement)
echo "$COMMAND" | grep -qE "planner-create\.sh" && exit 0

# Skip git commits (commit messages may mention plan-db.sh)
echo "$COMMAND" | grep -qE "^(cd [^;]+(&& |; ))?git commit" && exit 0

# Skip echo/printf/cat (test output, not execution)
echo "$COMMAND" | grep -qE "^(echo |printf )" && exit 0

# Extract first line for command matching
FIRST_LINE=$(echo "$COMMAND" | head -1)

# Block: plan-db.sh create (must use planner-create.sh)
if echo "$FIRST_LINE" | grep -qE "(^|[;&|] *)plan-db\.sh[[:space:]]+create[[:space:]]"; then
    echo '{"decision":"block","reason":"BLOCKED: Use planner-create.sh create (not plan-db.sh create). planner-create.sh enforces 3 mandatory reviews (standard + challenger + business) before plan creation. Ref: Plan 100026 violation."}'
    exit 0
fi

# Block: plan-db.sh import (must use planner-create.sh)
if echo "$FIRST_LINE" | grep -qE "(^|[;&|] *)plan-db\.sh[[:space:]]+import[[:space:]]"; then
    echo '{"decision":"block","reason":"BLOCKED: Use planner-create.sh import (not plan-db.sh import). planner-create.sh enforces 3 mandatory reviews before spec import. Ref: Plan 100026 violation."}'
    exit 0
fi

# Block: plan-db.sh update-task ... done (must use plan-db-safe.sh)
if echo "$FIRST_LINE" | grep -qE "(^|[;&|] *)plan-db\.sh[[:space:]]+update-task[[:space:]].*[[:space:]]done"; then
    echo '{"decision":"block","reason":"BLOCKED: Use plan-db-safe.sh (not plan-db.sh) to mark tasks done. plan-db-safe.sh enforces Thor audit trail."}'
    exit 0
fi

exit 0
