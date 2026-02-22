#!/bin/bash
# Test for thor-audit-log.sh functionality
# Test criteria:
# - scripts/thor-audit-log.sh exists
# - plan-db-safe.sh contains "thor-audit"

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORKTREE="/Users/roberdan/.claude-plan-189"
ERRORS=0

echo "=========================================="
echo "TEST: Thor Audit Log (T1-04)"
echo "=========================================="
echo ""

# Test 1: thor-audit-log.sh exists
echo "[1/4] Checking thor-audit-log.sh exists..."
if [[ -f "$WORKTREE/scripts/thor-audit-log.sh" ]]; then
	echo "  ✓ PASS: thor-audit-log.sh exists"
else
	echo "  ✗ FAIL: thor-audit-log.sh does not exist"
	((ERRORS++))
fi

# Test 2: thor-audit-log.sh is executable
echo "[2/4] Checking thor-audit-log.sh is executable..."
if [[ -x "$WORKTREE/scripts/thor-audit-log.sh" ]]; then
	echo "  ✓ PASS: thor-audit-log.sh is executable"
else
	echo "  ✗ FAIL: thor-audit-log.sh is not executable"
	((ERRORS++))
fi

# Test 3: plan-db-safe.sh contains "thor-audit"
echo "[3/4] Checking plan-db-safe.sh contains 'thor-audit'..."
if grep -q "thor-audit" "$WORKTREE/scripts/plan-db-safe.sh"; then
	echo "  ✓ PASS: plan-db-safe.sh references thor-audit"
else
	echo "  ✗ FAIL: plan-db-safe.sh does not reference thor-audit"
	((ERRORS++))
fi

# Test 4: thor-audit-log.sh has set -euo pipefail
echo "[4/4] Checking thor-audit-log.sh has set -euo pipefail..."
if [[ -f "$WORKTREE/scripts/thor-audit-log.sh" ]] && grep -q "set -euo pipefail" "$WORKTREE/scripts/thor-audit-log.sh"; then
	echo "  ✓ PASS: thor-audit-log.sh has set -euo pipefail"
else
	echo "  ✗ FAIL: thor-audit-log.sh missing set -euo pipefail"
	((ERRORS++))
fi

echo ""
echo "=========================================="
if [[ $ERRORS -eq 0 ]]; then
	echo "✓ ALL TESTS PASSED"
	exit 0
else
	echo "✗ $ERRORS TEST(S) FAILED"
	exit 1
fi
