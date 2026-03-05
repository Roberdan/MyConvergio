#!/bin/bash
# Test suite for hooks/warn-bash-antipatterns.sh
# Tests that bash antipatterns hook detects common bad patterns
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="${SCRIPT_DIR}/../hooks/warn-bash-antipatterns.sh"

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
	local input_json="$2"
	local expected_exit="$3"
	local expected_pattern="$4"

	local output
	local exit_code=0

	set +e
	output=$(echo "$input_json" | "$HOOK_PATH" 2>&1)
	exit_code=$?
	set -e

	if [ "$exit_code" -ne "$expected_exit" ]; then
		test_fail "$test_name" "exit $expected_exit" "exit $exit_code (output: $output)"
		return 0
	fi

	if [ -n "$expected_pattern" ] && ! echo "$output" | grep -q "$expected_pattern"; then
		test_fail "$test_name" "output containing '$expected_pattern'" "'$output'"
		return 0
	fi

	test_pass "$test_name"
	return 0
}

# Helper: wrap command with Bash tool_name
bash_input() {
	local cmd="$1"
	printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd"
}

# Test 1: Find command should warn about Glob
echo "Test 1: Find command warns about Glob tool"
run_test "Find command antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"find . -name \"*.txt\""}}' \
	0 "Glob"

# Test 2: Grep command should warn about Grep
echo "Test 2: Grep command warns about Grep tool"
run_test "Grep command antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"grep pattern file.txt"}}' \
	0 "Grep"

# Test 3: Cat for reading should warn about Read
echo "Test 3: Cat command warns about Read tool"
run_test "Cat command antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"cat file.txt"}}' \
	0 "Read"

# Test 4: Sed -i should warn about Edit
echo "Test 4: Sed -i warns about Edit tool"
run_test "Sed -i antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"sed -i \"s/old/new/\" file.txt"}}' \
	0 "Edit"

# Test 5: Echo redirect should warn about Write
echo "Test 5: Echo redirect warns about Write tool"
run_test "Echo redirect antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"echo content > file.txt"}}' \
	0 "Write"

# Test 6: Heredoc should warn about Write
echo "Test 6: Heredoc warns about Write tool"
run_test "Heredoc antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"cat <<EOF > file.txt"}}' \
	0 "Write"

# Test 7: SQL != in double quotes should block (zsh issue)
echo "Test 7: SQL != in double quotes blocked for zsh safety"
run_test "SQL != blocked" \
	'{"tool_name":"Bash","tool_input":{"command":"sqlite3 db.sqlite \"SELECT * WHERE status != '\''done'\''\""}}' \
	2 "BLOCKED"

# Test 8: SQL <> should pass
echo "Test 8: SQL <> operator passes"
run_test "SQL <> passes" \
	'{"tool_name":"Bash","tool_input":{"command":"sqlite3 db.sqlite \"SELECT * WHERE status <> '\''done'\''\""}}' \
	0 ""

# Test 9: Pipe to grep should warn
echo "Test 9: Pipe to grep warns"
run_test "Pipe to grep" \
	'{"tool_name":"Bash","tool_input":{"command":"ls -la | grep txt"}}' \
	0 "Grep"

# Test 10: Ripgrep (rg) should warn
echo "Test 10: Ripgrep warns about Grep tool"
run_test "Ripgrep antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"rg pattern ."}}' \
	0 "Grep"

# Test 11: Head command should warn about Read
echo "Test 11: Head command warns about Read tool"
run_test "Head command antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"head -n 10 file.txt"}}' \
	0 "Read"

# Test 12: Tail command should warn about Read
echo "Test 12: Tail command warns about Read tool"
run_test "Tail command antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"tail -n 10 file.txt"}}' \
	0 "Read"

# Test 13: Awk should warn about Edit
echo "Test 13: Awk warns about Edit tool"
run_test "Awk antipattern" \
	'{"tool_name":"Bash","tool_input":{"command":"awk '\''{print $1}'\'' file.txt"}}' \
	0 "Edit"

# Test 14: Normal git command should pass
echo "Test 14: Normal git command passes"
run_test "Git command passes" \
	'{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
	0 ""

# Test 15: Empty command should pass
echo "Test 15: Empty command passes"
run_test "Empty command" \
	'{"tool_name":"Bash","tool_input":{"command":""}}' \
	0 ""

# Test 16: Pipe to echo (builtin) passes
echo "Test 16: Pipe to echo (builtin) passes"
run_test "Pipe to builtin" \
	'{"tool_name":"Bash","tool_input":{"command":"ls | echo test"}}' \
	0 ""

# Test 17: Non-Bash tool is ignored
echo "Test 17: Non-Bash tool is ignored"
run_test "Non-Bash tool ignored" \
	'{"tool_name":"Read","tool_input":{"command":"grep pattern file.txt"}}' \
	0 ""

# Summary
echo ""
echo "========================================"
echo "Test Summary: warn-bash-antipatterns.sh"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "========================================"

[ "$TESTS_FAILED" -eq 0 ] && exit 0 || exit 1
