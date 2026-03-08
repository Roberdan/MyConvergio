#!/usr/bin/env bash
# enforce-thor-completion.sh — Copilot CLI preToolUse hook
# Blocks plan-db.sh complete when plan has non-validated tasks.
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
[ -z "$COMMAND" ] && exit 0

# Intercept: plan-db.sh complete ...
if ! echo "$COMMAND" | grep -qE 'plan-db\.sh[[:space:]]+complete([[:space:]]|$)'; then
  exit 0
fi

DB_PATH="${HOME}/.claude/data/dashboard.db"
PLAN_ID=$(echo "$COMMAND" | sed -nE 's/.*plan-db\.sh[[:space:]]+complete[[:space:]]+([0-9]+).*/\1/p')

# Fallback to active plan file if complete called without explicit plan ID
if [ -z "$PLAN_ID" ]; then
  PLAN_FILE="${HOME}/.claude/data/active-plan-id.txt"
  if [ -f "$PLAN_FILE" ]; then
    PLAN_ID=$(grep -m1 -E '^[0-9]+$' "$PLAN_FILE" 2>/dev/null || true)
  fi
fi

if [ -z "$PLAN_ID" ]; then
  jq -n '{permissionDecision: "deny", permissionDecisionReason: "BLOCKED: Cannot resolve plan_id for plan-db.sh complete. Pass explicit numeric plan_id."}'
  exit 0
fi

UNVALIDATED_TASKS=$(sqlite3 "$DB_PATH" "SELECT task_id FROM tasks WHERE plan_id = ${PLAN_ID} AND validated_at IS NULL AND status NOT IN ('skipped', 'cancelled') ORDER BY id;" 2>/dev/null)

if [ -n "$UNVALIDATED_TASKS" ]; then
  TASK_LIST=$(echo "$UNVALIDATED_TASKS" | awk 'NF {printf("%s%s", sep, $0); sep=", "}')
  jq -n --arg plan_id "$PLAN_ID" --arg task_ids "$TASK_LIST" \
    '{permissionDecision: "deny", permissionDecisionReason: ("BLOCKED: plan-db.sh complete denied for plan " + $plan_id + ". Unvalidated tasks: " + $task_ids + ".")}'
  exit 0
fi

exit 0
