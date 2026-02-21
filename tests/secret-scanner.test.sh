#!/bin/bash
# Test suite for hooks/secret-scanner.sh
# Tests detection of secrets, API keys, hardcoded URLs, and localhost/IPs

set -uo pipefail

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

HOOK_PATH="/Users/roberdan/.claude-plan-189/hooks/secret-scanner.sh"
FAILED=0

# Test 1: API keys detection
echo "Test 1: Detect OpenAI API key"
echo 'const key = "sk-proj-abc123xyz";' > test1.js
git add test1.js
if ! bash "$HOOK_PATH" >/dev/null 2>&1; then
  echo "✓ PASS: OpenAI key detected (blocked)"
else
  echo "✗ FAIL: OpenAI key not detected"
  FAILED=1
fi
git reset -q

# Test 2: GitHub token detection
echo "Test 2: Detect GitHub token"
echo 'TOKEN=ghp_1234567890abcdef' > test2.sh
git add test2.sh
if ! bash "$HOOK_PATH" >/dev/null 2>&1; then
  echo "✓ PASS: GitHub token detected (blocked)"
else
  echo "✗ FAIL: GitHub token not detected"
  FAILED=1
fi
git reset -q

# Test 3: AWS credentials detection
echo "Test 3: Detect AWS access key"
echo 'AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE' > test3.env
git add test3.env
if ! bash "$HOOK_PATH" >/dev/null 2>&1; then
  echo "✓ PASS: AWS key detected (blocked)"
else
  echo "✗ FAIL: AWS key not detected"
  FAILED=1
fi
git reset -q

# Test 4: Hardcoded URL detection
echo "Test 4: Detect hardcoded URL"
echo 'const api = "https://api.production.com/v1";' > test4.js
git add test4.js
if ! bash "$HOOK_PATH" >/dev/null 2>&1; then
  echo "✓ PASS: Hardcoded URL detected (blocked)"
else
  echo "✗ FAIL: Hardcoded URL not detected"
  FAILED=1
fi
git reset -q

# Test 5: Localhost without env var fallback
echo "Test 5: Detect localhost without fallback"
echo 'const db = "http://localhost:5432";' > test5.js
git add test5.js
if ! bash "$HOOK_PATH" >/dev/null 2>&1; then
  echo "✓ PASS: localhost without fallback detected (blocked)"
else
  echo "✗ FAIL: localhost without fallback not detected"
  FAILED=1
fi
git reset -q

# Test 6: Clean file passes
echo "Test 6: Clean file should pass"
echo 'const url = process.env.API_URL || "http://localhost:3000";' > test6.js
git add test6.js
if bash "$HOOK_PATH" >/dev/null 2>&1; then
  echo "✓ PASS: Clean file passes"
else
  echo "✗ FAIL: Clean file blocked"
  FAILED=1
fi
git reset -q

# Test 7: Environment variable with fallback is allowed
echo "Test 7: Env var with fallback allowed"
echo 'DB_URL=${DATABASE_URL:-localhost:5432}' > test7.sh
git add test7.sh
if bash "$HOOK_PATH" >/dev/null 2>&1; then
  echo "✓ PASS: Env var with fallback allowed"
else
  echo "✗ FAIL: Env var with fallback blocked"
  FAILED=1
fi

echo ""
if [ $FAILED -eq 0 ]; then
  echo "All tests passed!"
  exit 0
else
  echo "Some tests failed!"
  exit 1
fi

