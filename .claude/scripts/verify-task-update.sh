#!/bin/bash
set -euo pipefail
# Verify task was updated in DB after task-executor completion
# Usage: verify-task-update.sh <db_task_id> [expected_status]
#
# Returns:
#   0 = Task properly updated
#   1 = Task NOT updated (still pending/in_progress when should be done)
#   2 = Task not found

# Version: 1.1.0
set -euo pipefail

DB="${HOME}/.claude/data/dashboard.db"
TASK_ID="${1:?Usage: verify-task-update.sh <db_task_id> [expected_status]}"
EXPECTED_STATUS="${2:-done}"

# Check task exists
TASK=$(sqlite3 "$DB" "SELECT id, task_id, status, notes FROM tasks WHERE id=$TASK_ID;" 2>/dev/null)

if [ -z "$TASK" ]; then
	echo "ERROR: Task $TASK_ID not found in database"
	exit 2
fi

# Parse fields
STATUS=$(echo "$TASK" | cut -d'|' -f3)
NOTES=$(echo "$TASK" | cut -d'|' -f4)
TASK_CODE=$(echo "$TASK" | cut -d'|' -f2)

# Check status
if [ "$STATUS" = "pending" ]; then
	echo "FAILED: Task $TASK_CODE (id=$TASK_ID) still PENDING"
	echo "  → Executor forgot to update status"
	echo "  → Run: plan-db.sh update-task $TASK_ID $EXPECTED_STATUS \"Summary\""
	exit 1
fi

if [ "$STATUS" = "in_progress" ] && [ "$EXPECTED_STATUS" = "done" ]; then
	echo "FAILED: Task $TASK_CODE (id=$TASK_ID) stuck IN_PROGRESS"
	echo "  → Executor started but forgot to mark done"
	echo "  → Run: plan-db.sh update-task $TASK_ID done \"Summary\""
	exit 1
fi

if [ "$STATUS" != "$EXPECTED_STATUS" ]; then
	echo "WARNING: Task $TASK_CODE status is '$STATUS', expected '$EXPECTED_STATUS'"
	exit 0 # Not a hard failure, just warning
fi

# Check notes (soft warning)
if [ -z "$NOTES" ] || [ "$NOTES" = "null" ]; then
	echo "WARNING: Task $TASK_CODE has no completion notes"
fi

echo "OK: Task $TASK_CODE (id=$TASK_ID) status=$STATUS"
exit 0
