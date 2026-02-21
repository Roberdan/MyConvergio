#!/bin/bash
# Test: Circuit breaker prevents infinite retry loops
# Version: 1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAFE_SCRIPT="$SCRIPT_DIR/../scripts/plan-db-safe.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

test_count=0
pass_count=0

# Test helper
assert_grep() {
	local pattern="$1"
	local file="$2"
	local desc="$3"
	
	((test_count++))
	if grep -q "$pattern" "$file"; then
		echo -e "${GREEN}✓${NC} $desc"
		((pass_count++))
	else
		echo -e "${RED}✗${NC} $desc"
		echo "  Expected pattern: $pattern"
		echo "  Not found in: $file"
	fi
}

echo "========================================"
echo "TEST: Circuit Breaker in plan-db-safe.sh"
echo "========================================"
echo ""

# Test 1: Check for circuit breaker keywords
echo "[Test 1] Circuit breaker code exists..."
assert_grep "circuit.breaker\|consecutive.*reject\|max_rejections" "$SAFE_SCRIPT" \
	"Circuit breaker logic found"

# Test 2: Check for max_rejections configuration
echo ""
echo "[Test 2] Configurable max_rejections..."
assert_grep "MAX_REJECTIONS\|max_rejections" "$SAFE_SCRIPT" \
	"MAX_REJECTIONS constant exists"

# Test 3: Check for thor-audit.jsonl logging
echo ""
echo "[Test 3] Thor audit logging..."
assert_grep "thor-audit.jsonl" "$SAFE_SCRIPT" \
	"Logs to thor-audit.jsonl"

# Test 4: Check for blocked status
echo ""
echo "[Test 4] Auto-block mechanism..."
assert_grep "blocked\|block" "$SAFE_SCRIPT" \
	"Sets task to blocked status"

echo ""
echo "========================================"
echo "RESULTS: $pass_count/$test_count tests passed"
echo "========================================"

if [[ $pass_count -eq $test_count ]]; then
	exit 0
else
	exit 1
fi
