#!/bin/bash
# Test: dashboard-mini.sh waves subcommand
# TDD tests for W3-01 task 4063

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/dashboard-mini.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
	echo -e "${GREEN}PASS${NC} $1"
	((PASSED++))
}
fail() {
	echo -e "${RED}FAIL${NC} $1"
	((FAILED++))
}

# Test 1: cmd_waves function exists in the script
test_function_defined() {
	if grep -q "cmd_waves()" "$SCRIPT"; then
		pass "cmd_waves() function defined in dashboard-mini.sh"
	else
		fail "cmd_waves() function NOT defined in dashboard-mini.sh"
	fi
}

# Test 2: waves subcommand dispatch exists
test_dispatch_exists() {
	if grep -q "waves)" "$SCRIPT"; then
		pass "waves) dispatch case exists in dashboard-mini.sh"
	else
		fail "waves) dispatch case NOT found in dashboard-mini.sh"
	fi
}

# Test 3: help text mentions waves
test_help_mentions_waves() {
	if grep -q "waves" "$SCRIPT"; then
		pass "Script mentions 'waves'"
	else
		fail "Script does not mention 'waves'"
	fi
}

# Test 4: bash syntax check
test_syntax() {
	if bash -n "$SCRIPT" 2>/dev/null; then
		pass "Syntax check: dashboard-mini.sh"
	else
		fail "Syntax check FAILED: dashboard-mini.sh"
		bash -n "$SCRIPT" 2>&1
	fi
}

# Test 5: waves subcommand runs without crashing (with invalid plan_id returns gracefully)
test_waves_runs() {
	local output
	output=$(bash "$SCRIPT" waves 99999 2>&1)
	local exit_code=$?
	if echo "$output" | grep -q "Wave Worktrees\|No waves found"; then
		pass "waves subcommand runs and produces expected output"
	else
		fail "waves subcommand did not produce expected output: $output"
	fi
}

# Test 6: line count still <=250
test_line_count() {
	local count
	count=$(wc -l <"$SCRIPT" | tr -d ' ')
	if [ "$count" -le 250 ]; then
		pass "dashboard-mini.sh is $count lines (<=250)"
	else
		fail "dashboard-mini.sh is $count lines (>250 limit)"
	fi
}

echo -e "${YELLOW}Tests: dashboard-mini.sh waves subcommand${NC}"
echo ""

test_function_defined
test_dispatch_exists
test_help_mentions_waves
test_syntax
test_waves_runs
test_line_count

echo ""
echo -e "${YELLOW}========================${NC}"
echo -e "${GREEN}PASSED: $PASSED${NC}"
echo -e "${RED}FAILED: $FAILED${NC}"
echo -e "${YELLOW}========================${NC}"

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
