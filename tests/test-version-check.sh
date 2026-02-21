#!/bin/bash
# RED test: version-check.sh must check copilot-cli, opencode, gemini and output to data/.cli-versions.json
set -euo pipefail

failures=0

# Test 1: copilot-cli check
if ! grep -q 'copilot-cli' hooks/version-check.sh && ! grep -q 'copilot' hooks/version-check.sh; then
  echo 'FAIL: copilot check missing'
  failures=$((failures+1))
else
  echo 'PASS: copilot check present'
fi

# Test 2: opencode check
if ! grep -q 'opencode' hooks/version-check.sh; then
  echo 'FAIL: opencode check missing'
  failures=$((failures+1))
else
  echo 'PASS: opencode check present'
fi

# Test 3: gemini check
if ! grep -q 'gemini' hooks/version-check.sh; then
  echo 'FAIL: gemini check missing'
  failures=$((failures+1))
else
  echo 'PASS: gemini check present'
fi

# Test 4: .cli-versions.json output
if ! grep -q 'data/.cli-versions.json' hooks/version-check.sh; then
  echo 'FAIL: .cli-versions.json output missing'
  failures=$((failures+1))
else
  echo 'PASS: .cli-versions.json output present'
fi

# Test 5: <80 lines
lines=$(wc -l < hooks/version-check.sh)
if [ "$lines" -ge 80 ]; then
  echo "FAIL: version-check.sh exceeds 80 lines ($lines)"
  failures=$((failures+1))
else
  echo "PASS: version-check.sh under 80 lines ($lines)"
fi

exit $failures
