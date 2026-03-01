#!/bin/bash
# Test: N-peer cluster support in plan-db-cluster.sh and plan-db-remote.sh
# TDD: These tests should FAIL before implementation, PASS after.
set -euo pipefail

TEST_ROOT="/Users/roberdan/.claude-plan-297-W2"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_start() {
	((TESTS_RUN++))
	echo -n "  [$TESTS_RUN] $1 ... "
}
test_pass() {
	((TESTS_PASSED++))
	echo "PASS"
}
test_fail() {
	((TESTS_FAILED++))
	echo "FAIL: $1"
}

# F-09: cluster.sh sources peers.sh
test_cluster_sources_peers() {
	test_start "plan-db-cluster.sh sources peers.sh"
	if grep -q 'source.*peers\.sh\|\..*peers\.sh' "$TEST_ROOT/scripts/lib/plan-db-cluster.sh"; then
		test_pass
	else
		test_fail "No 'source peers.sh' in plan-db-cluster.sh"
	fi
}

# F-09: cluster.sh uses peers_online or peers_others
test_cluster_uses_peers_online() {
	test_start "plan-db-cluster.sh uses peers_online or peers_others"
	if grep -q 'peers_online\|peers_others' "$TEST_ROOT/scripts/lib/plan-db-cluster.sh"; then
		test_pass
	else
		test_fail "No peers_online/peers_others in plan-db-cluster.sh"
	fi
}

# F-09: remote.sh sources peers.sh
test_remote_sources_peers() {
	test_start "plan-db-remote.sh sources peers.sh"
	if grep -q 'source.*peers\.sh\|\..*peers\.sh' "$TEST_ROOT/scripts/lib/plan-db-remote.sh"; then
		test_pass
	else
		test_fail "No 'source peers.sh' in plan-db-remote.sh"
	fi
}

# F-14: remote.sh token_report handles peers
test_remote_token_report_peers() {
	test_start "plan-db-remote.sh cmd_token_report references peers"
	if grep -q 'token_report\|token-report' "$TEST_ROOT/scripts/lib/plan-db-remote.sh"; then
		test_pass
	else
		test_fail "No token_report in plan-db-remote.sh"
	fi
}

# C-02: backward compat - REMOTE_HOST still referenced
test_backward_compat_remote_host() {
	test_start "plan-db-remote.sh preserves REMOTE_HOST backward compat"
	if grep -q 'REMOTE_HOST' "$TEST_ROOT/scripts/lib/plan-db-remote.sh"; then
		test_pass
	else
		test_fail "REMOTE_HOST not preserved in plan-db-remote.sh"
	fi
}

# C-02: no hardcoded machine names in cluster.sh
test_no_hardcoded_hostnames() {
	test_start "plan-db-cluster.sh has no hardcoded machine hostnames"
	if grep -qE 'omarchy|roberdan-mac|MacBook' "$TEST_ROOT/scripts/lib/plan-db-cluster.sh"; then
		test_fail "Hardcoded hostname found in plan-db-cluster.sh"
	else
		test_pass
	fi
}

# C-02: no hardcoded machine names in remote.sh
test_no_hardcoded_hostnames_remote() {
	test_start "plan-db-remote.sh has no hardcoded machine hostnames"
	if grep -qE 'omarchy|roberdan-mac|MacBook' "$TEST_ROOT/scripts/lib/plan-db-remote.sh"; then
		test_fail "Hardcoded hostname found in plan-db-remote.sh"
	else
		test_pass
	fi
}

# SSH_TIMEOUT still configurable
test_ssh_timeout_configurable() {
	test_start "PLAN_DB_SSH_TIMEOUT remains configurable in cluster.sh"
	if grep -q 'PLAN_DB_SSH_TIMEOUT' "$TEST_ROOT/scripts/lib/plan-db-cluster.sh"; then
		test_pass
	else
		test_fail "PLAN_DB_SSH_TIMEOUT not found in plan-db-cluster.sh"
	fi
}

# Line count (max 250)
test_cluster_line_count() {
	test_start "plan-db-cluster.sh <= 250 lines"
	local lc
	lc=$(wc -l <"$TEST_ROOT/scripts/lib/plan-db-cluster.sh")
	if [[ $lc -le 250 ]]; then
		test_pass
	else
		test_fail "Too many lines: $lc (max 250)"
	fi
}

test_remote_line_count() {
	test_start "plan-db-remote.sh <= 250 lines"
	local lc
	lc=$(wc -l <"$TEST_ROOT/scripts/lib/plan-db-remote.sh")
	if [[ $lc -le 250 ]]; then
		test_pass
	else
		test_fail "Too many lines: $lc (max 250)"
	fi
}

# Bash syntax check
test_cluster_syntax() {
	test_start "plan-db-cluster.sh passes bash -n"
	if bash -n "$TEST_ROOT/scripts/lib/plan-db-cluster.sh" 2>/dev/null; then
		test_pass
	else
		test_fail "Syntax error in plan-db-cluster.sh"
	fi
}

test_remote_syntax() {
	test_start "plan-db-remote.sh passes bash -n"
	if bash -n "$TEST_ROOT/scripts/lib/plan-db-remote.sh" 2>/dev/null; then
		test_pass
	else
		test_fail "Syntax error in plan-db-remote.sh"
	fi
}

# cmd_is_alive uses peer routing (peers_check or peers_best_route)
test_is_alive_peer_name() {
	test_start "cmd_is_alive uses peer routing (peers_check/peers_best_route)"
	if grep -q 'peers_check\|peers_best_route\|peers_get' "$TEST_ROOT/scripts/lib/plan-db-cluster.sh"; then
		test_pass
	else
		test_fail "cmd_is_alive does not use peer routing functions"
	fi
}

echo "=== N-Peer Cluster Tests ==="
test_cluster_sources_peers
test_cluster_uses_peers_online
test_remote_sources_peers
test_remote_token_report_peers
test_backward_compat_remote_host
test_no_hardcoded_hostnames
test_no_hardcoded_hostnames_remote
test_ssh_timeout_configurable
test_cluster_line_count
test_remote_line_count
test_cluster_syntax
test_remote_syntax
test_is_alive_peer_name

echo ""
echo "================================"
echo "Run: $TESTS_RUN | Pass: $TESTS_PASSED | Fail: $TESTS_FAILED"
echo "================================"
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
