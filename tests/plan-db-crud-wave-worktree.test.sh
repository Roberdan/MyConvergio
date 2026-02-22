#!/bin/bash
# Test suite for wave worktree CRUD commands in plan-db-crud.sh
# TDD: written before implementation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/scripts/lib"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_start() {
	TESTS_RUN=$((TESTS_RUN + 1))
	echo -n "  [$TESTS_RUN] $1 ... "
}
test_pass() {
	TESTS_PASSED=$((TESTS_PASSED + 1))
	echo "PASS"
}
test_fail() {
	TESTS_FAILED=$((TESTS_FAILED + 1))
	echo "FAIL: $1"
}

# ---------------------------------------------------------------------------
# Helper: create temp DB with post-v8 waves schema
# ---------------------------------------------------------------------------
make_test_db() {
	local db
	db=$(mktemp "/tmp/test-crud-ww.XXXXXX")
	sqlite3 "$db" <<'SQL'
CREATE TABLE IF NOT EXISTS projects (id TEXT PRIMARY KEY, name TEXT NOT NULL);
INSERT INTO projects VALUES ('test-project', 'Test Project');
CREATE TABLE IF NOT EXISTS waves (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  wave_id TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL,
  plan_id INTEGER,
  tasks_done INTEGER DEFAULT 0,
  tasks_total INTEGER DEFAULT 0,
  worktree_path TEXT,
  branch_name TEXT,
  pr_number INTEGER,
  pr_url TEXT
);
INSERT INTO waves (project_id, wave_id, name, status, plan_id)
  VALUES ('test-project', 'W0', 'Setup', 'pending', 1);
SQL
	echo "$db"
}

# Helper: run code with a specific DB_FILE (override AFTER sourcing core)
run_with_db() {
	local db="$1"
	local code="$2"
	bash -c "
		source '$LIB_DIR/plan-db-core.sh' 2>/dev/null
		source '$LIB_DIR/plan-db-crud.sh' 2>/dev/null
		DB_FILE='$db'
		$code
	" 2>/dev/null
}

# ---------------------------------------------------------------------------
# cmd_get_wave_worktree: returns expanded path when set
# ---------------------------------------------------------------------------
test_get_wave_worktree_returns_path() {
	test_start "cmd_get_wave_worktree() returns expanded path when set"
	local db
	db=$(make_test_db)
	sqlite3 "$db" "UPDATE waves SET worktree_path = '~/.claude-plan-197-W0' WHERE id = 1;"

	local result
	result=$(run_with_db "$db" "cmd_get_wave_worktree 1")
	rm -f "$db"

	local expected="$HOME/.claude-plan-197-W0"
	if [[ "$result" == "$expected" ]]; then
		test_pass
	else
		test_fail "expected '$expected', got '$result'"
	fi
}

# ---------------------------------------------------------------------------
# cmd_get_wave_worktree: exits with error when no path set
# ---------------------------------------------------------------------------
test_get_wave_worktree_exits_on_empty() {
	test_start "cmd_get_wave_worktree() exits with error when path not set"
	local db
	db=$(make_test_db)

	local exit_code=0
	run_with_db "$db" "cmd_get_wave_worktree 1" || exit_code=$?
	rm -f "$db"

	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit when path not set, got 0"
	fi
}

# ---------------------------------------------------------------------------
# cmd_set_wave_worktree: stores normalized path
# ---------------------------------------------------------------------------
test_set_wave_worktree_normalizes_path() {
	test_start "cmd_set_wave_worktree() stores normalized ~ path"
	local db
	db=$(make_test_db)

	local abs_path="$HOME/.claude-plan-197-W0"
	run_with_db "$db" "cmd_set_wave_worktree 1 '$abs_path'" 2>/dev/null || true

	local stored
	stored=$(sqlite3 "$db" "SELECT worktree_path FROM waves WHERE id = 1;")
	rm -f "$db"

	if [[ "$stored" == "~/.claude-plan-197-W0" ]]; then
		test_pass
	else
		test_fail "expected '~/.claude-plan-197-W0', got '$stored'"
	fi
}

# ---------------------------------------------------------------------------
# round-trip: set then get returns same absolute path
# ---------------------------------------------------------------------------
test_wave_worktree_round_trip() {
	test_start "set-wave-worktree then get-wave-worktree returns same path"
	local db
	db=$(make_test_db)

	local abs_path="$HOME/.claude-plan-197-W0"
	run_with_db "$db" "cmd_set_wave_worktree 1 '$abs_path'" 2>/dev/null || true

	local result
	result=$(run_with_db "$db" "cmd_get_wave_worktree 1")
	rm -f "$db"

	if [[ "$result" == "$abs_path" ]]; then
		test_pass
	else
		test_fail "expected '$abs_path', got '$result'"
	fi
}

# ---------------------------------------------------------------------------
# cmd_update_wave: accepts 'merging' status
# ---------------------------------------------------------------------------
test_update_wave_accepts_merging() {
	test_start "cmd_update_wave() accepts 'merging' status without error"
	local db
	db=$(make_test_db)

	local exit_code=0
	run_with_db "$db" "cmd_update_wave 1 merging" 2>/dev/null || exit_code=$?
	rm -f "$db"

	if [[ $exit_code -eq 0 ]]; then
		test_pass
	else
		test_fail "expected exit 0 for 'merging' status, got $exit_code"
	fi
}

# ---------------------------------------------------------------------------
# cmd_update_wave: rejects invalid status
# ---------------------------------------------------------------------------
test_update_wave_rejects_invalid_status() {
	test_start "cmd_update_wave() rejects invalid status"
	local db
	db=$(make_test_db)

	local exit_code=0
	run_with_db "$db" "cmd_update_wave 1 invalid_status" 2>/dev/null || exit_code=$?
	rm -f "$db"

	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit for invalid status"
	fi
}

# ---------------------------------------------------------------------------
# plan-db.sh dispatch: get-wave-worktree routed (missing arg => usage error)
# ---------------------------------------------------------------------------
test_dispatch_get_wave_worktree() {
	test_start "plan-db.sh dispatches get-wave-worktree command"
	local result
	result=$(bash "$SCRIPT_DIR/scripts/plan-db.sh" get-wave-worktree 2>&1 || true)
	if echo "$result" | grep -q "wave_db_id required"; then
		test_pass
	else
		test_fail "expected 'wave_db_id required' error, got: $result"
	fi
}

test_dispatch_set_wave_worktree() {
	test_start "plan-db.sh dispatches set-wave-worktree command"
	local result
	result=$(bash "$SCRIPT_DIR/scripts/plan-db.sh" set-wave-worktree 2>&1 || true)
	if echo "$result" | grep -q "wave_db_id required"; then
		test_pass
	else
		test_fail "expected 'wave_db_id required' error, got: $result"
	fi
}

# ---------------------------------------------------------------------------
# help text contains new commands
# ---------------------------------------------------------------------------
test_help_contains_get_wave_worktree() {
	test_start "plan-db.sh help contains get-wave-worktree"
	local help_text
	help_text=$(bash "$SCRIPT_DIR/scripts/plan-db.sh" _no_such_cmd_ 2>&1 || true)
	if echo "$help_text" | grep -q "get-wave-worktree"; then
		test_pass
	else
		test_fail "help text missing 'get-wave-worktree'"
	fi
}

test_help_contains_set_wave_worktree() {
	test_start "plan-db.sh help contains set-wave-worktree"
	local help_text
	help_text=$(bash "$SCRIPT_DIR/scripts/plan-db.sh" _no_such_cmd_ 2>&1 || true)
	if echo "$help_text" | grep -q "set-wave-worktree"; then
		test_pass
	else
		test_fail "help text missing 'set-wave-worktree'"
	fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
echo ""
echo "=== plan-db-crud wave worktree Test Suite ==="
echo ""

test_get_wave_worktree_returns_path
test_get_wave_worktree_exits_on_empty
test_set_wave_worktree_normalizes_path
test_wave_worktree_round_trip
test_update_wave_accepts_merging
test_update_wave_rejects_invalid_status
test_dispatch_get_wave_worktree
test_dispatch_set_wave_worktree
test_help_contains_get_wave_worktree
test_help_contains_set_wave_worktree

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed"
if [[ $TESTS_FAILED -gt 0 ]]; then
	exit 1
fi
exit 0
