#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

LOADER="$REPO_ROOT/scripts/lib/agent-context-loader.sh"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

[[ -f "$LOADER" ]] || fail "scripts/lib/agent-context-loader.sh must exist"
[[ -x "$LOADER" ]] || fail "scripts/lib/agent-context-loader.sh must be executable"
pass "agent context loader exists and is executable"

output="$("$LOADER" executor)"
bytes="$(printf '%s' "$output" | wc -c | tr -d '[:space:]')"

[[ -n "$output" ]] || fail "executor context output must not be empty"
[[ "$bytes" -gt 10000 ]] || fail "executor context should include substantial role context (>10k chars), got $bytes"
[[ "$bytes" -lt 50000 ]] || fail "executor context must stay below 50k chars, got $bytes"
[[ "$output" == *"### Source:"* ]] || fail "output must include source boundaries for concatenated instructions"
pass "executor context size and format constraints are satisfied"

echo "[OK] T14-02 criteria satisfied"
