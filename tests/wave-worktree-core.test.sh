#!/bin/bash
# Test suite for wave-worktree-core.sh
# TDD: written before implementation — all tests should fail (RED) initially
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/scripts/lib"

# Test counters
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

# Load the library under test
if [[ ! -f "$LIB_DIR/wave-worktree-core.sh" ]]; then
	echo "FATAL: wave-worktree-core.sh not found at $LIB_DIR/wave-worktree-core.sh"
	exit 1
fi
source "$LIB_DIR/wave-worktree-core.sh"

# ---------------------------------------------------------------------------
# wave_branch_name
# ---------------------------------------------------------------------------
test_wave_branch_name_basic() {
	test_start "wave_branch_name() returns plan/{plan}-{wave}"
	local result
	result=$(wave_branch_name 200 W1)
	if [[ "$result" == "plan/200-W1" ]]; then
		test_pass
	else
		test_fail "expected 'plan/200-W1', got '$result'"
	fi
}

test_wave_branch_name_plan197() {
	test_start "wave_branch_name() with plan 197 wave W0"
	local result
	result=$(wave_branch_name 197 W0)
	if [[ "$result" == "plan/197-W0" ]]; then
		test_pass
	else
		test_fail "expected 'plan/197-W0', got '$result'"
	fi
}

# ---------------------------------------------------------------------------
# wave_worktree_path
# ---------------------------------------------------------------------------
test_wave_worktree_path_basic() {
	test_start "wave_worktree_path() returns sibling directory"
	local result
	result=$(wave_worktree_path "/Users/roberdan/.claude" 200 W1)
	if [[ "$result" == "/Users/roberdan/.claude-plan-200-W1" ]]; then
		test_pass
	else
		test_fail "expected '/Users/roberdan/.claude-plan-200-W1', got '$result'"
	fi
}

test_wave_worktree_path_repo_name() {
	test_start "wave_worktree_path() extracts repo name from path"
	local result
	result=$(wave_worktree_path "/home/user/myrepo" 42 W3)
	if [[ "$result" == "/home/user/myrepo-plan-42-W3" ]]; then
		test_pass
	else
		test_fail "expected '/home/user/myrepo-plan-42-W3', got '$result'"
	fi
}

# ---------------------------------------------------------------------------
# _normalize_path and _expand_path (inline helpers)
# ---------------------------------------------------------------------------
test_normalize_path() {
	test_start "_normalize_path() replaces \$HOME with ~"
	local result
	result=$(_normalize_path "$HOME/.claude/data")
	if [[ "$result" == "~/.claude/data" ]]; then
		test_pass
	else
		test_fail "expected '~/.claude/data', got '$result'"
	fi
}

test_expand_path() {
	test_start "_expand_path() expands ~ to \$HOME"
	local result
	result=$(_expand_path "~/.claude/data")
	if [[ "$result" == "$HOME/.claude/data" ]]; then
		test_pass
	else
		test_fail "expected '$HOME/.claude/data', got '$result'"
	fi
}

# ---------------------------------------------------------------------------
# wave_stash_if_dirty (using a temp dir)
# ---------------------------------------------------------------------------
test_wave_stash_if_dirty_clean() {
	test_start "wave_stash_if_dirty() returns empty on clean repo"
	local tmpdir
	tmpdir=$(mktemp -d)
	cd "$tmpdir"
	git init -q
	git commit -q --allow-empty -m "init"
	local result
	result=$(wave_stash_if_dirty "$tmpdir")
	cd /tmp
	rm -rf "$tmpdir"
	if [[ -z "$result" ]]; then
		test_pass
	else
		test_fail "expected empty string on clean repo, got '$result'"
	fi
}

test_wave_stash_if_dirty_dirty() {
	test_start "wave_stash_if_dirty() stashes dirty repo"
	local tmpdir
	tmpdir=$(mktemp -d)
	cd "$tmpdir"
	git init -q
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -q --allow-empty -m "init"
	echo "dirty" >dirty.txt
	git add dirty.txt
	local result
	result=$(wave_stash_if_dirty "$tmpdir")
	cd /tmp
	rm -rf "$tmpdir"
	if [[ -n "$result" ]]; then
		test_pass
	else
		test_fail "expected stash ref on dirty repo, got empty"
	fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
echo ""
echo "=== wave-worktree-core.sh Test Suite ==="
echo ""

test_wave_branch_name_basic
test_wave_branch_name_plan197
test_wave_worktree_path_basic
test_wave_worktree_path_repo_name
test_normalize_path
test_expand_path
test_wave_stash_if_dirty_clean
test_wave_stash_if_dirty_dirty

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed"
if [[ $TESTS_FAILED -gt 0 ]]; then
	exit 1
fi
exit 0
