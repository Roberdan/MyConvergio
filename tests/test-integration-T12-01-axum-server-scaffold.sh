#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

RUST_ROOT="$REPO_ROOT/rust/claude-core"

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

[[ -f "$RUST_ROOT/src/server/mod.rs" ]] || fail "src/server/mod.rs must exist"
[[ -f "$RUST_ROOT/src/server/routes.rs" ]] || fail "src/server/routes.rs must exist"
[[ -f "$RUST_ROOT/src/server/middleware.rs" ]] || fail "src/server/middleware.rs must exist"
pass "server scaffold files exist"

grep -q "pub const DASHBOARD_STATIC_DIR: &str = \"scripts/dashboard_web\"" "$RUST_ROOT/src/server/mod.rs" \
	|| fail "mod.rs must define dashboard static dir"
grep -q "/ws/brain" "$RUST_ROOT/src/server/routes.rs" || fail "routes.rs must include websocket route"
grep -q "/api/chat/stream/:sid" "$RUST_ROOT/src/server/routes.rs" || fail "routes.rs must include chat SSE route"
grep -rq "/api/github/commits" "$RUST_ROOT/src/server/" || fail "routes.rs must include github commits route"
pass "ported route table entries exist"

cd "$RUST_ROOT"
cargo check 2>&1 | grep -q "Finished" || fail "cargo check must finish successfully"
pass "cargo check finished"

echo "[OK] T12-01 criteria satisfied"
