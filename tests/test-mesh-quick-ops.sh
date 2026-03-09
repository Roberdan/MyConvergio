#!/usr/bin/env bash
set -euo pipefail
# Tests for mesh quick operations scripts
# Run: bash tests/test-mesh-quick-ops.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0 FAIL=0
_ok() { PASS=$((PASS+1)); echo "  ✓ $1"; }
_fail() { FAIL=$((FAIL+1)); echo "  ✗ $1: $2"; }

echo "=== mesh-sync.sh ==="
bash -n "$SCRIPT_DIR/scripts/mesh-sync.sh" && _ok "syntax" || _fail "syntax" "parse error"
grep -q 'peers_load' "$SCRIPT_DIR/scripts/mesh-sync.sh" && _ok "uses peers.sh" || _fail "uses peers.sh" "missing peers_load"
grep -q 'gh_account\|gh auth' "$SCRIPT_DIR/scripts/mesh-sync.sh" && _ok "handles gh auth" || _fail "handles gh auth" "no auth handling"
grep -q '\-\-dry-run' "$SCRIPT_DIR/scripts/mesh-sync.sh" && _ok "supports --dry-run" || _fail "supports --dry-run" "missing flag"
grep -q '\-\-force' "$SCRIPT_DIR/scripts/mesh-sync.sh" && _ok "supports --force" || _fail "supports --force" "missing flag"
grep -q '\-\-peer' "$SCRIPT_DIR/scripts/mesh-sync.sh" && _ok "supports --peer" || _fail "supports --peer" "missing flag"
grep -q 'apply-migrations' "$SCRIPT_DIR/scripts/mesh-sync.sh" && _ok "triggers migrations" || _fail "triggers migrations" "no migration step"
lines=$(wc -l < "$SCRIPT_DIR/scripts/mesh-sync.sh")
[[ $lines -le 110 ]] && _ok "line count ($lines ≤ 110)" || _fail "line count" "$lines > 110"

echo "=== mesh-exec.sh ==="
bash -n "$SCRIPT_DIR/scripts/mesh-exec.sh" && _ok "syntax" || _fail "syntax" "parse error"
grep -q 'peers_load' "$SCRIPT_DIR/scripts/mesh-exec.sh" && _ok "uses peers.sh" || _fail "uses peers.sh" "missing peers_load"
grep -q 'copilot\|claude' "$SCRIPT_DIR/scripts/mesh-exec.sh" && _ok "supports both tools" || _fail "supports both tools" "missing tool support"
grep -q '\-\-model' "$SCRIPT_DIR/scripts/mesh-exec.sh" && _ok "supports --model" || _fail "supports --model" "missing flag"
grep -q '\-\-tool' "$SCRIPT_DIR/scripts/mesh-exec.sh" && _ok "supports --tool" || _fail "supports --tool" "missing flag"
grep -q 'gh_account\|gh auth' "$SCRIPT_DIR/scripts/mesh-exec.sh" && _ok "handles gh auth" || _fail "handles gh auth" "no auth handling"
lines=$(wc -l < "$SCRIPT_DIR/scripts/mesh-exec.sh")
[[ $lines -le 80 ]] && _ok "line count ($lines ≤ 80)" || _fail "line count" "$lines > 80"

echo "=== mesh-health.sh ==="
bash -n "$SCRIPT_DIR/scripts/mesh-health.sh" && _ok "syntax" || _fail "syntax" "parse error"
grep -q 'peers_load' "$SCRIPT_DIR/scripts/mesh-health.sh" && _ok "uses peers.sh" || _fail "uses peers.sh" "missing peers_load"
grep -q 'COMMIT\|commit\|SHA' "$SCRIPT_DIR/scripts/mesh-health.sh" && _ok "shows commit" || _fail "shows commit" "missing"
grep -q 'DB\|db_cols' "$SCRIPT_DIR/scripts/mesh-health.sh" && _ok "shows DB status" || _fail "shows DB status" "missing"
grep -q 'SERVER\|server\|8420' "$SCRIPT_DIR/scripts/mesh-health.sh" && _ok "checks server" || _fail "checks server" "missing"
grep -q '\-\-peer' "$SCRIPT_DIR/scripts/mesh-health.sh" && _ok "supports --peer" || _fail "supports --peer" "missing flag"
lines=$(wc -l < "$SCRIPT_DIR/scripts/mesh-health.sh")
[[ $lines -le 80 ]] && _ok "line count ($lines ≤ 80)" || _fail "line count" "$lines > 80"

echo "=== apply-migrations.sh ==="
bash -n "$SCRIPT_DIR/scripts/apply-migrations.sh" && _ok "syntax" || _fail "syntax" "parse error"
grep -q 'state.rs' "$SCRIPT_DIR/scripts/apply-migrations.sh" && _ok "reads state.rs" || _fail "reads state.rs" "missing"
grep -q 'sqlite3' "$SCRIPT_DIR/scripts/apply-migrations.sh" && _ok "uses sqlite3" || _fail "uses sqlite3" "missing"
grep -q 'ALTER TABLE\|CREATE TABLE' "$SCRIPT_DIR/scripts/apply-migrations.sh" && _ok "extracts migrations" || _fail "extracts migrations" "no pattern"
lines=$(wc -l < "$SCRIPT_DIR/scripts/apply-migrations.sh")
[[ $lines -le 30 ]] && _ok "line count ($lines ≤ 30)" || _fail "line count" "$lines > 30"

echo "=== peers.conf ==="
grep -q 'gh_account' "$SCRIPT_DIR/config/peers.conf" && _ok "has gh_account field" || _fail "has gh_account field" "missing"
for peer in m3max omarchy m1mario; do
  grep -A 15 "^\[$peer\]" "$SCRIPT_DIR/config/peers.conf" | grep -q 'gh_account=' && _ok "$peer has gh_account" || _fail "$peer has gh_account" "missing"
done

echo "=== Integration: apply-migrations.sh live ==="
OUTPUT=$(bash "$SCRIPT_DIR/scripts/apply-migrations.sh" 2>&1)
echo "$OUTPUT" | grep -q 'Migrations:' && _ok "runs successfully" || _fail "runs" "$OUTPUT"

echo "=== Docs ==="
grep -q 'mesh-sync.sh' "$SCRIPT_DIR/reference/operational/digest-scripts.md" && _ok "in digest-scripts" || _fail "in digest-scripts" "missing"
grep -q 'mesh-sync.sh' "$SCRIPT_DIR/reference/operational/mesh-networking.md" && _ok "in mesh-networking" || _fail "in mesh-networking" "missing"
grep -q 'mesh-sync.sh\|mesh-health.sh' "$SCRIPT_DIR/rules/migration-checklist.md" && _ok "in migration checklist" || _fail "in migration checklist" "missing"
test -f "$SCRIPT_DIR/docs/adr/0041-mesh-quick-operations.md" && _ok "ADR 0041 exists" || _fail "ADR 0041" "missing"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
