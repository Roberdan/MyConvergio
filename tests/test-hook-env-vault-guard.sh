#!/bin/bash
# Test suite for hooks/env-vault-guard.sh
# Tests env vault guard detects env vars in committed files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="${SCRIPT_DIR}/../hooks/env-vault-guard.sh"

# Test framework
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
  echo "✓ $1"
  ((++TESTS_PASSED))
}

test_fail() {
  echo "✗ $1"
  echo "  Expected: $2"
  echo "  Got: $3"
  ((++TESTS_FAILED))
}

# Setup temp git repo
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

# Create .gitignore
echo ".env" > .gitignore
git add .gitignore
git commit -qm "Add .gitignore"

# Test 1: Clean file should pass
echo "Test 1: Clean file passes"
echo "NORMAL_VAR=value" > clean.txt
git add clean.txt
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
  test_pass "Clean file passes"
else
  test_fail "Clean file passes" "exit 0" "exit $EXIT_CODE"
fi
git reset HEAD clean.txt >/dev/null 2>&1

# Test 2: API_KEY should be blocked
echo "Test 2: API_KEY pattern blocked"
echo "API_KEY=secret123" > secrets.txt
git add secrets.txt
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -ne 0 ] && echo "$OUTPUT" | grep -q "BLOCKED"; then
  test_pass "API_KEY blocked"
else
  test_fail "API_KEY blocked" "exit 1 with BLOCKED" "exit $EXIT_CODE"
fi
git reset HEAD secrets.txt >/dev/null 2>&1
rm -f secrets.txt

# Test 3: SECRET= should be blocked
echo "Test 3: SECRET= pattern blocked"
echo "SECRET=mysecret" > secrets.txt
git add secrets.txt
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -ne 0 ] && echo "$OUTPUT" | grep -q "BLOCKED"; then
  test_pass "SECRET= blocked"
else
  test_fail "SECRET= blocked" "exit 1 with BLOCKED" "exit $EXIT_CODE"
fi
git reset HEAD secrets.txt >/dev/null 2>&1
rm -f secrets.txt

# Test 4: PASSWORD= should be blocked
echo "Test 4: PASSWORD= pattern blocked"
echo "PASSWORD=pass123" > secrets.txt
git add secrets.txt
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -ne 0 ] && echo "$OUTPUT" | grep -q "BLOCKED"; then
  test_pass "PASSWORD= blocked"
else
  test_fail "PASSWORD= blocked" "exit 1 with BLOCKED" "exit $EXIT_CODE"
fi
git reset HEAD secrets.txt >/dev/null 2>&1
rm -f secrets.txt

# Test 5: CONNECTION_STRING= should be blocked
echo "Test 5: CONNECTION_STRING= pattern blocked"
echo "CONNECTION_STRING=server=localhost" > secrets.txt
git add secrets.txt
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -ne 0 ] && echo "$OUTPUT" | grep -q "BLOCKED"; then
  test_pass "CONNECTION_STRING= blocked"
else
  test_fail "CONNECTION_STRING= blocked" "exit 1 with BLOCKED" "exit $EXIT_CODE"
fi
git reset HEAD secrets.txt >/dev/null 2>&1
rm -f secrets.txt

# Test 6: private_key should be blocked
echo "Test 6: private_key pattern blocked"
echo "private_key: ABCD1234" > secrets.txt
git add secrets.txt
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -ne 0 ] && echo "$OUTPUT" | grep -q "BLOCKED"; then
  test_pass "private_key blocked"
else
  test_fail "private_key blocked" "exit 1 with BLOCKED" "exit $EXIT_CODE"
fi
git reset HEAD secrets.txt >/dev/null 2>&1
rm -f secrets.txt

# Test 7: token should be blocked
echo "Test 7: token pattern blocked"
echo "auth_token: xyz789" > secrets.txt
git add secrets.txt
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -ne 0 ] && echo "$OUTPUT" | grep -q "BLOCKED"; then
  test_pass "token blocked"
else
  test_fail "token blocked" "exit 1 with BLOCKED" "exit $EXIT_CODE"
fi
git reset HEAD secrets.txt >/dev/null 2>&1
rm -f secrets.txt

# Test 8: .env in .gitignore check
echo "Test 8: .env in .gitignore checked"
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
set -e
if ! echo "$OUTPUT" | grep -q "WARNING.*\.env"; then
  test_pass ".env in .gitignore check passes"
else
  test_fail ".env in .gitignore check" "no warning" "warning found"
fi

# Test 9: Multiple clean files should pass
echo "Test 9: Multiple clean files pass"
echo "config=value1" > file1.txt
echo "setting=value2" > file2.txt
git add file1.txt file2.txt
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
  test_pass "Multiple clean files pass"
else
  test_fail "Multiple clean files pass" "exit 0" "exit $EXIT_CODE"
fi
git reset HEAD file1.txt file2.txt >/dev/null 2>&1

# Test 10: No staged files should pass
echo "Test 10: No staged files passes"
git reset HEAD >/dev/null 2>&1
set +e
OUTPUT=$(bash "$HOOK_PATH" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
  test_pass "No staged files passes"
else
  test_fail "No staged files passes" "exit 0" "exit $EXIT_CODE"
fi

# Cleanup
cd "$SCRIPT_DIR"

# Summary
echo ""
echo "========================================"
echo "Test Summary: env-vault-guard.sh"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "========================================"

[ "$TESTS_FAILED" -eq 0 ] && exit 0 || exit 1
