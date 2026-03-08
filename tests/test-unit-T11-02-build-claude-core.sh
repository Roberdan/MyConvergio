#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

SCRIPT_PATH="$REPO_ROOT/scripts/build-claude-core.sh"

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

[[ -f "$SCRIPT_PATH" ]] || fail "scripts/build-claude-core.sh must exist"
[[ -x "$SCRIPT_PATH" ]] || fail "scripts/build-claude-core.sh must be executable"
pass "build script exists and is executable"

EXPECTED=$'darwin-aarch64\ndarwin-x86_64\nlinux-aarch64\nlinux-x86_64'
ACTUAL="$(bash "$SCRIPT_PATH" --check-targets)"
[[ "$ACTUAL" == "$EXPECTED" ]] || fail "unexpected targets output: $ACTUAL"
pass "target list output is correct"

echo "[OK] T11-02 criteria satisfied"
