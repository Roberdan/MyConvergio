#!/bin/bash
# Test suite for hooks/worktree-guard.sh
# Tests worktree guard blocks operations on main when worktrees exist
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="${SCRIPT_DIR}/../hooks/worktree-guard.sh"

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
  local expected_output="$4"
  
  local output
  local exit_code=0
  
  set +e  # Temporarily disable exit on error
  output=$(echo "$input_json" | "$HOOK_PATH" 2>&1)
  exit_code=$?
  set -e  # Re-enable exit on error
  
  if [ "$exit_code" -ne "$expected_exit" ]; then
    test_fail "$test_name" "exit $expected_exit" "exit $exit_code"
    return 0
  fi
  
  if [ -n "$expected_output" ] && ! echo "$output" | grep -q "$expected_output"; then
    test_fail "$test_name" "output containing '$expected_output'" "'$output'"
    return 0
  fi
  
  test_pass "$test_name"
  return 0
}

# Setup temp git repo
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"
echo "test" > file.txt
git add file.txt
git commit -qm "Initial commit"

# Test 1: Non-git command should pass
echo "Test 1: Non-git command passes"
INPUT='{"tool_input":{"command":"ls -la"}}'
run_test "Non-git command" "$INPUT" 0 ""

# Test 2: Git read command should pass
echo "Test 2: Git read command passes"
INPUT='{"tool_input":{"command":"git log --oneline"}}'
run_test "Git read command" "$INPUT" 0 ""

# Test 3: Git commit on main without worktrees should pass
echo "Test 3: Git commit on main without worktrees passes"
INPUT='{"tool_input":{"command":"git add *.txt"}}'
run_test "Git add without worktrees" "$INPUT" 0 ""

# Test 4: Create a worktree and test warning on main
echo "Test 4: Git commit on main with worktrees warns (exit 0)"
WORKTREE_DIR="${TEMP_DIR}/../test-wt-$$"
mkdir -p "$WORKTREE_DIR"
git worktree add "$WORKTREE_DIR" -b test-branch-$$ 2>/dev/null || true
INPUT='{"tool_input":{"command":"git commit -m test"}}'
run_test "Git commit on main with worktrees" "$INPUT" 0 "WARNING"
# Clean up worktree
git worktree remove "$WORKTREE_DIR" 2>/dev/null || true

# Test 5: Block worktree add inside repo
echo "Test 5: Block worktree add inside repo"
INPUT='{"tool_input":{"command":"git worktree add ./nested-worktree"}}'
run_test "Worktree inside repo blocked" "$INPUT" 2 "BLOCKED"

# Test 6: Allow worktree add outside repo
echo "Test 6: Allow worktree add outside repo"
INPUT='{"tool_input":{"command":"git worktree add ../sibling-worktree"}}'
run_test "Worktree outside repo allowed" "$INPUT" 0 ""

# Test 7: Block direct git worktree remove
echo "Test 7: Block direct git worktree remove"
INPUT='{"tool_input":{"command":"git worktree remove test-worktree"}}'
run_test "Direct worktree remove blocked" "$INPUT" 2 "BLOCKED"

# Test 8: Git operation on feature branch with worktrees should pass
echo "Test 8: Git operation on feature branch passes"
git checkout -qb feature-test 2>/dev/null || git checkout -q feature-test
INPUT='{"tool_input":{"command":"git add *.txt"}}'
run_test "Git add on feature branch" "$INPUT" 0 ""

# Test 9: Empty command should pass
echo "Test 9: Empty command passes"
INPUT='{"tool_input":{"command":""}}'
run_test "Empty command" "$INPUT" 0 ""

# Test 10: Invalid JSON should handle gracefully
echo "Test 10: Invalid JSON handled gracefully"
INPUT='invalid json'
run_test "Invalid JSON" "$INPUT" 0 ""

# Cleanup
cd "$SCRIPT_DIR"
git worktree prune 2>/dev/null || true

# Summary
echo ""
echo "========================================"
echo "Test Summary: worktree-guard.sh"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "========================================"

[ "$TESTS_FAILED" -eq 0 ] && exit 0 || exit 1
