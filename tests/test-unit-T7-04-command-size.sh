#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

count=$(find "$REPO_ROOT/commands" -maxdepth 1 -name '*.md' -exec wc -c {} + | awk '$1>4000 && !/total/{print}' | wc -l | tr -d ' ')

if [[ "$count" != "0" ]]; then
  echo "[FAIL] commands/*.md files must be <= 4000 bytes"
  find "$REPO_ROOT/commands" -maxdepth 1 -name '*.md' -exec wc -c {} + | awk '$1>4000 && !/total/{print}'
  exit 1
fi

echo "[PASS] all commands/*.md files are <= 4000 bytes"
