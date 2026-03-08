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

[[ -d "$RUST_ROOT" ]] || fail "rust/claude-core directory must exist"
[[ -f "$RUST_ROOT/Cargo.toml" ]] || fail "Cargo.toml must exist"
[[ -f "$RUST_ROOT/src/main.rs" ]] || fail "src/main.rs must exist"
[[ -f "$RUST_ROOT/src/lib.rs" ]] || fail "src/lib.rs must exist"
pass "required Rust scaffold files exist"

for dir in db hooks digest lock; do
	[[ -d "$RUST_ROOT/src/$dir" ]] || fail "src/$dir directory must exist"
done
pass "required module directories exist"

cd "$RUST_ROOT"
cargo check 2>&1 | grep -q "Finished" || fail "cargo check must finish successfully"
pass "cargo check finished"

echo "[OK] T10-01 criteria satisfied"
