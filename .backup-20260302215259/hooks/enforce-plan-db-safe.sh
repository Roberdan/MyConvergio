#!/bin/bash
# enforce-plan-db-safe.sh - PreToolUse hook on Bash
# Blocks direct plan-db.sh update-task ... done commands.
# Forces use of plan-db-safe.sh which auto-validates and tracks Thor audit.
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Exit if no command
[ -z "$COMMAND" ] && exit 0

# Allow plan-db-safe.sh (safe wrapper is always OK)
if echo "$COMMAND" | grep -qE "plan-db-safe\.sh"; then
	exit 0
fi

# Block: plan-db.sh update-task ... done (without plan-db-safe)
if echo "$COMMAND" | grep -qE "plan-db\.sh[[:space:]]+update-task[[:space:]].*[[:space:]]done"; then
	echo "BLOCKED: Use plan-db-safe.sh (not plan-db.sh) to mark tasks done. plan-db-safe.sh auto-validates and tracks Thor audit." >&2
	exit 2
fi

exit 0
