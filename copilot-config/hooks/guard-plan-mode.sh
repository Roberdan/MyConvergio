#!/usr/bin/env bash
# guard-plan-mode.sh — Copilot CLI preToolUse hook
# Blocks EnterPlanMode — forces use of /planner skill instead.
# Internal filter: only acts on toolName == "EnterPlanMode".
# Exit 0=allow, deny via jq JSON output + exit 0
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""' 2>/dev/null)

# Only block EnterPlanMode
if [ "$TOOL_NAME" = "EnterPlanMode" ]; then
	jq -n '{permissionDecision: "deny", permissionDecisionReason: "BLOCKED: Use @planner instead of EnterPlanMode. EnterPlanMode = no DB registration = Thor/execute/tracking break. Ref: Plan 225."}'
	exit 0
fi

exit 0
