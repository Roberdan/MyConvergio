#!/bin/bash
# RED test: plan-db.sh delegation-report should fail before implementation
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail_count=0

# 1. Syntax check for scripts/lib/plan-db-delegate.sh (should exist now)
if bash -n scripts/lib/plan-db-delegate.sh 2>/dev/null; then
  echo 'PASS: scripts/lib/plan-db-delegate.sh exists.'
else
  echo 'FAIL: scripts/lib/plan-db-delegate.sh missing or syntax error.'
  fail_count=$((fail_count+1))
fi

# 2. plan-db.sh delegation-report should succeed (exit code == 0)
if scripts/plan-db.sh delegation-report 2>/dev/null; then
  echo 'PASS: plan-db.sh delegation-report succeeded.'
else
  echo 'FAIL: plan-db.sh delegation-report failed.'
  fail_count=$((fail_count+1))
fi

# 3. grep plan-db-delegate in scripts/plan-db.sh should find registration
if grep 'plan-db-delegate' scripts/plan-db.sh; then
  echo 'PASS: plan-db-delegate registered in plan-db.sh.'
else
  echo 'FAIL: plan-db-delegate not registered in plan-db.sh.'
  fail_count=$((fail_count+1))
fi

exit $fail_count
