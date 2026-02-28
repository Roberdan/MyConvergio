#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$HOME/.claude/scripts/db-digest.sh"

assert_true() {
  local msg="$1"
  shift
  if ! "$@"; then
    echo "FAIL: $msg" >&2
    return 1
  fi
}

assert_true "help exits 0" bash "$SCRIPT" --help >/dev/null

PLANS_JSON=$(bash "$SCRIPT" plans)
assert_true "plans emits valid plan ids" bash -lc "echo '$PLANS_JSON' | jq -e '.[] | .id | numbers' >/dev/null"

STATS_JSON=$(bash "$SCRIPT" stats)
assert_true "stats total_plans > 0" bash -lc "echo '$STATS_JSON' | jq -e '.total_plans > 0' >/dev/null"

echo "PASS"
