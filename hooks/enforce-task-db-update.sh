#!/usr/bin/env bash
# enforce-task-db-update.sh — TaskCompleted hook
# Version: 1.0.0
#
# After a task-executor subagent completes, verify that the plan DB
# was updated. If the task is still in_progress, emit a BLOCKING
# notification so the coordinator cannot proceed without updating.
#
# Problem solved: Plan 382 — all 13 tasks executed but DB showed 0/13
# because coordinator lost state during compaction and never called
# plan-db-safe.sh update-task.
set -uo pipefail

DB_PATH="${HOME}/.claude/data/dashboard.db"
[ -f "$DB_PATH" ] || exit 0

INPUT=$(cat)
# TaskCompleted provides: task_id (subagent ID), result summary
RESULT=$(echo "$INPUT" | jq -r '.result // ""' 2>/dev/null)

# Extract plan ID from result text (task-executors mention it)
PLAN_ID=$(echo "$RESULT" | grep -oE 'plan[_ -]?([0-9]+)' | grep -oE '[0-9]+' | head -1)
[ -z "$PLAN_ID" ] && exit 0

# Count tasks that are in_progress (executor done but DB not updated)
IN_PROGRESS=$(sqlite3 "$DB_PATH" \
  "SELECT COUNT(*) FROM tasks WHERE plan_id = $PLAN_ID AND status = 'in_progress';" \
  2>/dev/null || echo "0")

# Count tasks still pending
PENDING=$(sqlite3 "$DB_PATH" \
  "SELECT COUNT(*) FROM tasks WHERE plan_id = $PLAN_ID AND status = 'pending';" \
  2>/dev/null || echo "0")

# Count submitted (awaiting Thor)
SUBMITTED=$(sqlite3 "$DB_PATH" \
  "SELECT COUNT(*) FROM tasks WHERE plan_id = $PLAN_ID AND status = 'submitted';" \
  2>/dev/null || echo "0")

if [ "$IN_PROGRESS" -gt 0 ] 2>/dev/null; then
  # List the in_progress tasks
  STALE_TASKS=$(sqlite3 "$DB_PATH" \
    "SELECT id || ':' || task_id || ' ' || title FROM tasks WHERE plan_id = $PLAN_ID AND status = 'in_progress' LIMIT 5;" \
    2>/dev/null || echo "unknown")

  cat <<EOF
{"decision":"block","reason":"PLAN DB OUT OF SYNC: Plan $PLAN_ID has $IN_PROGRESS task(s) still marked 'in_progress' in the database after executor completed.\n\nStale tasks:\n$STALE_TASKS\n\nYou MUST run for each completed task:\n  plan-db-safe.sh update-task <DB_ID> done \"summary\"\n\nThen: plan-db.sh validate-task <DB_ID> $PLAN_ID\n\nDO NOT launch more tasks until DB is current."}
EOF
  exit 0
fi

if [ "$SUBMITTED" -gt 0 ] 2>/dev/null; then
  cat <<EOF
{"decision":"allow","notification":"Plan $PLAN_ID: $SUBMITTED task(s) in 'submitted' status awaiting Thor validation. Run plan-db.sh validate-task for each before proceeding."}
EOF
  exit 0
fi

exit 0
