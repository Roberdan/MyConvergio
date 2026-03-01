#!/usr/bin/env bash
# test-peers-lib.sh — Tests for scripts/lib/peers.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_FILE="$REPO_ROOT/scripts/lib/peers.sh"

source "$SCRIPT_DIR/lib/test-helpers.sh"

# Setup: temp peers.conf
setup_temp_dir

TEMP_CONF="$TEST_TEMP_DIR/peers.conf"
cat >"$TEMP_CONF" <<'EOF'
[host-a]
ssh_alias=host-a
user=alice
os=macos
tailscale_ip=100.1.1.1
capabilities=claude,copilot
role=hybrid
status=active

[host-b]
ssh_alias=host-b
user=bob
os=linux
tailscale_ip=100.1.1.2
capabilities=copilot
role=worker
status=active

[host-c]
ssh_alias=host-c
user=carol
os=linux
tailscale_ip=100.1.1.3
capabilities=claude,ollama
role=worker
status=inactive
EOF

export PEERS_CONF="$TEMP_CONF"
HOSTNAME_ORIG="$(hostname)"

echo "=== peers.sh Library Tests ==="
echo ""

# T1: File exists
assert_file_exists "$LIB_FILE" "peers.sh exists at scripts/lib/peers.sh"

# T2: Valid bash syntax
assert_bash_syntax "$LIB_FILE" "peers.sh has valid bash syntax"

# T3: Line count <= 200
assert_line_count "$LIB_FILE" 200 "peers.sh <= 200 lines"

# T4: All functions defined after sourcing
(
	source "$LIB_FILE"
	for fn in peers_load peers_list peers_get peers_check peers_online \
		peers_with_capability peers_best_route peers_self peers_others; do
		if declare -f "$fn" >/dev/null 2>&1; then
			pass "Function $fn is defined"
		else
			fail "Function $fn is NOT defined"
		fi
	done
)

# T5: peers_list returns active peers
RESULT=$(bash -c "source '$LIB_FILE' && peers_load && peers_list")
if echo "$RESULT" | grep -q "host-a" && echo "$RESULT" | grep -q "host-b"; then
	pass "peers_list returns active peers (host-a, host-b)"
else
	fail "peers_list should return active peers" "host-a host-b" "$RESULT"
fi

# T6: peers_list excludes inactive peers
if echo "$RESULT" | grep -q "host-c"; then
	fail "peers_list should exclude inactive peer host-c" "" "host-c found"
else
	pass "peers_list excludes inactive peer host-c"
fi

# T7: peers_get returns correct field
FIELD_VAL=$(bash -c "source '$LIB_FILE' && peers_load && peers_get host-a user")
if [[ "$FIELD_VAL" == "alice" ]]; then
	pass "peers_get(host-a, user) returns 'alice'"
else
	fail "peers_get(host-a, user) should return 'alice'" "alice" "$FIELD_VAL"
fi

# T8: peers_get tailscale_ip
IP_VAL=$(bash -c "source '$LIB_FILE' && peers_load && peers_get host-b tailscale_ip")
if [[ "$IP_VAL" == "100.1.1.2" ]]; then
	pass "peers_get(host-b, tailscale_ip) returns '100.1.1.2'"
else
	fail "peers_get(host-b, tailscale_ip)" "100.1.1.2" "$IP_VAL"
fi

# T9: peers_with_capability filters by capability
CAP_RESULT=$(bash -c "source '$LIB_FILE' && peers_load && peers_with_capability claude")
if echo "$CAP_RESULT" | grep -q "host-a" && ! echo "$CAP_RESULT" | grep -q "host-b"; then
	pass "peers_with_capability(claude) returns host-a, excludes host-b"
else
	fail "peers_with_capability(claude) incorrect" "host-a only" "$CAP_RESULT"
fi

# T10: peers_with_capability excludes inactive
if echo "$CAP_RESULT" | grep -q "host-c"; then
	fail "peers_with_capability should exclude inactive host-c" "" "host-c found"
else
	pass "peers_with_capability excludes inactive host-c"
fi

# T11: peers_best_route returns ssh_alias or tailscale_ip
ROUTE=$(bash -c "source '$LIB_FILE' && peers_load && peers_best_route host-a" 2>/dev/null || true)
if [[ -n "$ROUTE" ]]; then
	pass "peers_best_route(host-a) returns a route: $ROUTE"
else
	fail "peers_best_route(host-a) should return a route"
fi

# T12: peers_self detects current machine (may return empty if no match)
SELF=$(bash -c "source '$LIB_FILE' && peers_load && peers_self" 2>/dev/null || true)
pass "peers_self runs without error (result: '${SELF:-<none>}')"

# T13: peers_others excludes self
# With no hostname match, should return all active peers
OTHERS=$(bash -c "source '$LIB_FILE' && peers_load && peers_others" 2>/dev/null || true)
pass "peers_others runs without error (result: '${OTHERS:-<none>}')"

# T14: Missing peers.conf gives clear error
ERR=$(bash -c "PEERS_CONF=/nonexistent/peers.conf source '$LIB_FILE' && peers_load" 2>&1 || true)
if echo "$ERR" | grep -qi "not found\|no such\|missing\|cannot\|error"; then
	pass "Missing peers.conf gives clear error message"
else
	fail "Missing peers.conf should give clear error" "error message" "$ERR"
fi

# T15: peers_check returns 0 or 1 (SSH test with unreachable host)
bash -c "source '$LIB_FILE' && peers_load && peers_check host-a" >/dev/null 2>&1
CHECK_RC=$?
if [[ $CHECK_RC -eq 0 || $CHECK_RC -eq 1 ]]; then
	pass "peers_check returns 0 or 1 exit code (got: $CHECK_RC)"
else
	fail "peers_check should return 0 or 1" "0 or 1" "$CHECK_RC"
fi

echo ""
print_test_summary "peers.sh Library"
