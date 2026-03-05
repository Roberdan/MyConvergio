#!/bin/bash
set -euo pipefail
# test-peer-crud.sh — Unit tests for peers_writer.py CRUD + backup + locking
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_ROOT/config"
WEB_DIR="$REPO_ROOT/scripts/dashboard_web"
PASS=0; FAIL=0

_ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
_fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== test-peer-crud.sh ==="

# Test 1: list_peers returns >=3 peers
echo "[1] list_peers"
result=$(python3 -c "
import sys; sys.path.insert(0, '$WEB_DIR')
from peers_writer import PeersWriter
pw = PeersWriter('$CONF_DIR/peers.conf')
peers = pw.list_peers()
print(len(peers))
" 2>&1)
[[ "$result" -ge 3 ]] && _ok "list_peers returns $result peers" || _fail "list_peers returned $result (expected >=3)"

# Test 2: add_peer creates a new peer
echo "[2] add_peer"
TMP_CONF=$(mktemp)
cp "$CONF_DIR/peers.conf" "$TMP_CONF"
python3 -c "
import sys; sys.path.insert(0, '$WEB_DIR')
from peers_writer import PeersWriter
pw = PeersWriter('$TMP_CONF')
pw.add_peer({'peer_name': 'testnode', 'ssh_alias': 'test-ts', 'user': 'testuser', 'os': 'linux', 'role': 'worker', 'default_engine': 'copilot'})
peers = pw.list_peers()
assert any(p['peer_name'] == 'testnode' for p in peers), 'testnode not found'
" 2>&1 && _ok "add_peer creates peer" || _fail "add_peer failed"

# Test 3: backup created
echo "[3] backup"
ls "${TMP_CONF}.bak."* >/dev/null 2>&1 && _ok "backup file created" || _fail "no backup file"

# Test 4: duplicate peer rejected
echo "[4] uniqueness"
python3 -c "
import sys; sys.path.insert(0, '$WEB_DIR')
from peers_writer import PeersWriter
pw = PeersWriter('$TMP_CONF')
try:
    pw.add_peer({'peer_name': 'TestNode', 'ssh_alias': 'x', 'user': 'x', 'os': 'linux', 'role': 'worker'})
    print('FAIL: should have raised')
    sys.exit(1)
except ValueError as e:
    if 'Duplicate' in str(e) or 'duplicate' in str(e).lower():
        print('OK')
    else:
        print(f'FAIL: wrong error: {e}')
        sys.exit(1)
" 2>&1 | grep -q 'OK' && _ok "duplicate rejected (case-insensitive)" || _fail "duplicate not rejected"

# Test 5: update_peer
echo "[5] update_peer"
python3 -c "
import sys; sys.path.insert(0, '$WEB_DIR')
from peers_writer import PeersWriter
pw = PeersWriter('$TMP_CONF')
pw.update_peer('testnode', {'status': 'inactive'})
" 2>&1 && _ok "update_peer works" || _fail "update_peer failed"

# Test 6: soft delete
echo "[6] soft delete"
python3 -c "
import sys; sys.path.insert(0, '$WEB_DIR')
from peers_writer import PeersWriter
pw = PeersWriter('$TMP_CONF')
pw.delete_peer('testnode', 'soft')
" 2>&1 && _ok "soft delete" || _fail "soft delete failed"

# Test 7: hard delete
echo "[7] hard delete"
python3 -c "
import sys; sys.path.insert(0, '$WEB_DIR')
from peers_writer import PeersWriter
pw = PeersWriter('$TMP_CONF')
pw.delete_peer('testnode', 'hard')
peers = pw.list_peers()
assert not any(p['peer_name'] == 'testnode' for p in peers), 'testnode still exists'
" 2>&1 && _ok "hard delete removes section" || _fail "hard delete failed"

# Test 8: comments preserved
echo "[8] comments preserved"
head -1 "$TMP_CONF" | grep -q '^#' && _ok "header comments preserved" || _fail "comments destroyed"

# Test 9: fcntl + atomic write
echo "[9] code checks"
grep -q 'fcntl' "$WEB_DIR/peers_writer.py" && _ok "fcntl present" || _fail "fcntl missing"
grep -q 'rename' "$WEB_DIR/peers_writer.py" && _ok "atomic rename present" || _fail "rename missing"

# Cleanup
rm -f "$TMP_CONF" "${TMP_CONF}.bak."* "${TMP_CONF}.tmp" "${TMP_CONF}.lock"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
