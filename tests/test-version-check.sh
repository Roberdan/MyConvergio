#!/bin/bash
# Test: version-check.sh must check copilot-cli, opencode, gemini
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/hooks/version-check.sh"
failures=0

# Test 1: copilot check
if grep -q 'copilot' "$TARGET"; then
	echo 'PASS: copilot check present'
else
	echo 'FAIL: copilot check missing'
	failures=$((failures + 1))
fi

# Test 2: opencode check
if grep -q 'opencode' "$TARGET"; then
	echo 'PASS: opencode check present'
else
	echo 'FAIL: opencode check missing'
	failures=$((failures + 1))
fi

# Test 3: gemini check
if grep -q 'gemini' "$TARGET"; then
	echo 'PASS: gemini check present'
else
	echo 'FAIL: gemini check missing'
	failures=$((failures + 1))
fi

# Test 4: .cli-versions.json output
if grep -q 'cli-versions' "$TARGET"; then
	echo 'PASS: cli-versions output present'
else
	echo 'FAIL: cli-versions output missing'
	failures=$((failures + 1))
fi

# Test 5: <80 lines
lines=$(wc -l <"$TARGET")
if [ "$lines" -lt 80 ]; then
	echo "PASS: $lines lines (<80)"
else
	echo "FAIL: $lines lines (>=80)"
	failures=$((failures + 1))
fi

exit $failures
