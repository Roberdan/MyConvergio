#!/bin/bash
# RED test: gh-ops-routing.sh must source pr-threads.sh, pr-comment-resolver, pr-ops.sh, agent-protocol.sh, delegate.sh
set -euo pipefail
failures=0

# 1. Syntax check
GH_OPS_ROUTING="/Users/roberdan/.claude-convergio-orchestrator/scripts/lib/gh-ops-routing.sh"

if ! bash -n "$GH_OPS_ROUTING" 2>/dev/null; then
  echo 'FAIL: bash -n failed'
  failures=$((failures+1))
else
  echo 'PASS: bash -n'
fi

# 2. Must reference pr-threads.sh and pr-ops.sh
if ! grep -q 'pr-threads' "$GH_OPS_ROUTING"; then
  echo 'FAIL: missing pr-threads reference'
  failures=$((failures+1))
else
  echo 'PASS: pr-threads reference'
fi
if ! grep -q 'pr-ops' "$GH_OPS_ROUTING"; then
  echo 'FAIL: missing pr-ops reference'
  failures=$((failures+1))
else
  echo 'PASS: pr-ops reference'
fi

# 3. Line count < 200
lines=$(wc -l < "$GH_OPS_ROUTING")
if [ "$lines" -ge 200 ]; then
  echo "FAIL: $lines lines (>=200)"
  failures=$((failures+1))
else
  echo "PASS: $lines lines (<200)"
fi

exit $failures
