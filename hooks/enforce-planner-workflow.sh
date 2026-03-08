#!/usr/bin/env bash
# enforce-planner-workflow.sh — PreToolUse hook for Claude Code
# Blocks direct plan-db.sh create/import commands outside planner skill.
# Also blocks EnterPlanMode.
# Bypass: command prefixed with PLANNER_ACTIVE=1 (set by planner skill only)
# Version: 1.1.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)

# Block EnterPlanMode
if [ "$TOOL_NAME" = "EnterPlanMode" ]; then
    echo '{"decision":"block","reason":"BLOCKED: Use Skill(skill=\"planner\") instead of EnterPlanMode. EnterPlanMode = no DB registration = VIOLATION (Plan 225)."}'
    exit 0
fi

# Only check Bash tool calls
if [ "$TOOL_NAME" != "Bash" ] && [ "$TOOL_NAME" != "bash" ]; then
    exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // .toolArgs.command // ""' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Allow plan-db-safe.sh (safe wrapper is always OK)
echo "$COMMAND" | grep -qE "plan-db-safe\.sh" && exit 0

# Allow if PLANNER_ACTIVE=1 prefix (set by planner skill during execution)
echo "$COMMAND" | grep -qE "^PLANNER_ACTIVE=1[[:space:]]" && exit 0

# Block: plan-db.sh create (must come from planner skill)
if echo "$COMMAND" | grep -qE "plan-db\.sh[[:space:]]+create[[:space:]]"; then
    echo '{"decision":"block","reason":"BLOCKED: plan-db.sh create must be invoked via Skill(skill=\"planner\"), not directly. Prefix with PLANNER_ACTIVE=1 inside planner skill only. Ref: Plan 100026 violation."}'
    exit 0
fi

# Block: plan-db.sh import (must come from planner skill)
if echo "$COMMAND" | grep -qE "plan-db\.sh[[:space:]]+import[[:space:]]"; then
    echo '{"decision":"block","reason":"BLOCKED: plan-db.sh import must be invoked via Skill(skill=\"planner\"), not directly. Prefix with PLANNER_ACTIVE=1 inside planner skill only. Ref: Plan 100026 violation."}'
    exit 0
fi

# Block: plan-db.sh update-task ... done (must use plan-db-safe.sh)
if echo "$COMMAND" | grep -qE "plan-db\.sh[[:space:]]+update-task[[:space:]].*[[:space:]]done"; then
    echo '{"decision":"block","reason":"BLOCKED: Use plan-db-safe.sh (not plan-db.sh) to mark tasks done. plan-db-safe.sh enforces Thor audit trail."}'
    exit 0
fi

exit 0
