#!/bin/bash
# Version: 1.0.0
# Auto-restart copilot until plan is 100% complete
# Usage: copilot-plan-runner.sh <plan_id>
set -uo pipefail

PLAN_ID="$1"
DB="$HOME/.claude/data/dashboard.db"
MAX_RETRIES=50
RETRY=0

plan_done() {
	local pending
	pending=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE plan_id = $PLAN_ID AND status NOT IN ('done','validated','skipped','cancelled');")
	[ "$pending" -eq 0 ]
}

plan_summary() {
	sqlite3 "$DB" "SELECT status, COUNT(*) FROM tasks WHERE plan_id = $PLAN_ID GROUP BY status;"
}

echo "=== Plan #$PLAN_ID Runner (auto-restart) ==="

while ! plan_done; do
	RETRY=$((RETRY + 1))
	if [ "$RETRY" -gt "$MAX_RETRIES" ]; then
		echo "[FAIL] Max retries ($MAX_RETRIES) reached. Plan still incomplete:"
		plan_summary
		exit 1
	fi

	REMAINING=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE plan_id = $PLAN_ID AND status NOT IN ('done','validated','skipped','cancelled');")
	echo ""
	echo "[Run $RETRY/$MAX_RETRIES] $REMAINING tasks remaining..."
	plan_summary
	echo ""

	# Reset any stuck in_progress tasks from previous crashed run
	sqlite3 "$DB" "UPDATE tasks SET status='pending' WHERE plan_id = $PLAN_ID AND status='in_progress';"

	copilot --yolo -p "@execute $PLAN_ID" 2>&1
	EXIT_CODE=$?

	echo ""
	echo "[Run $RETRY] Copilot exited (code $EXIT_CODE). Checking progress..."
	sleep 2
done

echo ""
echo "=== Plan #$PLAN_ID COMPLETE ==="
plan_summary
