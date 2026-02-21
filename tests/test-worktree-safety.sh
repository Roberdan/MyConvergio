#!/bin/bash
# Test: worktree-safety.sh syntax, functions, subcommands, line count
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/worktree-safety.sh"
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

echo "=== test-worktree-safety.sh ==="

# T1: File exists and is executable
if [ -x "$TARGET" ]; then
	pass "file exists and is executable"
else
	fail "file not found or not executable"
fi

# T2: Bash syntax check
if bash -n "$TARGET" 2>/dev/null; then
	pass "bash -n"
else
	fail "bash -n failed"
fi

# T3: Contains pre-check subcommand
if grep -q 'pre-check' "$TARGET"; then
	pass "pre-check subcommand"
else
	fail "pre-check subcommand missing"
fi

# T4: Contains notify-merge subcommand
if grep -q 'notify-merge' "$TARGET"; then
	pass "notify-merge subcommand"
else
	fail "notify-merge subcommand missing"
fi

# T5: Contains recover subcommand
if grep -q 'recover' "$TARGET"; then
	pass "recover subcommand"
else
	fail "recover subcommand missing"
fi

# T6: Contains audit subcommand
if grep -q 'audit' "$TARGET"; then
	pass "audit subcommand"
else
	fail "audit subcommand missing"
fi

# T7: Uses git commands
if grep -q 'git ' "$TARGET"; then
	pass "uses git commands"
else
	fail "no git commands found"
fi

# T8: Line count < 250
lines=$(wc -l <"$TARGET")
if [ "$lines" -lt 250 ]; then
	pass "$lines lines (<250)"
else
	fail "$lines lines (>=250)"
fi

echo ""
echo "=== Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
