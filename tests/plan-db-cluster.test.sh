#!/bin/bash
# Test suite for plan-db-cluster.sh
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_ROOT/scripts/lib/plan-db-core.sh"
source "$TEST_ROOT/scripts/lib/plan-db-cluster.sh"

# Test database
TEST_DB="/tmp/test-plan-db-cluster-$$.db"
export DB_FILE="$TEST_DB"

# Mock config_sync_check to avoid network calls in tests
config_sync_check() {
	echo "SYNCED"
	return 0
}

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
	sqlite3 "$TEST_DB" <<-'EOF'
		CREATE TABLE plans (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL,
			status TEXT DEFAULT 'backlog',
			execution_host TEXT,
			started_at DATETIME
		);
		CREATE TABLE host_heartbeats (
			host TEXT PRIMARY KEY NOT NULL,
			last_seen DATETIME NOT NULL,
			plan_count INTEGER DEFAULT 0,
			os TEXT
		);
		INSERT INTO plans (id, name, status) VALUES (1, 'Test Plan', 'pending');
		INSERT INTO plans (id, name, status) VALUES (2, 'Another Plan', 'pending');
	EOF
}

# Cleanup
cleanup() {
	rm -f "$TEST_DB"
}
trap cleanup EXIT

# Test cmd_claim exists
test_cmd_claim_exists() {
	test_start "cmd_claim() function exists"
	if declare -F cmd_claim &>/dev/null; then
		test_pass
	else
		test_fail "cmd_claim function not found"
	fi
}

# Test cmd_release exists
test_cmd_release_exists() {
	test_start "cmd_release() function exists"
	if declare -F cmd_release &>/dev/null; then
		test_pass
	else
		test_fail "cmd_release function not found"
	fi
}

# Test cmd_heartbeat exists
test_cmd_heartbeat_exists() {
	test_start "cmd_heartbeat() function exists"
	if declare -F cmd_heartbeat &>/dev/null; then
		test_pass
	else
		test_fail "cmd_heartbeat function not found"
	fi
}

# Test cmd_is_alive exists
test_cmd_is_alive_exists() {
	test_start "cmd_is_alive() function exists"
	if declare -F cmd_is_alive &>/dev/null; then
		test_pass
	else
		test_fail "cmd_is_alive function not found"
	fi
}

# Test cmd_claim atomicity
test_cmd_claim_atomic() {
	test_start "cmd_claim() claims unclaimed plan"
	setup_test_db

	cmd_claim 1 &>/dev/null || true

	local host=$(sqlite3 "$TEST_DB" "SELECT execution_host FROM plans WHERE id=1")
	local status=$(sqlite3 "$TEST_DB" "SELECT status FROM plans WHERE id=1")

	if [[ "$host" == "$PLAN_DB_HOST" ]] && [[ "$status" == "doing" ]]; then
		test_pass
	else
		test_fail "Plan not claimed correctly (host=$host, status=$status)"
	fi
}

# Test cmd_claim prevents double claim
test_cmd_claim_prevents_double_claim() {
	test_start "cmd_claim() prevents claiming already claimed plan"
	setup_test_db

	# First claim
	cmd_claim 1 &>/dev/null || true

	# Try to claim with different host (simulate)
	local result=$(sqlite3 "$TEST_DB" "UPDATE plans SET execution_host='other-host' WHERE id=1 AND execution_host='$PLAN_DB_HOST'; SELECT changes();" 2>&1)

	# Try second claim without force
	if cmd_claim 1 &>/dev/null; then
		test_fail "Should have failed to claim already-claimed plan"
	else
		test_pass
	fi
}

# Test cmd_claim with --force
test_cmd_claim_force() {
	test_start "cmd_claim() with --force overrides existing claim"
	setup_test_db

	# Set plan as claimed by another host
	sqlite3 "$TEST_DB" "UPDATE plans SET execution_host='other-host', status='doing' WHERE id=1"

	cmd_claim 1 --force &>/dev/null || true

	local host=$(sqlite3 "$TEST_DB" "SELECT execution_host FROM plans WHERE id=1")

	if [[ "$host" == "$PLAN_DB_HOST" ]]; then
		test_pass
	else
		test_fail "Force claim failed (host=$host)"
	fi
}

# Test cmd_release
test_cmd_release_releases_claim() {
	test_start "cmd_release() releases claimed plan"
	setup_test_db

	# Claim first
	cmd_claim 1 &>/dev/null || true

	# Release
	cmd_release 1 &>/dev/null || true

	local host=$(sqlite3 "$TEST_DB" "SELECT execution_host FROM plans WHERE id=1")

	if [[ -z "$host" ]]; then
		test_pass
	else
		test_fail "Plan not released (host=$host)"
	fi
}

# Test cmd_heartbeat writes record
test_cmd_heartbeat_writes() {
	test_start "cmd_heartbeat() writes heartbeat record"
	setup_test_db

	cmd_heartbeat &>/dev/null || true

	local host=$(sqlite3 "$TEST_DB" "SELECT host FROM host_heartbeats WHERE host='$PLAN_DB_HOST'")

	if [[ "$host" == "$PLAN_DB_HOST" ]]; then
		test_pass
	else
		test_fail "Heartbeat not written"
	fi
}

# Test cmd_heartbeat updates plan_count
test_cmd_heartbeat_plan_count() {
	test_start "cmd_heartbeat() updates plan_count"
	setup_test_db

	# Claim a plan
	cmd_claim 1 &>/dev/null || true

	# Write heartbeat
	cmd_heartbeat &>/dev/null || true

	local count=$(sqlite3 "$TEST_DB" "SELECT plan_count FROM host_heartbeats WHERE host='$PLAN_DB_HOST'")

	if [[ "$count" == "1" ]]; then
		test_pass
	else
		test_fail "Plan count incorrect (count=$count)"
	fi
}

# Test cmd_is_alive with recent heartbeat
test_cmd_is_alive_recent() {
	test_start "cmd_is_alive() returns ALIVE for recent heartbeat"
	setup_test_db

	# Write recent heartbeat
	sqlite3 "$TEST_DB" "INSERT INTO host_heartbeats (host, last_seen, plan_count) VALUES ('test-host', datetime('now'), 0)"

	local result=$(cmd_is_alive test-host 2>/dev/null)

	if [[ "$result" == "ALIVE" ]]; then
		test_pass
	else
		test_fail "Expected ALIVE, got $result"
	fi
}

# Test cmd_is_alive with stale heartbeat
test_cmd_is_alive_stale() {
	test_start "cmd_is_alive() detects stale heartbeat"
	setup_test_db

	# Write old heartbeat (10 minutes ago)
	sqlite3 "$TEST_DB" "INSERT INTO host_heartbeats (host, last_seen, plan_count) VALUES ('test-host', datetime('now', '-10 minutes'), 0)"

	local result=$(cmd_is_alive test-host 2>/dev/null)

	# Will be STALE or UNREACHABLE depending on SSH
	if [[ "$result" == "STALE" ]] || [[ "$result" == "UNREACHABLE" ]]; then
		test_pass
	else
		test_fail "Expected STALE or UNREACHABLE, got $result"
	fi
}

# Run all tests
echo "Running plan-db-cluster.sh tests..."
echo

test_cmd_claim_exists
test_cmd_release_exists
test_cmd_heartbeat_exists
test_cmd_is_alive_exists
test_cmd_claim_atomic
test_cmd_claim_prevents_double_claim
test_cmd_claim_force
test_cmd_release_releases_claim
test_cmd_heartbeat_writes
test_cmd_heartbeat_plan_count
test_cmd_is_alive_recent
test_cmd_is_alive_stale

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
