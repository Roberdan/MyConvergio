#!/usr/bin/env bash
# Test: opencode-worker.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/opencode-worker.sh"

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

echo "=== test-opencode-worker.sh ==="

if bash -n "$TARGET" >/dev/null 2>&1; then
pass "bash -n scripts/opencode-worker.sh"
else
fail "bash -n scripts/opencode-worker.sh"
fi

if grep -Eq 'delegate-utils|agent-protocol' "$TARGET" 2>/dev/null; then
pass "grep delegate-utils|agent-protocol"
else
fail "grep delegate-utils|agent-protocol"
fi

if grep -Eq 'plan-db-safe|safe_update_task' "$TARGET" 2>/dev/null; then
pass "grep plan-db-safe|safe_update_task"
else
fail "grep plan-db-safe|safe_update_task"
fi

if grep -q 'log_delegation' "$TARGET" 2>/dev/null; then
pass "grep log_delegation"
else
fail "grep log_delegation"
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
