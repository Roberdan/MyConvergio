#!/bin/bash
# Test suite for plan-db-validate.sh
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$TEST_ROOT/scripts:$PATH"

# Setup test DB - must be set BEFORE sourcing
TEST_DB="/tmp/test-plan-db-validate-$$.db"

# Override DB_FILE before sourcing core
DB_FILE="$TEST_DB"
export DB_FILE

# Load plan-db functions
source "$TEST_ROOT/scripts/lib/plan-db-core.sh"
source "$TEST_ROOT/scripts/lib/plan-db-validate.sh"

# Re-export DB_FILE after sourcing to ensure it's not overridden
DB_FILE="$TEST_DB"
export DB_FILE

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helpers
test_start() {
	((TESTS_RUN++))
	echo -n "  [$TESTS_RUN] $1 ... "
}

test_pass() {
	((TESTS_PASSED++))
	echo "✓ PASS"
}

test_fail() {
	((TESTS_FAILED++))
	echo "✗ FAIL: $1"
}

# Setup test database
setup_test_db() {
	rm -f "$TEST_DB"
	sqlite3 "$TEST_DB" <<-SQL
		CREATE TABLE IF NOT EXISTS plans (
			id INTEGER PRIMARY KEY,
			project_id TEXT,
			name TEXT,
			status TEXT DEFAULT 'pending',
			tasks_done INTEGER DEFAULT 0,
			tasks_total INTEGER DEFAULT 0,
			validated_at TEXT,
			validated_by TEXT,
			completed_at TEXT
		);
		CREATE TABLE IF NOT EXISTS waves (
			id INTEGER PRIMARY KEY,
			plan_id INTEGER,
			wave_id TEXT,
			status TEXT DEFAULT 'pending',
			tasks_done INTEGER DEFAULT 0,
			tasks_total INTEGER DEFAULT 0,
			position INTEGER,
			completed_at TEXT
		);
		CREATE TABLE IF NOT EXISTS tasks (
			id INTEGER PRIMARY KEY,
			plan_id INTEGER,
			wave_id_fk INTEGER,
			task_id TEXT,
			title TEXT,
			status TEXT DEFAULT 'pending',
			validated_at TEXT,
			validated_by TEXT,
			wave_id TEXT
		);
	SQL
}

# T1-01: validate-task enforcement tests
test_validate_task_without_force_requires_thor() {
	test_start "validate-task without --force requires Thor agent"

	setup_test_db

	# Create test task
	sqlite3 "$TEST_DB" <<-SQL
		INSERT INTO plans (id, project_id, name) VALUES (1, 'test', 'test-plan');
		INSERT INTO waves (id, plan_id, wave_id, position) VALUES (1, 1, 'W1', 1);
		INSERT INTO tasks (id, plan_id, wave_id_fk, task_id, title, status)
		VALUES (1, 1, 1, 'T1-01', 'Test task', 'done');
	SQL

	# Try to validate with non-Thor agent - should warn but allow with --force
	local output
	output=$(cmd_validate_task 1 1 "random-agent" 2>&1 || echo "FAILED")

	if echo "$output" | grep -q "force"; then
		test_pass
	else
		test_fail "Expected warning about --force flag, got: $output"
	fi
}

test_validate_task_accepts_thor_agent() {
	test_start "validate-task accepts 'thor' agent without --force"

	setup_test_db

	# Create test task
	sqlite3 "$TEST_DB" <<-SQL
		INSERT INTO plans (id, project_id, name) VALUES (1, 'test', 'test-plan');
		INSERT INTO waves (id, plan_id, wave_id, position) VALUES (1, 1, 'W1', 1);
		INSERT INTO tasks (id, plan_id, wave_id_fk, task_id, title, status)
		VALUES (1, 1, 1, 'T1-01', 'Test task', 'done');
	SQL

	# Validate with thor agent - should succeed
	cmd_validate_task 1 1 "thor" >/dev/null 2>&1
	local exit_code=$?

	if [[ $exit_code -eq 0 ]]; then
		test_pass
	else
		test_fail "Expected thor validation to succeed, got exit code: $exit_code"
	fi
}

test_validate_task_accepts_thor_quality_assurance_guardian() {
	test_start "validate-task accepts 'thor-quality-assurance-guardian' agent"

	setup_test_db

	# Create test task
	sqlite3 "$TEST_DB" <<-SQL
		INSERT INTO plans (id, project_id, name) VALUES (1, 'test', 'test-plan');
		INSERT INTO waves (id, plan_id, wave_id, position) VALUES (1, 1, 'W1', 1);
		INSERT INTO tasks (id, plan_id, wave_id_fk, task_id, title, status)
		VALUES (1, 1, 1, 'T1-01', 'Test task', 'done');
	SQL

	# Validate with thor-quality-assurance-guardian - should succeed
	cmd_validate_task 1 1 "thor-quality-assurance-guardian" >/dev/null 2>&1
	local exit_code=$?

	if [[ $exit_code -eq 0 ]]; then
		test_pass
	else
		test_fail "Expected thor-quality-assurance-guardian validation to succeed"
	fi
}

# T1-02: validate-wave per-task check tests
test_validate_wave_checks_per_task_validation() {
	test_start "validate-wave checks that all done tasks are validated"

	setup_test_db

	# Create test wave with done but unvalidated task
	sqlite3 "$TEST_DB" <<-SQL
		INSERT INTO plans (id, project_id, name) VALUES (1, 'test', 'test-plan');
		INSERT INTO waves (id, plan_id, wave_id, position) VALUES (1, 1, 'W1', 1);
		INSERT INTO tasks (id, plan_id, wave_id_fk, task_id, title, status, validated_at)
		VALUES
			(1, 1, 1, 'T1-01', 'Task 1', 'done', NULL),
			(2, 1, 1, 'T1-02', 'Task 2', 'done', NULL);
	SQL

	# Try to validate wave - should fail with message about unvalidated tasks
	local output
	output=$(cmd_validate_wave 1 "thor" 2>&1 || echo "EXPECTED_FAILURE")

	if echo "$output" | grep -q "NOT validated"; then
		test_pass
	else
		test_fail "Expected error about unvalidated tasks, got: $output"
	fi
}

test_validate_wave_lists_unvalidated_tasks() {
	test_start "validate-wave lists unvalidated tasks"

	setup_test_db

	# Create test wave with unvalidated task
	sqlite3 "$TEST_DB" <<-SQL
		INSERT INTO plans (id, project_id, name) VALUES (1, 'test', 'test-plan');
		INSERT INTO waves (id, plan_id, wave_id, position) VALUES (1, 1, 'W1', 1);
		INSERT INTO tasks (id, plan_id, wave_id_fk, task_id, title, status, validated_at)
		VALUES (1, 1, 1, 'T1-01', 'Unvalidated task', 'done', NULL);
	SQL

	# Try to validate wave - should list the unvalidated task
	local output
	output=$(cmd_validate_wave 1 "thor" 2>&1 || echo "")

	if echo "$output" | grep -q "T1-01" && echo "$output" | grep -q "Unvalidated task"; then
		test_pass
	else
		test_fail "Expected to see task T1-01 listed, got: $output"
	fi
}

test_validate_wave_succeeds_when_all_validated() {
	test_start "validate-wave succeeds when all tasks are validated"

	setup_test_db

	# Create test wave with validated tasks
	sqlite3 "$TEST_DB" <<-SQL
		INSERT INTO plans (id, project_id, name) VALUES (1, 'test', 'test-plan');
		INSERT INTO waves (id, plan_id, wave_id, position) VALUES (1, 1, 'W1', 1);
		INSERT INTO tasks (id, plan_id, wave_id_fk, task_id, title, status, validated_at, validated_by)
		VALUES
			(1, 1, 1, 'T1-01', 'Task 1', 'done', datetime('now'), 'thor'),
			(2, 1, 1, 'T1-02', 'Task 2', 'done', datetime('now'), 'thor');
	SQL

	# Validate wave - should succeed
	cmd_validate_wave 1 "thor" >/dev/null 2>&1
	local exit_code=$?

	if [[ $exit_code -eq 0 ]]; then
		test_pass
	else
		test_fail "Expected validation to succeed when all tasks validated"
	fi
}

# Cleanup
cleanup() {
	rm -f "$TEST_DB"
}
trap cleanup EXIT

# Run all tests
echo "Running plan-db-validate.sh tests..."
echo

test_validate_task_without_force_requires_thor
test_validate_task_accepts_thor_agent
test_validate_task_accepts_thor_quality_assurance_guardian
test_validate_wave_checks_per_task_validation
test_validate_wave_lists_unvalidated_tasks
test_validate_wave_succeeds_when_all_validated

# Summary
echo
echo "================================"
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
	exit 1
fi

exit 0
