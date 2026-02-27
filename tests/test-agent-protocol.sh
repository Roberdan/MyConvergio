#!/bin/bash
# Test: agent-protocol.sh syntax, functions, line count
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/lib/agent-protocol.sh"
PASS=0
FAIL=0

pass() {
	PASS=$((PASS + 1))
	echo "  PASS: $1"
}
fail() {
	FAIL=$((FAIL + 1))
	echo "  FAIL: $1"
}

echo "=== test-agent-protocol.sh ==="

# T1: File exists
if [ -f "$TARGET" ]; then
	pass "file exists"
else fail "file not found"; fi

# T2: Bash syntax check
if bash -n "$TARGET" 2>/dev/null; then
	pass "bash -n"
else fail "bash -n failed"; fi

# T3: build_task_envelope function
if grep -q 'build_task_envelope' "$TARGET"; then
	pass "build_task_envelope function"
else fail "missing build_task_envelope"; fi

# T4: parse_worker_result function
if grep -q 'parse_worker_result' "$TARGET"; then
	pass "parse_worker_result function"
else fail "missing parse_worker_result"; fi

# T5: format_thor_input function
if grep -q 'format_thor_input' "$TARGET"; then
	pass "format_thor_input function"
else fail "missing format_thor_input"; fi

# T6: Context windowing (max tokens)
if grep -q 'MAX_CONTEXT\|max_context\|2000\|token' "$TARGET"; then
	pass "context windowing"
else fail "missing context windowing"; fi

# T7: JSON output (jq or json)
if grep -q 'jq\|json\|JSON' "$TARGET"; then
	pass "JSON handling"
else fail "missing JSON handling"; fi

# T8: Line count < 250
lines=$(wc -l <"$TARGET")
if [ "$lines" -lt 250 ]; then
	pass "$lines lines (<250)"
else fail "$lines lines (>=250)"; fi

echo ""
echo "=== Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
