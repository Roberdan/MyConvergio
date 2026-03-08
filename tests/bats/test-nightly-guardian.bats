#!/usr/bin/env bats
# Tests for scripts/myconvergio-nightly-guardian.sh

setup() {
  NIGHTLY_SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/myconvergio-nightly-guardian.sh"
}

@test "nightly-guardian: script exists" {
  [ -f "$NIGHTLY_SCRIPT" ]
}

@test "nightly-guardian: parses cleanly" {
  run bash -n "$NIGHTLY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "nightly-guardian: uses set -euo pipefail" {
  run grep 'set -euo pipefail' "$NIGHTLY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "nightly-guardian: requires gh cli" {
  run grep -E 'require_cmd.*gh|command -v gh' "$NIGHTLY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "nightly-guardian: has configurable model" {
  run grep 'MODEL' "$NIGHTLY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "nightly-guardian: has configurable max items" {
  run grep 'MAX_ITEMS' "$NIGHTLY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "nightly-guardian: uses finalize/cleanup trap" {
  run grep -E 'trap.*EXIT|trap.*finalize' "$NIGHTLY_SCRIPT"
  [ "$status" -eq 0 ]
}
