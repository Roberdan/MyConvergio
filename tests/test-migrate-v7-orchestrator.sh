#!/usr/bin/env bash
# Test: migrate-v7-orchestrator.sh
# Verifies: delegation_log table, env_vault_log table, indexes, views
# TDD: Written BEFORE implementation
# Version: 1.0.0
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATION="${SCRIPT_DIR}/scripts/migrate-v7-orchestrator.sh"
TEST_DB=$(mktemp "/tmp/test-migrate-v7-XXXXXX.db")

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
	rm -f "$TEST_DB"
}
trap cleanup EXIT

test_pass() {
	TESTS_PASSED=$((TESTS_PASSED + 1))
	echo "  [PASS] $1"
}

test_fail() {
	TESTS_FAILED=$((TESTS_FAILED + 1))
	echo "  [FAIL] $1: $2"
}

t() {
	TESTS_RUN=$((TESTS_RUN + 1))
}

echo "=== migrate-v7-orchestrator.sh Tests ==="
echo ""

# Test 1: Script exists and is executable
t
if [[ -x "$MIGRATION" ]]; then
	test_pass "Script exists and is executable"
else
	test_fail "Script exists and is executable" "file not found or not executable at $MIGRATION"
	echo ""
	echo "=== Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed ==="
	exit 1
fi

# Setup: create minimal DB and run migration
sqlite3 "$TEST_DB" "SELECT 1;" >/dev/null

# Test 2: Migration exits 0
t
if DB_FILE="$TEST_DB" bash "$MIGRATION" >/dev/null 2>&1; then
	test_pass "Migration exits 0 on first run"
else
	test_fail "Migration exits 0 on first run" "non-zero exit"
	echo ""
	echo "=== Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed ==="
	exit 1
fi

# Test 3: Idempotent - second run also exits 0
t
if DB_FILE="$TEST_DB" bash "$MIGRATION" >/dev/null 2>&1; then
	test_pass "Migration idempotent (second run exits 0)"
else
	test_fail "Migration idempotent (second run exits 0)" "non-zero exit on second run"
fi

# Test 4: delegation_log table exists
t
RESULT=$(sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='delegation_log';")
if [[ "$RESULT" == "delegation_log" ]]; then
	test_pass "delegation_log table exists"
else
	test_fail "delegation_log table exists" "table not found"
fi

# Test 5: delegation_log columns
t
COLS=$(sqlite3 "$TEST_DB" "PRAGMA table_info(delegation_log);" | awk -F'|' '{print $2}' | tr '\n' ',')
EXPECTED_COLS="id,task_db_id,plan_id,project_id,provider,model,prompt_tokens,response_tokens,duration_ms,exit_code,thor_result,cost_estimate,privacy_level,created_at,"
if [[ "$COLS" == "$EXPECTED_COLS" ]]; then
	test_pass "delegation_log has all required columns"
else
	test_fail "delegation_log has all required columns" "got: $COLS, want: $EXPECTED_COLS"
fi

# Test 6: delegation_log cost_estimate is REAL type
t
COL_TYPE=$(sqlite3 "$TEST_DB" "PRAGMA table_info(delegation_log);" | awk -F'|' '$2=="cost_estimate"{print $3}')
if [[ "$COL_TYPE" == "REAL" ]]; then
	test_pass "cost_estimate column is REAL type"
else
	test_fail "cost_estimate column is REAL type" "got: $COL_TYPE"
fi

# Test 7: env_vault_log table exists
t
RESULT=$(sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='env_vault_log';")
if [[ "$RESULT" == "env_vault_log" ]]; then
	test_pass "env_vault_log table exists"
else
	test_fail "env_vault_log table exists" "table not found"
fi

# Test 8: env_vault_log columns
t
COLS=$(sqlite3 "$TEST_DB" "PRAGMA table_info(env_vault_log);" | awk -F'|' '{print $2}' | tr '\n' ',')
EXPECTED_COLS="id,project_id,action,target,vars_count,env_file,status,error_message,created_at,"
if [[ "$COLS" == "$EXPECTED_COLS" ]]; then
	test_pass "env_vault_log has all required columns"
else
	test_fail "env_vault_log has all required columns" "got: $COLS, want: $EXPECTED_COLS"
fi

# Test 9: env_vault_log action CHECK constraint (backup, restore, diff, audit)
t
if sqlite3 "$TEST_DB" "INSERT INTO env_vault_log(project_id,action,target,status) VALUES('test','INVALID','gh','success');" 2>/dev/null; then
	test_fail "env_vault_log action CHECK constraint" "invalid action accepted"
else
	test_pass "env_vault_log action CHECK rejects invalid values"
fi

# Test 10: env_vault_log target CHECK constraint (gh, az, both)
t
if sqlite3 "$TEST_DB" "INSERT INTO env_vault_log(project_id,action,target,status) VALUES('test','backup','INVALID','success');" 2>/dev/null; then
	test_fail "env_vault_log target CHECK constraint" "invalid target accepted"
else
	test_pass "env_vault_log target CHECK rejects invalid values"
fi

# Test 11: env_vault_log status CHECK constraint (success, error)
t
if sqlite3 "$TEST_DB" "INSERT INTO env_vault_log(project_id,action,target,status) VALUES('test','backup','gh','INVALID');" 2>/dev/null; then
	test_fail "env_vault_log status CHECK constraint" "invalid status accepted"
else
	test_pass "env_vault_log status CHECK rejects invalid values"
fi

# Test 12: Valid insertion into delegation_log
t
if sqlite3 "$TEST_DB" "INSERT INTO delegation_log(task_db_id,plan_id,project_id,provider,model,prompt_tokens,response_tokens,duration_ms,exit_code,thor_result,cost_estimate,privacy_level) VALUES(1,1,'proj','anthropic','claude-sonnet-4-6',1000,500,2000,0,'PASS',0.015,'internal');" 2>/dev/null; then
	test_pass "delegation_log accepts valid insertion"
else
	test_fail "delegation_log accepts valid insertion" "insert failed"
fi

# Test 13: Valid insertion into env_vault_log
t
if sqlite3 "$TEST_DB" "INSERT INTO env_vault_log(project_id,action,target,vars_count,env_file,status) VALUES('proj','backup','gh',5,'.env','success');" 2>/dev/null; then
	test_pass "env_vault_log accepts valid insertion"
else
	test_fail "env_vault_log accepts valid insertion" "insert failed"
fi

# Test 14: v_model_effectiveness view exists
t
RESULT=$(sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='view' AND name='v_model_effectiveness';")
if [[ "$RESULT" == "v_model_effectiveness" ]]; then
	test_pass "v_model_effectiveness view exists"
else
	test_fail "v_model_effectiveness view exists" "view not found"
fi

# Test 15: v_daily_cost view exists
t
RESULT=$(sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='view' AND name='v_daily_cost';")
if [[ "$RESULT" == "v_daily_cost" ]]; then
	test_pass "v_daily_cost view exists"
else
	test_fail "v_daily_cost view exists" "view not found"
fi

# Test 16: v_delegation_summary view exists
t
RESULT=$(sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='view' AND name='v_delegation_summary';")
if [[ "$RESULT" == "v_delegation_summary" ]]; then
	test_pass "v_delegation_summary view exists"
else
	test_fail "v_delegation_summary view exists" "view not found"
fi

# Test 17: v_env_vault_status view exists
t
RESULT=$(sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='view' AND name='v_env_vault_status';")
if [[ "$RESULT" == "v_env_vault_status" ]]; then
	test_pass "v_env_vault_status view exists"
else
	test_fail "v_env_vault_status view exists" "view not found"
fi

# Test 18: v_model_effectiveness is queryable
t
if sqlite3 "$TEST_DB" "SELECT * FROM v_model_effectiveness LIMIT 0;" 2>/dev/null; then
	test_pass "v_model_effectiveness is queryable"
else
	test_fail "v_model_effectiveness is queryable" "query failed"
fi

# Test 19: Indexes exist
t
IDX_COUNT=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND (tbl_name='delegation_log' OR tbl_name='env_vault_log') AND name NOT LIKE 'sqlite_%';")
if [[ "$IDX_COUNT" -ge 2 ]]; then
	test_pass "Indexes created on new tables (count: $IDX_COUNT)"
else
	test_fail "Indexes created on new tables" "got $IDX_COUNT indexes, want >= 2"
fi

echo ""
echo "=== Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed ==="

if [[ "$TESTS_FAILED" -gt 0 ]]; then
	exit 1
fi
exit 0
