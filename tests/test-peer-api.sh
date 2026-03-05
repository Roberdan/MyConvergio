#!/bin/bash
set -euo pipefail
# test-peer-api.sh — Smoke tests for peer CRUD API endpoints
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DIR="$REPO_ROOT/scripts/dashboard_web"
PASS=0; FAIL=0

_ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
_fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== test-peer-api.sh ==="

# Test: module imports without error
echo "[1] api_peers import"
python3 -c "import sys; sys.path.insert(0, '$WEB_DIR'); import api_peers; print('OK')" 2>&1 | grep -q 'OK' && _ok "import ok" || _fail "import failed"

# Test: api_peer_list returns peers dict
echo "[2] api_peer_list"
python3 -c "
import sys; sys.path.insert(0, '$WEB_DIR')
from api_peers import api_peer_list
result = api_peer_list()
assert 'peers' in result, 'Missing peers key'
assert len(result['peers']) >= 3, f'Only {len(result[\"peers\"])} peers'
print('OK')
" 2>&1 | grep -q 'OK' && _ok "list returns >=3 peers" || _fail "list failed"

# Test: validation rejects invalid data
echo "[3] validation"
python3 -c "
import sys; sys.path.insert(0, '$WEB_DIR')
from api_peers import _validate_create
err = _validate_create({})
assert err is not None, 'Should reject empty data'
err2 = _validate_create({'peer_name': 'test', 'ssh_alias': 'x', 'user': 'x', 'os': 'windows', 'role': 'worker'})
assert err2 is not None, 'Should reject invalid os'
print('OK')
" 2>&1 | grep -q 'OK' && _ok "validation rejects bad data" || _fail "validation broken"

# Test: SSH check function exists and has ConnectTimeout
echo "[4] ssh_check endpoint"
grep -q 'ConnectTimeout' "$WEB_DIR/api_peers.py" && _ok "ConnectTimeout present" || _fail "ConnectTimeout missing"

# Test: discover function exists
echo "[5] discover endpoint"
grep -q 'def api_peer_discover' "$WEB_DIR/api_peers.py" && _ok "discover endpoint" || _fail "discover missing"

# Test: server routes include /api/peers
echo "[6] server routes"
grep -q '/api/peers' "$WEB_DIR/server.py" && _ok "routes registered" || _fail "routes missing"
grep -q 'do_POST' "$WEB_DIR/server.py" && _ok "POST handler" || _fail "POST missing"
grep -q 'do_DELETE' "$WEB_DIR/server.py" && _ok "DELETE handler" || _fail "DELETE missing"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
