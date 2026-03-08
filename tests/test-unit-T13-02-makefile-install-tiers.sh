#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

MAKEFILE="$REPO_ROOT/Makefile"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

[[ -f "$MAKEFILE" ]] || fail "Makefile must exist"

grep -q 'claude-core' "$MAKEFILE" || fail "Makefile must reference claude-core"
pass "Makefile references claude-core"

grep -q '^INSTALL_MINIMAL_TOOLS[[:space:]]*[:?+]*=' "$MAKEFILE" || fail "INSTALL_MINIMAL_TOOLS must be defined"
grep -q '^INSTALL_STANDARD_TOOLS[[:space:]]*[:?+]*=' "$MAKEFILE" || fail "INSTALL_STANDARD_TOOLS must be defined"
grep -q '^INSTALL_FULL_TOOLS[[:space:]]*[:?+]*=' "$MAKEFILE" || fail "INSTALL_FULL_TOOLS must be defined"
pass "install tier tool lists are defined"

if grep -q 'python3' "$MAKEFILE"; then
  grep -q 'optional' "$MAKEFILE" || fail "python3 exists but optional marker is missing"
fi
pass "python3 is marked optional"

echo "[OK] T13-02 criteria satisfied"
