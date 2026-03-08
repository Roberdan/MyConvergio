#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

C_SCRIPT="$REPO_ROOT/scripts/c"
SETTINGS_JSON="$REPO_ROOT/settings.json"

fail() { echo "[FAIL] $1" >&2; exit 1; }
pass() { echo "[PASS] $1"; }

[[ -x "$C_SCRIPT" ]] || fail "scripts/c must be executable"

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

cat > "$tmp_dir/claude-core" <<'CORE'
#!/usr/bin/env bash
printf 'FAKE-CORE:%s\n' "$*"
CORE
chmod +x "$tmp_dir/claude-core"

fake_hook_out="$(printf '{}' | PATH="$tmp_dir:/usr/bin:/bin" bash "$C_SCRIPT" hook pre)"
[[ "$fake_hook_out" == "FAKE-CORE:hook pre" ]] || fail "c hook pre must prefer claude-core"
pass "c hook pre prefers claude-core binary"

# Verify settings.json uses consolidated dispatcher
pre_command="$(python3 -c "import json; s=json.load(open('$SETTINGS_JSON')); hooks=[h for g in s.get('hooks',[]) if g.get('event')=='PreToolUse' for h in g.get('hooks',[])]; print(hooks[0].get('command','') if hooks else '')")"
[[ "$pre_command" == *"hook pre"* ]] || [[ "$pre_command" == *"dispatcher"* ]] || fail "PreToolUse must use hook dispatcher"
pass "settings PreToolUse uses hook dispatcher"

post_command="$(python3 -c "import json; s=json.load(open('$SETTINGS_JSON')); hooks=[h for g in s.get('hooks',[]) if g.get('event')=='PostToolUse' for h in g.get('hooks',[])]; print(hooks[0].get('command','') if hooks else '')")"
[[ "$post_command" == *"hook post"* ]] || [[ "$post_command" == *"dispatcher"* ]] || fail "PostToolUse must use hook dispatcher"
pass "settings PostToolUse uses hook dispatcher"

grep -q 'claude-core' "$C_SCRIPT" || fail "scripts/c must contain claude-core wiring"
pass "scripts/c contains claude-core wiring"

echo "[OK] T11-04 criteria satisfied"
