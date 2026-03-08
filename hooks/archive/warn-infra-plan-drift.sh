#!/usr/bin/env bash
# warn-infra-plan-drift.sh — Copilot CLI version
# PreToolUse hook: warns when az infra commands run while infra tasks are pending.
# Does NOT block — just warns loudly so the agent updates plan-db.
# Version: 1.0.0
set -euo pipefail

DB="$HOME/.claude/data/dashboard.db"
[[ ! -f "$DB" ]] && exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Bash tool calls
case "$TOOL_NAME" in
Bash | bash) ;;
*) exit 0 ;;
esac

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# Check if command is an az infra command
INFRA_PATTERN='az (containerapp|acr |postgres|redis |keyvault|storage |deployment group|webapp create|webapp update)'
if ! echo "$CMD" | grep -qE "$INFRA_PATTERN"; then
	exit 0
fi

# Check for active plans with pending infra tasks
PENDING=$(sqlite3 "$DB" "
    SELECT COUNT(*) FROM tasks t
    JOIN plans p ON t.plan_id = p.id
    WHERE p.status = 'doing'
    AND t.status IN ('pending', 'in_progress')
    AND (t.title LIKE '%Azure%' OR t.title LIKE '%Bicep%' OR t.title LIKE '%ACR%'
         OR t.title LIKE '%Container%' OR t.title LIKE '%Redis%' OR t.title LIKE '%PostgreSQL%'
         OR t.title LIKE '%Key Vault%' OR t.title LIKE '%Storage%' OR t.title LIKE '%MI %'
         OR t.title LIKE '%Managed Identity%' OR t.title LIKE '%deploy%' OR t.title LIKE '%provision%');
" 2>/dev/null || echo "0")

if [[ "$PENDING" -gt 0 ]]; then
	TASKS=$(sqlite3 "$DB" "
        SELECT t.task_id || ': ' || t.title FROM tasks t
        JOIN plans p ON t.plan_id = p.id
        WHERE p.status = 'doing'
        AND t.status IN ('pending', 'in_progress')
        AND (t.title LIKE '%Azure%' OR t.title LIKE '%Bicep%' OR t.title LIKE '%ACR%'
             OR t.title LIKE '%Container%' OR t.title LIKE '%Redis%' OR t.title LIKE '%PostgreSQL%'
             OR t.title LIKE '%Key Vault%' OR t.title LIKE '%Storage%' OR t.title LIKE '%MI %'
             OR t.title LIKE '%Managed Identity%' OR t.title LIKE '%deploy%' OR t.title LIKE '%provision%')
        LIMIT 5;
    " 2>/dev/null || true)

	cat >&2 <<EOF
[ADR-054] INFRA PLAN DRIFT WARNING
Running az infra command while ${PENDING} infra task(s) are pending in active plan.
Matching tasks:
${TASKS}
ACTION REQUIRED: Update plan-db BEFORE or AFTER this operation.
  plan-db.sh update-task <id> in_progress  (before)
  plan-db-safe.sh update-task <id> done "evidence" (after)
EOF
fi

exit 0
