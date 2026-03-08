#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

TARGET="$REPO_ROOT/scripts/lib/plan-db-update.sh"

for pattern in "commit_sha" "lines_added" "rev-parse HEAD" "diff --stat" "plan_commits"; do
  if ! grep -q "$pattern" "$TARGET"; then
    echo "Missing pattern in plan-db-update.sh: $pattern"
    exit 1
  fi
done

echo "PASS"
