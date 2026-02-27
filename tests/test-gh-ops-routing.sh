#!/bin/bash
# Test: gh-ops-routing.sh syntax, references, line count
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/lib/gh-ops-routing.sh"
failures=0

# 1. Syntax check
if ! bash -n "$TARGET" 2>/dev/null; then
	echo 'FAIL: bash -n failed'
	failures=$((failures + 1))
else
	echo 'PASS: bash -n'
fi

# 2. Must reference pr-threads.sh and pr-ops.sh
if ! grep -q 'pr-threads' "$TARGET"; then
	echo 'FAIL: missing pr-threads reference'
	failures=$((failures + 1))
else
	echo 'PASS: pr-threads reference'
fi
if ! grep -q 'pr-ops' "$TARGET"; then
	echo 'FAIL: missing pr-ops reference'
	failures=$((failures + 1))
else
	echo 'PASS: pr-ops reference'
fi

# 3. Line count < 200
lines=$(wc -l <"$TARGET")
if [ "$lines" -ge 200 ]; then
	echo "FAIL: $lines lines (>=200)"
	failures=$((failures + 1))
else
	echo "PASS: $lines lines (<200)"
fi

exit $failures
