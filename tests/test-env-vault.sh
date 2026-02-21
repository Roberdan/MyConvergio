#!/bin/bash
# Test: env-vault.sh syntax, subcommands, line count
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/env-vault.sh"
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

echo "=== test-env-vault.sh ==="

# T1: File exists
if [ -f "$TARGET" ]; then
	pass "file exists"
else fail "file not found"; fi

# T2: Bash syntax check
if bash -n "$TARGET" 2>/dev/null; then
	pass "bash -n"
else fail "bash -n failed"; fi

# T3: backup subcommand
if grep -q 'backup' "$TARGET"; then
	pass "backup subcommand"
else fail "missing backup"; fi

# T4: restore subcommand
if grep -q 'restore' "$TARGET"; then
	pass "restore subcommand"
else fail "missing restore"; fi

# T5: audit subcommand
if grep -q 'audit' "$TARGET"; then
	pass "audit subcommand"
else fail "missing audit"; fi

# T6: References gh or az for secrets
if grep -q 'gh\|az\|keyvault' "$TARGET"; then
	pass "secrets CLI reference"
else fail "missing secrets CLI"; fi

# T7: Line count < 250
lines=$(wc -l <"$TARGET")
if [ "$lines" -lt 250 ]; then
	pass "$lines lines (<250)"
else fail "$lines lines (>=250)"; fi

echo ""
echo "=== Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
