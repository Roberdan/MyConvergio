#!/bin/bash
# Guard against EnterPlanMode — blocks direct plan creation bypassing /planner skill
# PreToolUse hook: Exit 2 = BLOCK, Exit 0 = ALLOW
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

if [ "$TOOL_NAME" = "EnterPlanMode" ]; then
	echo 'BLOCKED: Use Skill(skill="planner") instead of EnterPlanMode. EnterPlanMode = no DB registration = Thor/execute/tracking break. Ref: Plan 225.' >&2
	exit 2
fi

exit 0
