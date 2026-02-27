#!/bin/bash
# Test: quality-gate-templates.sh syntax, functions, line count
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/lib/quality-gate-templates.sh"
failures=0

# Test 1: File exists
if [ ! -f "$TARGET" ]; then
	echo "FAIL: $TARGET does not exist"
	exit 1
fi
echo "PASS: file exists"

# Test 2: Bash syntax check
if bash -n "$TARGET" 2>/dev/null; then
	echo "PASS: bash -n"
else
	echo "FAIL: bash -n failed"
	failures=$((failures + 1))
fi

# Test 3: Must contain gate functions
if grep -q 'gate_pre_deploy\|gate_env_var\|gate_security' "$TARGET"; then
	echo "PASS: gate functions found"
else
	echo "FAIL: gate functions not found"
	failures=$((failures + 1))
fi

# Test 4: Line count < 250
lines=$(wc -l <"$TARGET")
if [ "$lines" -lt 250 ]; then
	echo "PASS: $lines lines (<250)"
else
	echo "FAIL: $lines lines (>=250)"
	failures=$((failures + 1))
fi

exit $failures
