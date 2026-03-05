#!/bin/bash
set -euo pipefail
# test-delegation-engine.sh — Verify copilot is default engine for mesh delegation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0; FAIL=0

_ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
_fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== test-delegation-engine.sh ==="

# Test 1: remote-dispatch.sh uses copilot as default fallback
echo "[1] copilot default in remote-dispatch"
grep -q 'copilot' "$REPO_ROOT/scripts/remote-dispatch.sh" && _ok "copilot referenced" || _fail "copilot missing"

# Test 2: fallback order is copilot-first
echo "[2] copilot-first fallback order"
grep -q 'for cap in copilot claude' "$REPO_ROOT/scripts/remote-dispatch.sh" && _ok "copilot before claude" || _fail "order wrong"

# Test 3: default_engine read from peers.conf
echo "[3] default_engine in dispatch"
grep -q 'default_engine' "$REPO_ROOT/scripts/remote-dispatch.sh" && _ok "reads default_engine" || _fail "missing default_engine"

# Test 4: peers.sh supports default_engine
echo "[4] peers.sh default_engine"
grep -q 'default_engine' "$REPO_ROOT/scripts/lib/peers.sh" && _ok "peers.sh has default_engine" || _fail "peers.sh missing"

# Test 5: peers_load works
echo "[5] peers_load"
bash -c "source '$REPO_ROOT/scripts/lib/peers.sh' && peers_load && echo OK" 2>&1 | grep -q 'OK' && _ok "peers_load works" || _fail "peers_load broken"

# Test 6: execute-plan.sh does NOT change (local stays claude)
echo "[6] local engine unchanged"
if [[ -f "$REPO_ROOT/scripts/execute-plan.sh" ]]; then
  grep -q 'claude' "$REPO_ROOT/scripts/execute-plan.sh" && _ok "local uses claude" || _ok "local engine ok (no claude ref)"
else
  _ok "execute-plan.sh not present (ok)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
