#!/usr/bin/env bash
# tests/test-peers.sh — Unit tests for scripts/lib/peers.sh and peers.conf
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_FILE="$REPO_ROOT/scripts/lib/peers.sh"
REAL_CONF="$REPO_ROOT/config/peers.conf"

TESTS_RUN=0 TESTS_PASSED=0 TESTS_FAILED=0
pass() {
	TESTS_PASSED=$((TESTS_PASSED + 1))
	TESTS_RUN=$((TESTS_RUN + 1))
	echo -e "\033[0;32m✓ PASS\033[0m: $1"
}
fail() {
	TESTS_FAILED=$((TESTS_FAILED + 1))
	TESTS_RUN=$((TESTS_RUN + 1))
	echo -e "\033[0;31m✗ FAIL\033[0m: $1"
	[ $# -ge 2 ] && echo "  Expected: $2"
	[ $# -ge 3 ] && echo "  Got: $3"
}

# Create mock peers.conf in /tmp
MOCK_DIR=$(mktemp -d)
trap "rm -rf $MOCK_DIR" EXIT
MOCK_CONF="$MOCK_DIR/peers.conf"
cat >"$MOCK_CONF" <<'MOCKEOF'
[alpha]
ssh_alias=alpha
user=alice
os=macos
tailscale_ip=100.1.1.1
capabilities=claude,copilot,ollama
role=hybrid
status=active

[bravo]
ssh_alias=bravo
user=bob
os=linux
tailscale_ip=100.1.1.2
capabilities=copilot
role=worker
status=active

[charlie]
ssh_alias=charlie
user=carol
os=linux
tailscale_ip=100.1.1.3
capabilities=claude,ollama
role=worker
status=inactive
MOCKEOF

echo "=== test-peers.sh: lib/peers.sh + peers.conf tests ==="

# T1: peers.sh exists
[[ -f "$LIB_FILE" ]] && pass "T1: peers.sh exists" || fail "T1: peers.sh missing"

# T2: valid bash syntax
bash -n "$LIB_FILE" 2>/dev/null && pass "T2: peers.sh syntax valid" || fail "T2: peers.sh syntax error"

# T3: real peers.conf exists with 3+ entries
[[ -f "$REAL_CONF" ]] && pass "T3: config/peers.conf exists" || fail "T3: config/peers.conf missing"
ENTRY_COUNT=$(grep -c '^\[' "$REAL_CONF" 2>/dev/null || echo 0)
[[ "$ENTRY_COUNT" -ge 3 ]] && pass "T3b: peers.conf has $ENTRY_COUNT entries (>=3)" || fail "T3b: expected >=3 entries" ">=3" "$ENTRY_COUNT"

# T4: required fields in real peers.conf
for field in ssh_alias user os role status; do
	grep -q "^${field}=" "$REAL_CONF" 2>/dev/null && pass "T4: has field $field" || fail "T4: missing field $field"
done

# Source library with mock conf for functional tests
export PEERS_CONF="$MOCK_CONF"
source "$LIB_FILE"
peers_load

# T5: peers_list returns active peers
LIST_OUT=$(peers_list)
echo "$LIST_OUT" | grep -q "alpha" && echo "$LIST_OUT" | grep -q "bravo" &&
	pass "T5: peers_list returns alpha and bravo" ||
	fail "T5: peers_list" "alpha bravo" "$LIST_OUT"

# T6: peers_list excludes inactive
echo "$LIST_OUT" | grep -q "charlie" &&
	fail "T6: charlie should be excluded" "" "charlie found" ||
	pass "T6: excludes inactive charlie"

# T7: peers_get returns correct value
USER_VAL=$(peers_get alpha user)
[[ "$USER_VAL" == "alice" ]] && pass "T7: peers_get(alpha,user)=alice" || fail "T7: peers_get" "alice" "$USER_VAL"

# T8: peers_get tailscale_ip
IP_VAL=$(peers_get bravo tailscale_ip)
[[ "$IP_VAL" == "100.1.1.2" ]] && pass "T8: peers_get(bravo,ip)=100.1.1.2" || fail "T8: peers_get" "100.1.1.2" "$IP_VAL"

# T9: peers_get on inactive peer
STATUS_VAL=$(peers_get charlie status 2>/dev/null || echo "")
[[ "$STATUS_VAL" == "inactive" ]] && pass "T9: peers_get(charlie,status)=inactive" || fail "T9: peers_get" "inactive" "$STATUS_VAL"

# T10: peers_with_capability(ollama)
OLLAMA_OUT=$(peers_with_capability ollama)
echo "$OLLAMA_OUT" | grep -q "alpha" && ! echo "$OLLAMA_OUT" | grep -q "charlie" &&
	pass "T10: capability(ollama) returns alpha, excludes inactive" ||
	fail "T10: capability(ollama)" "alpha only" "$OLLAMA_OUT"

# T11: peers_with_capability(copilot)
COPILOT_OUT=$(peers_with_capability copilot)
echo "$COPILOT_OUT" | grep -q "alpha" && echo "$COPILOT_OUT" | grep -q "bravo" &&
	pass "T11: capability(copilot) returns alpha+bravo" ||
	fail "T11: capability(copilot)" "alpha bravo" "$COPILOT_OUT"

# T12: nonexistent capability
EMPTY_CAP=$(peers_with_capability nonexistent_xyz 2>/dev/null || true)
[[ -z "$EMPTY_CAP" ]] && pass "T12: capability(nonexistent) returns empty" || fail "T12: should be empty" "" "$EMPTY_CAP"

# T13: peers_self (won't match mock peers)
SELF_OUT=$(peers_self 2>/dev/null || true)
pass "T13: peers_self runs (result: '${SELF_OUT:-<none>}')"

# T13b: peers_self with matching hostname
CURRENT_HOST="$(hostname -s 2>/dev/null || hostname)"
SELF_CONF="$MOCK_DIR/self.conf"
cat >"$SELF_CONF" <<EOF
[$CURRENT_HOST]
ssh_alias=$CURRENT_HOST
user=testuser
os=macos
tailscale_ip=100.9.9.1
capabilities=claude
role=hybrid
status=active
EOF
PEERS_CONF="$SELF_CONF" peers_load
SELF_MATCH=$(peers_self 2>/dev/null || true)
[[ "$SELF_MATCH" == "$CURRENT_HOST" ]] && pass "T13b: peers_self detects $CURRENT_HOST" || fail "T13b: peers_self" "$CURRENT_HOST" "$SELF_MATCH"

# T14: peers_others excludes self
OTHERS_OUT=$(peers_others 2>/dev/null || true)
! echo "$OTHERS_OUT" | grep -q "$CURRENT_HOST" &&
	pass "T14: peers_others excludes self" ||
	fail "T14: should exclude $CURRENT_HOST" "" "$OTHERS_OUT"

# T15: peers_others with mock conf (no self-match)
export PEERS_CONF="$MOCK_CONF"
peers_load
OTHERS_ALL=$(peers_others 2>/dev/null || true)
echo "$OTHERS_ALL" | grep -q "alpha" && echo "$OTHERS_ALL" | grep -q "bravo" &&
	pass "T15: peers_others returns all when no self" ||
	fail "T15: peers_others" "alpha bravo" "$OTHERS_ALL"

# T16: missing peers.conf error
MISSING_ERR=$(PEERS_CONF="/nonexistent/peers.conf" bash -c "source '$LIB_FILE' && peers_load" 2>&1 || true)
echo "$MISSING_ERR" | grep -qiE "not found|missing|error" &&
	pass "T16: missing conf shows error" ||
	fail "T16: should show error" "error msg" "$MISSING_ERR"

# T17: missing conf returns non-zero
MISSING_RC=0
PEERS_CONF="/nonexistent" bash -c "source '$LIB_FILE' && peers_load" 2>/dev/null || MISSING_RC=$?
[[ "$MISSING_RC" -ne 0 ]] && pass "T17: non-zero on missing (exit=$MISSING_RC)" || fail "T17: should be non-zero" "non-zero" "$MISSING_RC"

# T18: line count
LINE_COUNT=$(peers_list | wc -l | tr -d ' ')
[[ "$LINE_COUNT" -eq 2 ]] && pass "T18: peers_list returns 2 lines" || fail "T18: line count" "2" "$LINE_COUNT"

echo ""
echo "========================================="
echo "Total: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
echo "========================================="
[[ "$TESTS_FAILED" -eq 0 ]] && exit 0 || exit 1
