#!/bin/bash
# Test: hook registration — checks consolidated dispatcher includes required hooks
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail=0

check_hook() {
  local name="$1"
  if grep -rq "$name" "$REPO_ROOT/settings.json" "$REPO_ROOT/hooks/dispatcher.sh" "$REPO_ROOT/hooks/lib/hook-checks.sh" 2>/dev/null; then
    echo "PASS: $name registered"
  else
    echo "FAIL: $name not registered"
    fail=1
  fi
}

check_hook "model-registry-refresh"
check_hook "env.vault.guard"

exit $fail
