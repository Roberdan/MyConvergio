#!/bin/bash
# Test suite for hooks/enforce-line-limit.sh
# Tests that line limit enforcer detects files >250 lines
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="${SCRIPT_DIR}/../hooks/enforce-line-limit.sh"

# Test framework
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
	echo "✓ $1"
	((++TESTS_PASSED))
}

test_fail() {
	echo "✗ $1"
	echo "  Expected: $2"
	echo "  Got: $3"
	((++TESTS_FAILED))
}

run_test() {
	local test_name="$1"
	local file_path="$2"
	local expected_exit="$3"
	local expected_pattern="$4"

	local input_json="{\"toolName\":\"write\",\"toolArgs\":{\"file_path\":\"$file_path\"}}"
	local output
	local exit_code=0

	set +e # Temporarily disable exit on error
	output=$(echo "$input_json" | "$HOOK_PATH" 2>&1)
	exit_code=$?
	set -e # Re-enable exit on error

	if [ "$exit_code" -ne "$expected_exit" ]; then
		test_fail "$test_name" "exit $expected_exit" "exit $exit_code"
		return 0
	fi

	if [ -n "$expected_pattern" ] && ! echo "$output" | grep -q "$expected_pattern"; then
		test_fail "$test_name" "output containing '$expected_pattern'" "'$output'"
		return 0
	fi

	test_pass "$test_name"
	return 0
}

# Setup temp files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Test 1: Small file should pass
echo "Test 1: Small file (10 lines) passes"
SMALL_FILE="$TEMP_DIR/small.sh"
for i in {1..10}; do echo "line $i" >>"$SMALL_FILE"; done
run_test "Small file passes" "$SMALL_FILE" 0 ""

# Test 2: Exactly 250 lines should pass
echo "Test 2: File with exactly 250 lines passes"
EXACT_FILE="$TEMP_DIR/exact.sh"
for i in {1..250}; do echo "line $i" >>"$EXACT_FILE"; done
run_test "250 lines passes" "$EXACT_FILE" 0 ""

# Test 3: 251 lines should block
echo "Test 3: File with 251 lines blocked"
OVER_FILE="$TEMP_DIR/over.sh"
for i in {1..251}; do echo "line $i" >>"$OVER_FILE"; done
run_test "251 lines blocked" "$OVER_FILE" 1 "BLOCKED"

# Test 4: 500 lines should block
echo "Test 4: File with 500 lines blocked"
BIG_FILE="$TEMP_DIR/big.sh"
for i in {1..500}; do echo "line $i" >>"$BIG_FILE"; done
run_test "500 lines blocked" "$BIG_FILE" 1 "BLOCKED"

# Test 5: package-lock.json should be skipped
echo "Test 5: package-lock.json skipped"
LOCK_FILE="$TEMP_DIR/package-lock.json"
for i in {1..300}; do echo "line $i" >>"$LOCK_FILE"; done
run_test "package-lock.json skipped" "$LOCK_FILE" 0 ""

# Test 6: .lock files should be skipped
echo "Test 6: .lock files skipped"
LOCK_FILE="$TEMP_DIR/Gemfile.lock"
for i in {1..300}; do echo "line $i" >>"$LOCK_FILE"; done
run_test ".lock files skipped" "$LOCK_FILE" 0 ""

# Test 7: node_modules files should be skipped
echo "Test 7: node_modules files skipped"
mkdir -p "$TEMP_DIR/node_modules"
NODE_FILE="$TEMP_DIR/node_modules/lib.js"
for i in {1..300}; do echo "line $i" >>"$NODE_FILE"; done
run_test "node_modules skipped" "$NODE_FILE" 0 ""

# Test 8: .sqlite files should be skipped
echo "Test 8: .sqlite files skipped"
DB_FILE="$TEMP_DIR/test.sqlite"
for i in {1..300}; do echo "line $i" >>"$DB_FILE"; done
run_test ".sqlite files skipped" "$DB_FILE" 0 ""

# Test 9: vendor files should be skipped
echo "Test 9: vendor files skipped"
mkdir -p "$TEMP_DIR/vendor"
VENDOR_FILE="$TEMP_DIR/vendor/lib.php"
for i in {1..300}; do echo "line $i" >>"$VENDOR_FILE"; done
run_test "vendor files skipped" "$VENDOR_FILE" 0 ""

# Test 10: dist files should be skipped
echo "Test 10: dist files skipped"
mkdir -p "$TEMP_DIR/dist"
DIST_FILE="$TEMP_DIR/dist/bundle.js"
for i in {1..300}; do echo "line $i" >>"$DIST_FILE"; done
run_test "dist files skipped" "$DIST_FILE" 0 ""

# Test 11: Non-existent file should pass
echo "Test 11: Non-existent file passes"
run_test "Non-existent file" "$TEMP_DIR/nonexistent.sh" 0 ""

# Test 12: Empty path should pass
echo "Test 12: Empty path passes"
INPUT='{"toolName":"write","toolArgs":{"file_path":""}}'
set +e
OUTPUT=$(echo "$INPUT" | "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
	test_pass "Empty path passes"
else
	test_fail "Empty path passes" "exit 0" "exit $EXIT_CODE"
fi

# Test 13: .min.js files should be skipped
echo "Test 13: .min.js files skipped"
MIN_FILE="$TEMP_DIR/app.min.js"
for i in {1..300}; do echo "line $i" >>"$MIN_FILE"; done
run_test ".min.js files skipped" "$MIN_FILE" 0 ""

# Test 14: .min.css files should be skipped
echo "Test 14: .min.css files skipped"
MIN_CSS="$TEMP_DIR/style.min.css"
for i in {1..300}; do echo "line $i" >>"$MIN_CSS"; done
run_test ".min.css files skipped" "$MIN_CSS" 0 ""

# Test 15: Error message should mention 250 line limit
echo "Test 15: Error message mentions 250 line limit"
OVER_FILE2="$TEMP_DIR/over2.sh"
for i in {1..300}; do echo "line $i" >>"$OVER_FILE2"; done
run_test "Error shows limit" "$OVER_FILE2" 1 "250"

# Test 16: Error message should mention line count
echo "Test 16: Error message shows line count"
OVER_FILE3="$TEMP_DIR/over3.sh"
for i in {1..300}; do echo "line $i" >>"$OVER_FILE3"; done
run_test "Error shows count" "$OVER_FILE3" 1 "300"

# Cleanup
cd "$SCRIPT_DIR"

# Summary
echo ""
echo "========================================"
echo "Test Summary: enforce-line-limit.sh"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "========================================"

[ "$TESTS_FAILED" -eq 0 ] && exit 0 || exit 1
