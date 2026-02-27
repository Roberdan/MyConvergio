#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# RED test: orchestrator-test.sh must check bats-core, run all tests/test-*.sh, report total/pass/fail, output TAP, exit 1 if any fail

failures=0

# Test: script exists and is valid shell
if [ ! -f scripts/orchestrator-test.sh ]; then
  echo "not ok 1 - scripts/orchestrator-test.sh does not exist"
  failures=$((failures+1))
else
  bash -n scripts/orchestrator-test.sh || {
    echo "not ok 2 - scripts/orchestrator-test.sh is not valid shell"
    failures=$((failures+1))
  }
fi

# Test: bats-core check present
if ! grep -q 'bats' scripts/orchestrator-test.sh; then
  echo "not ok 3 - bats-core check missing"
  failures=$((failures+1))
else
  echo "ok 3 - bats-core check present"
fi

# Test: TAP output present
if ! grep -q 'TAP' scripts/orchestrator-test.sh; then
  echo "not ok 4 - TAP output missing"
  failures=$((failures+1))
else
  echo "ok 4 - TAP output present"
fi

# Test: line count < 100
lines=$(wc -l < scripts/orchestrator-test.sh)
if [ "$lines" -ge 100 ]; then
  echo "not ok 5 - scripts/orchestrator-test.sh exceeds 100 lines"
  failures=$((failures+1))
else
  echo "ok 5 - scripts/orchestrator-test.sh under 100 lines"
fi

exit $failures
