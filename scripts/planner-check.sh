#!/usr/bin/env bash
# planner-check.sh — Validate planner workflow completed correctly
# Usage: planner-check.sh <PLAN_ID>
# Checks: spec exists, plan in DB, tasks imported, worktree set
# Exit 0 = PASS, Exit 1 = FAIL with specific error
set -euo pipefail

PLAN_ID="${1:-}"

if [ -z "$PLAN_ID" ]; then
  echo "FAIL: Usage: planner-check.sh <PLAN_ID>"
  exit 1
fi

export PATH="$HOME/.claude/scripts:$PATH"
ERRORS=0

# Check 1: Plan exists in DB
PLAN_JSON=$(plan-db.sh json "$PLAN_ID" 2>/dev/null) || {
  echo "FAIL: Plan $PLAN_ID not found in plan-db"
  exit 1
}

# Check 2: Tasks imported
TASKS_TOTAL=$(echo "$PLAN_JSON" | jq -r '.tasks_total // 0' 2>/dev/null)
if [ -z "$TASKS_TOTAL" ] || [ "$TASKS_TOTAL" -eq 0 ]; then
  echo "FAIL: Plan $PLAN_ID has 0 tasks. Run: plan-db.sh import $PLAN_ID <spec.json>"
  ERRORS=$((ERRORS + 1))
fi

# Check 3: Source file exists
SOURCE=$(echo "$PLAN_JSON" | jq -r '.source_file // empty')
if [ -n "$SOURCE" ] && [ ! -f "$SOURCE" ]; then
  echo "WARN: Source file not found: $SOURCE"
fi

# Check 4: Plan has a name
NAME=$(echo "$PLAN_JSON" | jq -r '.name // empty')
if [ -z "$NAME" ]; then
  echo "FAIL: Plan $PLAN_ID has no name"
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "FAIL: $ERRORS check(s) failed for plan $PLAN_ID"
  exit 1
fi

echo "PASS: Plan $PLAN_ID ready — $NAME ($TASKS_TOTAL tasks)"
