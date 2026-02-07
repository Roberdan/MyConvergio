#!/bin/bash
# Test suite for plan-db-core.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/plan-db-core.sh"

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

# Test load_sync_config
test_load_sync_config() {
	test_start "load_sync_config() loads config file"

	load_sync_config

	if [[ -n "$REMOTE_HOST" ]] && [[ -n "$REMOTE_DB" ]]; then
		test_pass
	else
		test_fail "REMOTE_HOST or REMOTE_DB not set"
	fi
}

# Test get_remote_host
test_get_remote_host() {
	test_start "get_remote_host() returns host"

	local result=$(get_remote_host)

	if [[ -n "$result" ]]; then
		test_pass
	else
		test_fail "get_remote_host returned empty"
	fi
}

# Test ssh_check exists and is callable
test_ssh_check_exists() {
	test_start "ssh_check() function exists"

	if declare -F ssh_check &>/dev/null; then
		test_pass
	else
		test_fail "ssh_check function not found"
	fi
}

# Test config_sync_check exists
test_config_sync_check_exists() {
	test_start "config_sync_check() function exists"

	if declare -F config_sync_check &>/dev/null; then
		test_pass
	else
		test_fail "config_sync_check function not found"
	fi
}

# Test PLAN_DB_HOST export
test_plan_db_host_exported() {
	test_start "PLAN_DB_HOST is exported"

	if [[ -n "${PLAN_DB_HOST:-}" ]]; then
		test_pass
	else
		test_fail "PLAN_DB_HOST not set"
	fi
}

# Run all tests
echo "Running plan-db-core.sh tests..."
echo

test_load_sync_config
test_get_remote_host
test_ssh_check_exists
test_config_sync_check_exists
test_plan_db_host_exported

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
