#!/usr/bin/env bash
# enforce-plan-db-safe.sh — Copilot CLI preToolUse hook
# Blocks direct plan-db.sh update-task ... done commands.
# Forces use of plan-db-safe.sh which auto-validates and tracks Thor audit.
# Internal filter: only acts on bash/shell tool calls.
# Exit 0=allow, deny via jq JSON output + exit 0
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""' 2>/dev/null)

# Only check bash/shell tools
if [[ "$TOOL_NAME" != "bash" && "$TOOL_NAME" != "shell" ]]; then
	exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.toolArgs.command // ""' 2>/dev/null)

# Exit if no command
[ -z "$COMMAND" ] && exit 0

# Allow plan-db-safe.sh (safe wrapper is always OK)
if echo "$COMMAND" | grep -qE "plan-db-safe\.sh"; then
	exit 0
fi

# Block: plan-db.sh update-task ... done (without plan-db-safe)
if echo "$COMMAND" | grep -qE "plan-db\.sh[[:space:]]+update-task[[:space:]].*[[:space:]]done"; then
	jq -n '{permissionDecision: "deny", permissionDecisionReason: "BLOCKED: Use plan-db-safe.sh (not plan-db.sh) to mark tasks done. plan-db-safe.sh auto-validates and tracks Thor audit."}'
	exit 0
fi

exit 0
