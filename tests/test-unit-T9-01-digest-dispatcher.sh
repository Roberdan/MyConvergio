#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

DISPATCHER="$REPO_ROOT/scripts/digest.sh"

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

[[ -f "$DISPATCHER" ]] || fail "scripts/digest.sh must exist"
[[ -x "$DISPATCHER" ]] || fail "scripts/digest.sh must be executable"
pass "digest dispatcher exists and is executable"

line_count="$(wc -l <"$DISPATCHER" | tr -d ' ')"
[[ "$line_count" -le 250 ]] || fail "scripts/digest.sh must be <=250 lines (got $line_count)"
pass "dispatcher line count <=250"

for cmd in audit build ci copilot-review db deploy diff error git merge migration npm pr sentry service test; do
	grep -Eq "^[[:space:]]*${cmd}\)" "$DISPATCHER" || fail "dispatcher must route '${cmd}' subcommand"
done
pass "all 16 digest subcommands are routed"

bash "$DISPATCHER" ci --help >/dev/null
pass "ci subcommand help route works"

bash "$DISPATCHER" git --help >/dev/null
pass "git subcommand help route works"

echo "[OK] T9-01 criteria satisfied"
