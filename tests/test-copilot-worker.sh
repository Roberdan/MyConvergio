#!/usr/bin/env bash
# Test: copilot-worker.sh
# Verifies required refactor points for T1-06.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/copilot-worker.sh"

PASS=0
FAIL=0
TOTAL=0

pass() {
	PASS=$((PASS + 1))
	TOTAL=$((TOTAL + 1))
	echo "  PASS: $1"
}

fail() {
	FAIL=$((FAIL + 1))
	TOTAL=$((TOTAL + 1))
	echo "  FAIL: $1"
}

echo "=== test-copilot-worker.sh ==="

if bash -n "$TARGET" >/dev/null 2>&1; then
	pass "bash -n scripts/copilot-worker.sh"
else
	fail "bash -n scripts/copilot-worker.sh"
fi

if grep -Eq 'plan-db-safe|safe_update_task' "$TARGET" 2>/dev/null; then
	pass "references plan-db-safe or safe_update_task"
else
	fail "missing plan-db-safe/safe_update_task reference"
fi

if grep -Eq 'sqlite3.*UPDATE' "$TARGET" 2>/dev/null; then
	fail "contains raw sqlite3 UPDATE"
else
	pass "no raw sqlite3 UPDATE"
fi

if grep -q 'log_delegation' "$TARGET" 2>/dev/null; then
	pass "references log_delegation"
else
	fail "missing log_delegation reference"
fi

if grep -q 'git stash' "$TARGET" 2>/dev/null; then
	pass "references git stash"
else
	fail "missing git stash reference"
fi

echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
