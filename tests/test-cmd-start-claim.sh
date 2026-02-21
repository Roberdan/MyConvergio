#!/bin/bash
# Test: cmd_start should call cmd_claim instead of directly setting execution_host
# Framework: bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/scripts/lib"

# Use the main dashboard DB for testing (safer than creating test DB)
export DB_FILE="${HOME}/.claude/data/dashboard.db"
TEST_HOST="test-host-$(date +%s)"
source "$LIB_DIR/plan-db-core.sh"
source "$LIB_DIR/plan-db-crud.sh"
source "$LIB_DIR/plan-db-cluster.sh"
# Re-export after core.sh clobbers PLAN_DB_HOST
export PLAN_DB_HOST="$TEST_HOST"

# Clean up any previous test plans
sqlite3 "$DB_FILE" "DELETE FROM plans WHERE project_id = 'test-project-claim' AND name LIKE 'Test Plan Claim%';" 2>/dev/null || true

# Create a test plan
plan_id=$(sqlite3 "$DB_FILE" "
	INSERT INTO plans (project_id, name, status, is_master, tasks_total)
	VALUES ('test-project-claim', 'Test Plan Claim 1', 'todo', 0, 1);
	SELECT last_insert_rowid();
")

echo "Test 1: cmd_start should call cmd_claim and set execution_host"
cmd_start "$plan_id"

# Verify execution_host is set
host=$(sqlite3 "$DB_FILE" "SELECT execution_host FROM plans WHERE id = $plan_id;")
status=$(sqlite3 "$DB_FILE" "SELECT status FROM plans WHERE id = $plan_id;")

if [[ "$host" == "$PLAN_DB_HOST" ]] && [[ "$status" == "doing" ]]; then
	echo "✓ PASS: execution_host set to $PLAN_DB_HOST, status is doing"
else
	echo "✗ FAIL: expected host=$PLAN_DB_HOST status=doing, got host=$host status=$status"
	exit 1
fi

# Create another plan for force test
plan_id2=$(sqlite3 "$DB_FILE" "
	INSERT INTO plans (project_id, name, status, is_master, tasks_total, execution_host)
	VALUES ('test-project-claim', 'Test Plan Claim 2', 'doing', 0, 1, 'other-host');
	SELECT last_insert_rowid();
")

echo "Test 2: cmd_start should fail when plan is claimed by another host"
if cmd_start "$plan_id2" 2>/dev/null; then
	echo "✗ FAIL: should have failed when plan claimed by other host"
	exit 1
else
	echo "✓ PASS: cmd_start correctly failed for plan claimed by other host"
fi

echo "Test 3: cmd_start --force should override claim"
cmd_start "$plan_id2" "--force"

host2=$(sqlite3 "$DB_FILE" "SELECT execution_host FROM plans WHERE id = $plan_id2;")
if [[ "$host2" == "$PLAN_DB_HOST" ]]; then
	echo "✓ PASS: --force successfully claimed plan from other host"
else
	echo "✗ FAIL: expected host=$PLAN_DB_HOST, got host=$host2"
	exit 1
fi

echo ""
echo "All tests passed!"
