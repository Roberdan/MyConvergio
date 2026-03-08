#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env
ROOT="$REPO_ROOT"

cd "$ROOT/rust/claude-core"

cargo build --quiet
BIN="$(pwd)/target/debug/claude-core"

"$BIN" --version-json | rg -q '"binary":"claude-core"'
"$BIN" | rg -q 'claude-core scaffold ready'

set +e
DB_OUT=$("$BIN" db --db-path "/tmp/claude-core-t13-03.db" status 2>&1)
DB_RC=$?
set -e
[[ $DB_RC -ne 0 ]]
echo "$DB_OUT" | rg -q 'db open failed'

echo "claude-core shell integration checks passed"
