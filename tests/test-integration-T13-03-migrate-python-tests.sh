#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env
ROOT="$REPO_ROOT"

cd "$ROOT/rust/claude-core"

count_target_tests() {
  local target=$1
  cargo test --test "$target" -- --list \
    | rg ': test$' \
    | wc -l \
    | tr -d ' '
}

RUST_TEST_COUNT=$(( \
  $(count_target_tests ported_get_routes) + \
  $(count_target_tests ported_non_get_routes) + \
  $(count_target_tests ported_route_contracts) \
))
if [[ "$RUST_TEST_COUNT" -ne 99 ]]; then
  echo "Expected exactly 99 migrated Rust #[test] cases under rust/claude-core/tests, found: $RUST_TEST_COUNT"
  exit 1
fi

if ! rg -n 'claude-core' "$ROOT/tests"/*.sh >/dev/null 2>&1; then
  echo "Expected at least one shell integration test in tests/ invoking claude-core"
  exit 1
fi

echo "T13-03 migration contract satisfied (99 Rust tests + shell integration present)."
