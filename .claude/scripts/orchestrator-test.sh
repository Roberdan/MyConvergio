#!/usr/bin/env bash
set -euo pipefail

# Check bats-core
if ! command -v bats >/dev/null 2>&1; then
  echo "TAP version 13"
  echo "not ok 1 - bats-core not installed"
  exit 1
else
  echo "# bats-core found"
fi

# Find test scripts
TESTS=(tests/test-*.sh)
TOTAL=0
PASS=0
FAIL=0

# TAP header
echo "TAP version 13"

for test in "${TESTS[@]}"; do
  TOTAL=$((TOTAL+1))
  bash "$test"
  if [ $? -eq 0 ]; then
    echo "ok $TOTAL - $test"
    PASS=$((PASS+1))
  else
    echo "not ok $TOTAL - $test"
    FAIL=$((FAIL+1))
  fi
done

# Summary
echo "1..$TOTAL"
echo "# pass $PASS"
echo "# fail $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
