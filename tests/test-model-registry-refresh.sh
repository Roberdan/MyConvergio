#!/bin/bash
# Test: model-registry-refresh.sh hook existence, syntax, content, line count
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/hooks/model-registry-refresh.sh"
fail=0

# 1. File must exist
if [ ! -f "$TARGET" ]; then
	echo "FAIL: $TARGET does not exist"
	exit 1
fi
echo "PASS: file exists"

# 2. Bash syntax check
if bash -n "$TARGET"; then
	echo "PASS: bash -n"
else
	echo "FAIL: bash -n failed"
	fail=1
fi

# 3. Must contain '14' (for 14-day check)
if grep -q '14' "$TARGET"; then
	echo "PASS: contains '14'"
else
	echo "FAIL: missing '14'"
	fail=1
fi

# 4. Must be <80 lines
lines=$(wc -l <"$TARGET")
if [ "$lines" -lt 80 ]; then
	echo "PASS: $lines lines (<80)"
else
	echo "FAIL: $lines lines (>=80)"
	fail=1
fi

exit $fail
