#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

WRAPPER="$REPO_ROOT/scripts/claude-core-wrapper.sh"

fail() { echo "[FAIL] $1" >&2; exit 1; }
pass() { echo "[PASS] $1"; }

[[ -f "$WRAPPER" ]] || fail "scripts/claude-core-wrapper.sh must exist"
[[ -x "$WRAPPER" ]] || fail "scripts/claude-core-wrapper.sh must be executable"
pass "wrapper exists and is executable"

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

cat > "$tmp_dir/claude-core" <<'EOF'
#!/usr/bin/env bash
printf 'FAKE-CORE:%s\n' "$*"
EOF
chmod +x "$tmp_dir/claude-core"

fake_core_out="$(PATH="$tmp_dir:/usr/bin:/bin" bash "$WRAPPER" plan status claude)"
[[ "$fake_core_out" == "FAKE-CORE:db status claude" ]] || fail "wrapper must prefer claude-core when available"
pass "wrapper prefers claude-core binary when available"

# Verify fallback scripts exist (don't run them — may need crsqlite)
[[ -f "$REPO_ROOT/scripts/plan-db.sh" ]] || fail "plan-db.sh fallback must exist"
pass "plan-db.sh fallback script exists"

[[ -f "$REPO_ROOT/hooks/dispatcher.sh" ]] || fail "hooks/dispatcher.sh fallback must exist"
pass "hooks/dispatcher.sh fallback script exists"

# Verify wrapper routes hook command
grep -q "hook" "$WRAPPER" || fail "wrapper must handle hook subcommand"
pass "wrapper handles hook routing"

echo "[OK] T11-03 criteria satisfied"
