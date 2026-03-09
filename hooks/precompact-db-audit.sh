#!/usr/bin/env bash
# precompact-db-audit.sh — PreCompact hook
# Version: 1.0.0
#
# Before context compaction, check for orphaned in_progress tasks
# that the coordinator forgot to update. Injects a warning into
# the compacted context so the resumed session knows to fix it.
#
# Problem solved: Plan 382 — compaction wiped coordinator memory,
# tasks were never marked done, plan showed 0% progress.
set -uo pipefail

DB_PATH="${HOME}/.claude/data/dashboard.db"
[ -f "$DB_PATH" ] || exit 0

# Find active plans (status = 'doing')
ACTIVE_PLANS=$(sqlite3 "$DB_PATH" \
  "SELECT id FROM plans WHERE status = 'doing' LIMIT 5;" \
  2>/dev/null || echo "")

[ -z "$ACTIVE_PLANS" ] && exit 0

WARNINGS=""
for PLAN_ID in $ACTIVE_PLANS; do
  IN_PROGRESS=$(sqlite3 "$DB_PATH" \
    "SELECT COUNT(*) FROM tasks WHERE plan_id = $PLAN_ID AND status = 'in_progress';" \
    2>/dev/null || echo "0")

  if [ "$IN_PROGRESS" -gt 0 ] 2>/dev/null; then
    STALE=$(sqlite3 "$DB_PATH" \
      "SELECT id || ':' || task_id FROM tasks WHERE plan_id = $PLAN_ID AND status = 'in_progress' LIMIT 5;" \
      2>/dev/null || echo "?")
    WARNINGS="${WARNINGS}\nPlan $PLAN_ID: $IN_PROGRESS task(s) stuck in 'in_progress': $STALE"
  fi
done

if [ -n "$WARNINGS" ]; then
  CONTEXT="DB AUDIT WARNING (pre-compaction): Tasks may have been executed but not updated in DB.$WARNINGS\n\nAfter compaction, run:\n1. plan-db.sh execution-tree <plan_id>\n2. For each in_progress task that is actually done: plan-db-safe.sh update-task <id> done \"summary\"\n3. Then: plan-db.sh validate-task <id> <plan_id>"

  jq -n --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
  exit 0
fi

exit 0
