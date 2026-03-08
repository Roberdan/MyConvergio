#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

AGENTS_DIR="$REPO_ROOT/agents"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

[[ -d "$AGENTS_DIR" ]] || fail "agents directory must exist"

oversized=$(find "$AGENTS_DIR" -name '*.md' -exec wc -c {} + | awk '$1>1500 && !/total/{print}')
count=$(printf "%s\n" "$oversized" | sed '/^$/d' | wc -l | tr -d ' ')

if [[ "$count" != "0" ]]; then
  echo "[FAIL] agents/*.md files must be <= 1500 bytes"
  echo "$oversized"
  exit 1
fi

echo "[PASS] all agents/*.md files are <= 1500 bytes"
