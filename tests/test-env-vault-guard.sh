#!/bin/bash
# Test: env-vault-guard.sh syntax, patterns, line count
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/hooks/env-vault-guard.sh"

fail() {
	echo "FAIL: $1"
	exit 1
}

# Test 1: Syntax check
bash -n "$TARGET" || fail "Syntax check failed"
echo "PASS: bash -n"

# Test 2: Secret pattern grep
if grep -q 'API_KEY\|SECRET\|PASSWORD' "$TARGET"; then
	echo "PASS: Secret pattern found"
else
	fail "Secret pattern not found"
fi

# Test 3: gitignore check
if grep -q 'gitignore' "$TARGET"; then
	echo "PASS: gitignore check found"
else
	fail "gitignore check not found"
fi

# Test 4: Line count
if [ "$(wc -l <"$TARGET")" -lt 80 ]; then
	echo "PASS: Line count OK"
else
	fail "Line count exceeds 80"
fi

echo "All tests passed."
