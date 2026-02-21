#!/bin/bash
# Test: model-registry.sh syntax, subcommands, output format, line count
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/model-registry.sh"
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

echo "=== test-model-registry.sh ==="

# T1: File exists and is executable
if [ -x "$TARGET" ]; then
	pass "file exists and is executable"
else fail "file not found or not executable"; fi

# T2: Bash syntax check
if bash -n "$TARGET" 2>/dev/null; then
	pass "bash -n"
else fail "bash -n failed"; fi

# T3: refresh subcommand
if grep -q 'refresh' "$TARGET"; then
	pass "refresh subcommand"
else fail "missing refresh"; fi

# T4: diff subcommand
if grep -q 'diff' "$TARGET"; then
	pass "diff subcommand"
else fail "missing diff"; fi

# T5: check subcommand
if grep -q 'check' "$TARGET"; then
	pass "check subcommand"
else fail "missing check"; fi

# T6: list subcommand
if grep -q 'list' "$TARGET"; then
	pass "list subcommand"
else fail "missing list"; fi

# T7: References orchestrator.yaml or models-registry
if grep -q 'orchestrator.yaml\|models-registry' "$TARGET"; then
	pass "config reference"
else fail "missing config reference"; fi

# T8: References opencode provider
if grep -q 'opencode' "$TARGET"; then
	pass "opencode provider"
else fail "missing opencode provider"; fi

# T9: JSON output (jq)
if grep -q 'jq\|json\|JSON' "$TARGET"; then
	pass "JSON handling"
else fail "missing JSON handling"; fi

# T10: Line count < 250
lines=$(wc -l <"$TARGET")
if [ "$lines" -lt 250 ]; then
	pass "$lines lines (<250)"
else fail "$lines lines (>=250)"; fi

echo ""
echo "=== Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
