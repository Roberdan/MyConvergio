#!/bin/bash
# Test suite for hooks/worktree-guard.sh v2
# Tests JSON deny protocol + new branch creation blocking
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="${SCRIPT_DIR}/../hooks/worktree-guard.sh"

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
	local expected_output="$4"

	local output exit_code=0
	set +e
	output=$(echo "$input_json" | "$HOOK_PATH" 2>&1)
	exit_code=$?
	set -e

	if [ "$exit_code" -ne "$expected_exit" ]; then
		test_fail "$test_name" "exit $expected_exit" "exit $exit_code (output: $output)"
		return 0
	fi

	if [ -n "$expected_output" ] && ! echo "$output" | grep -q "$expected_output"; then
		test_fail "$test_name" "output containing '$expected_output'" "'$output'"
		return 0
	fi

	test_pass "$test_name"
}

# Helpers — v2 hook uses toolName + toolArgs.command
make_input() {
	local cmd="$1"
	printf '{"toolName":"bash","toolArgs":{"command":"%s"}}' "$cmd"
}

# Setup temp git repo
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"
echo "test" >file.txt
git add file.txt
CLAUDE_MAIN_WRITE_ALLOWED=1 git commit -qm "Initial commit"

# Test 1: Non-git command passes
echo "Test 1: Non-git command passes"
run_test "Non-git command" '{"toolName":"bash","toolArgs":{"command":"ls -la"}}' 0 ""

# Test 2: Git read command passes
echo "Test 2: Git read command passes"
run_test "Git read command" "$(make_input 'git log --oneline')" 0 ""

# Test 3: Git add without worktrees passes (feature branch)
echo "Test 3: Git add on feature branch passes"
git checkout -qb feature-test 2>/dev/null
run_test "Git add on feature branch" "$(make_input 'git add file.txt')" 0 ""
git checkout -q main 2>/dev/null

# Test 4: Non-bash tool name is ignored
echo "Test 4: Non-bash toolName ignored"
run_test "Non-bash tool" '{"toolName":"read","toolArgs":{"command":"git commit -m test"}}' 0 ""

# Test 5: Git commit on main with worktrees → JSON deny
echo "Test 5: Git commit on main with worktrees — JSON deny"
WORKTREE_DIR="${TEMP_DIR}/../test-wt-$$"
mkdir -p "$WORKTREE_DIR"
git worktree add "$WORKTREE_DIR" -b wt-branch-$$ 2>/dev/null || true
run_test "Git commit on main with worktrees" "$(make_input 'git commit -m test')" 0 "deny"
git worktree remove "$WORKTREE_DIR" 2>/dev/null || true
git branch -D "wt-branch-$$" 2>/dev/null || true

# Test 6: CLAUDE_MAIN_WRITE_ALLOWED=1 allows main writes
echo "Test 6: CLAUDE_MAIN_WRITE_ALLOWED=1 allows main write"
CLAUDE_MAIN_WRITE_ALLOWED=1 run_test "Main write allowed via env" "$(make_input 'git commit -m test')" 0 ""

# Test 7: Worktree add inside repo → JSON deny
echo "Test 7: Worktree add inside repo blocked"
run_test "Worktree inside repo blocked" "$(make_input 'git worktree add ./nested-wt')" 0 "deny"

# Test 8: Worktree add outside repo → allowed
echo "Test 8: Worktree add outside repo allowed"
run_test "Worktree outside repo allowed" "$(make_input 'git worktree add ../sibling-wt')" 0 ""

# Test 9: Direct git worktree remove → JSON deny
echo "Test 9: Direct git worktree remove blocked"
run_test "Direct worktree remove blocked" "$(make_input 'git worktree remove test-wt')" 0 "deny"

# Test 10: Empty command passes
echo "Test 10: Empty command passes"
run_test "Empty command" '{"toolName":"bash","toolArgs":{"command":""}}' 0 ""

# Test 11: Invalid JSON — hook should not crash (exit 0, no deny needed)
echo "Test 11: Invalid JSON handled gracefully"
set +e
bad_output=$(echo 'invalid json' | "$HOOK_PATH" 2>/dev/null)
bad_exit=$?
set -e
if [ "$bad_exit" -eq 0 ] || [ "$bad_exit" -eq 5 ]; then
	test_pass "Invalid JSON (exit $bad_exit acceptable)"
else
	test_fail "Invalid JSON" "exit 0 or 5" "exit $bad_exit"
fi

# Test 12: git branch (bare creation) → JSON deny
echo "Test 12: Bare branch creation blocked"
run_test "git branch new-branch blocked" "$(make_input 'git branch new-feature')" 0 "deny"

# Test 13: git checkout -b → JSON deny
echo "Test 13: git checkout -b blocked"
run_test "git checkout -b blocked" "$(make_input 'git checkout -b new-feature')" 0 "deny"

# Test 14: git switch -c → JSON deny
echo "Test 14: git switch -c blocked"
run_test "git switch -c blocked" "$(make_input 'git switch -c new-feature')" 0 "deny"

# Test 15: git branch -d → allowed (deletion OK)
echo "Test 15: git branch -d allowed"
run_test "git branch -d allowed" "$(make_input 'git branch -d old-feature')" 0 ""

# Test 16: git branch --show-current → allowed
echo "Test 16: git branch --show-current allowed"
run_test "git branch --show-current allowed" "$(make_input 'git branch --show-current')" 0 ""

# Cleanup
cd "$SCRIPT_DIR"
git worktree prune 2>/dev/null || true

echo ""
echo "========================================"
echo "Test Summary: worktree-guard.sh v2"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "========================================"

[ "$TESTS_FAILED" -eq 0 ] && exit 0 || exit 1
