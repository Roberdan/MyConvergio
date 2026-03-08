#!/usr/bin/env bash
# enforce-plan-reviews.sh — preToolUse hook
# Blocks plan-db.sh start when required planner reviews are missing.

set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""' 2>/dev/null)

if [[ "$TOOL_NAME" != "bash" && "$TOOL_NAME" != "shell" ]]; then
	exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.toolArgs.command // ""' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

if ! echo "$COMMAND" | grep -qE 'plan-db\.sh[[:space:]]+start([[:space:]]|$)'; then
	exit 0
fi

PLAN_ID=$(echo "$COMMAND" | sed -nE 's/.*plan-db\.sh[[:space:]]+start[[:space:]]+([0-9]+).*/\1/p')
if [ -z "$PLAN_ID" ]; then
	jq -n '{permissionDecision: "deny", permissionDecisionReason: "BLOCKED: plan-db.sh start requires explicit numeric plan_id."}'
	exit 0
fi

DB_PATH="${HOME}/.claude/data/dashboard.db"
if [ ! -f "$DB_PATH" ]; then
	jq -n '{permissionDecision: "deny", permissionDecisionReason: "BLOCKED: dashboard.db not found. Cannot verify planner review gates."}'
	exit 0
fi

TASK_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE plan_id=$PLAN_ID;" 2>/dev/null || echo "0")
REVIEW_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$PLAN_ID AND reviewer_agent LIKE '%reviewer%' AND reviewer_agent NOT LIKE '%challenger%';" 2>/dev/null || echo "0")
BIZ_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$PLAN_ID AND (reviewer_agent LIKE '%business%' OR reviewer_agent LIKE '%advisor%');" 2>/dev/null || echo "0")
CHALLENGER_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$PLAN_ID AND reviewer_agent LIKE '%challenger%';" 2>/dev/null || echo "0")
APPROVAL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$PLAN_ID AND reviewer_agent='user-approval';" 2>/dev/null || echo "0")

if [[ "$TASK_COUNT" -eq 0 ]]; then
	jq -n --arg plan_id "$PLAN_ID" '{permissionDecision: "deny", permissionDecisionReason: ("BLOCKED: plan " + $plan_id + " has no tasks in DB. Import plan before start.")}'
	exit 0
fi

if [[ "$REVIEW_COUNT" -eq 0 || "$BIZ_COUNT" -eq 0 || "$CHALLENGER_COUNT" -eq 0 || "$APPROVAL_COUNT" -eq 0 ]]; then
	jq -n --arg plan_id "$PLAN_ID" \
		--arg reviewer "$REVIEW_COUNT" --arg business "$BIZ_COUNT" --arg challenger "$CHALLENGER_COUNT" --arg approval "$APPROVAL_COUNT" \
		'{permissionDecision: "deny", permissionDecisionReason: ("BLOCKED: planner gates incomplete for plan " + $plan_id + " (reviewer=" + $reviewer + ", business=" + $business + ", challenger=" + $challenger + ", approval=" + $approval + "). Run plan-reviewer, plan-business-advisor, plan-challenger, and plan-db.sh approve before start.")}'
	exit 0
fi

exit 0
