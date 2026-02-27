#!/usr/bin/env bash
# Test: delegate-utils.sh
# Verifies required utility functions and constraints for T1-01.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/lib/delegate-utils.sh"

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

echo "=== test-delegate-utils.sh ==="

if bash -n "$TARGET" >/dev/null 2>&1; then
	pass "bash -n scripts/lib/delegate-utils.sh"
else
	fail "bash -n scripts/lib/delegate-utils.sh"
fi

if grep -q 'log_delegation' "$TARGET" 2>/dev/null; then
	pass "grep log_delegation"
else
	fail "grep log_delegation"
fi

if grep -q 'plan-db-safe' "$TARGET" 2>/dev/null; then
	pass "grep plan-db-safe"
else
	fail "grep plan-db-safe"
fi

if grep -q 'verify_work_done' "$TARGET" 2>/dev/null; then
	pass "grep verify_work_done"
else
	fail "grep verify_work_done"
fi

if [[ -f "$TARGET" ]]; then
	LINES=$(wc -l <"$TARGET")
	if [[ "$LINES" -lt 250 ]]; then
		pass "wc -l < 250"
	else
		fail "wc -l < 250"
	fi
else
	fail "wc -l < 250"
fi

echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
