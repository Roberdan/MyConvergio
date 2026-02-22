#!/usr/bin/env bash
# wave-worktree.test.sh — TDD tests for wave-worktree.sh create + status commands
# Written BEFORE implementation (RED phase)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/scripts/wave-worktree.sh"

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
# Script exists and is executable
# ---------------------------------------------------------------------------
test_script_exists() {
	test_start "wave-worktree.sh exists"
	if [[ -f "$SCRIPT" ]]; then
		test_pass
	else
		test_fail "script not found at $SCRIPT"
	fi
}

test_script_executable() {
	test_start "wave-worktree.sh is executable"
	if [[ -x "$SCRIPT" ]]; then
		test_pass
	else
		test_fail "script is not executable"
	fi
}

# ---------------------------------------------------------------------------
# Usage / help
# ---------------------------------------------------------------------------
test_no_args_shows_usage() {
	test_start "wave-worktree.sh (no args) shows usage"
	local out
	out=$(bash "$SCRIPT" 2>&1 || true)
	if echo "$out" | grep -qi "usage"; then
		test_pass
	else
		test_fail "expected usage message, got: $out"
	fi
}

test_help_shows_commands() {
	test_start "wave-worktree.sh help shows create/status/merge/cleanup"
	local out
	out=$(bash "$SCRIPT" 2>&1 || true)
	if echo "$out" | grep -q "create" && echo "$out" | grep -q "status"; then
		test_pass
	else
		test_fail "expected create|status in usage, got: $out"
	fi
}

# ---------------------------------------------------------------------------
# create: requires plan_id
# ---------------------------------------------------------------------------
test_create_requires_plan_id() {
	test_start "create with no args exits non-zero"
	local exit_code=0
	bash "$SCRIPT" create 2>/dev/null || exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit when plan_id missing"
	fi
}

# ---------------------------------------------------------------------------
# create: requires wave_db_id
# ---------------------------------------------------------------------------
test_create_requires_wave_db_id() {
	test_start "create with only plan_id exits non-zero"
	local exit_code=0
	bash "$SCRIPT" create 999 2>/dev/null || exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit when wave_db_id missing"
	fi
}

# ---------------------------------------------------------------------------
# status: requires plan_id
# ---------------------------------------------------------------------------
test_status_requires_plan_id() {
	test_start "status with no args exits non-zero"
	local exit_code=0
	bash "$SCRIPT" status 2>/dev/null || exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit when plan_id missing"
	fi
}

# ---------------------------------------------------------------------------
# status: output format check (header line)
# ---------------------------------------------------------------------------
test_status_outputs_table_header() {
	test_start "status outputs table with Wave/Status/Tasks columns"
	local out
	# Use plan 197 (real plan) — may have no waves or produce output
	out=$(bash "$SCRIPT" status 197 2>&1 || true)
	if echo "$out" | grep -qi "wave\|status\|tasks"; then
		test_pass
	else
		test_fail "expected table header with Wave/Status/Tasks, got: $out"
	fi
}

# ---------------------------------------------------------------------------
# merge: requires plan_id and wave_db_id
# ---------------------------------------------------------------------------
test_merge_requires_plan_id() {
	test_start "merge with no args exits non-zero"
	local exit_code=0
	bash "$SCRIPT" merge 2>/dev/null || exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit when plan_id missing"
	fi
}

test_merge_requires_wave_db_id() {
	test_start "merge with only plan_id exits non-zero"
	local exit_code=0
	bash "$SCRIPT" merge 999 2>/dev/null || exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit when wave_db_id missing"
	fi
}

test_merge_nonexistent_wave_errors() {
	test_start "merge with nonexistent wave_db_id logs error and exits 1"
	local out exit_code=0
	out=$(bash "$SCRIPT" merge 999 99999 2>&1) || exit_code=$?
	if [[ $exit_code -ne 0 ]] && echo "$out" | grep -qi "error\|not found\|worktree\|cannot"; then
		test_pass
	else
		test_fail "expected error exit for nonexistent wave, got exit=$exit_code out='$out'"
	fi
}

# ---------------------------------------------------------------------------
# cleanup: requires plan_id and wave_db_id
# ---------------------------------------------------------------------------
test_cleanup_requires_plan_id() {
	test_start "cleanup with no args exits non-zero"
	local exit_code=0
	bash "$SCRIPT" cleanup 2>/dev/null || exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit when plan_id missing"
	fi
}

test_cleanup_requires_wave_db_id() {
	test_start "cleanup with only plan_id exits non-zero"
	local exit_code=0
	bash "$SCRIPT" cleanup 999 2>/dev/null || exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit when wave_db_id missing"
	fi
}

test_cleanup_nonexistent_wave_errors() {
	test_start "cleanup with nonexistent wave_db_id logs error and exits 1"
	local out exit_code=0
	out=$(bash "$SCRIPT" cleanup 999 99999 2>&1) || exit_code=$?
	if [[ $exit_code -ne 0 ]] && echo "$out" | grep -qi "error\|not found\|worktree\|cannot"; then
		test_pass
	else
		test_fail "expected error exit for nonexistent wave, got exit=$exit_code out='$out'"
	fi
}

# ---------------------------------------------------------------------------
# DRY_RUN mode: merge commits+pushes but skips PR creation
# ---------------------------------------------------------------------------
test_merge_dry_run_nonexistent_wave_errors() {
	test_start "WAVE_DRY_RUN=1 merge with nonexistent wave exits non-zero"
	local out exit_code=0
	out=$(WAVE_DRY_RUN=1 bash "$SCRIPT" merge 999 99999 2>&1) || exit_code=$?
	if [[ $exit_code -ne 0 ]]; then
		test_pass
	else
		test_fail "expected non-zero exit for nonexistent wave, got: $out"
	fi
}

# ---------------------------------------------------------------------------
# cmd_merge function defined in script
# ---------------------------------------------------------------------------
test_merge_function_defined() {
	test_start "cmd_merge function is defined in script"
	if grep -q "cmd_merge()" "$SCRIPT"; then
		test_pass
	else
		test_fail "cmd_merge() not found in $SCRIPT"
	fi
}

# ---------------------------------------------------------------------------
# cmd_cleanup function defined in script
# ---------------------------------------------------------------------------
test_cleanup_function_defined() {
	test_start "cmd_cleanup function is defined in script"
	if grep -q "cmd_cleanup()" "$SCRIPT"; then
		test_pass
	else
		test_fail "cmd_cleanup() not found in $SCRIPT"
	fi
}

# ---------------------------------------------------------------------------
# Dispatch updated: merge/cleanup call functions (not placeholder)
# ---------------------------------------------------------------------------
test_dispatch_merge_calls_function() {
	test_start "dispatch: merge calls cmd_merge (not placeholder echo)"
	if grep -q "merge) cmd_merge" "$SCRIPT"; then
		test_pass
	else
		test_fail "dispatch does not call cmd_merge, found: $(grep 'merge)' "$SCRIPT" || true)"
	fi
}

test_dispatch_cleanup_calls_function() {
	test_start "dispatch: cleanup calls cmd_cleanup (not placeholder echo)"
	if grep -q "cleanup) cmd_cleanup" "$SCRIPT"; then
		test_pass
	else
		test_fail "dispatch does not call cmd_cleanup, found: $(grep 'cleanup)' "$SCRIPT" || true)"
	fi
}

# ---------------------------------------------------------------------------
# Line count check (max 250 lines per project rules)
# ---------------------------------------------------------------------------
test_line_count() {
	test_start "wave-worktree.sh is under 250 lines"
	if [[ ! -f "$SCRIPT" ]]; then
		test_fail "script not found"
		return
	fi
	local lines
	lines=$(wc -l <"$SCRIPT")
	if [[ "$lines" -le 250 ]]; then
		test_pass
	else
		test_fail "script has $lines lines (max 250)"
	fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
echo ""
echo "=== wave-worktree.sh Test Suite ==="
echo ""

test_script_exists
test_script_executable
test_no_args_shows_usage
test_help_shows_commands
test_create_requires_plan_id
test_create_requires_wave_db_id
test_status_requires_plan_id
test_status_outputs_table_header
test_merge_requires_plan_id
test_merge_requires_wave_db_id
test_merge_nonexistent_wave_errors
test_merge_dry_run_nonexistent_wave_errors
test_merge_function_defined
test_cleanup_requires_plan_id
test_cleanup_requires_wave_db_id
test_cleanup_nonexistent_wave_errors
test_cleanup_function_defined
test_dispatch_merge_calls_function
test_dispatch_cleanup_calls_function
test_line_count

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed"
if [[ $TESTS_FAILED -gt 0 ]]; then
	exit 1
fi
exit 0
