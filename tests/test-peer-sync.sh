#!/usr/bin/env bash
# tests/test-peer-sync.sh — Unit tests for scripts/peer-sync.sh, shell-aliases.sh, tlx-presync.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PEER_SYNC="$REPO_ROOT/scripts/peer-sync.sh"
SHELL_ALIASES="$REPO_ROOT/scripts/shell-aliases.sh"
TLX_PRESYNC="$REPO_ROOT/scripts/tlx-presync.sh"

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

echo "=== test-peer-sync.sh: peer-sync.sh + shell-aliases + tlx-presync tests ==="

# ---- T1: Files exist ----
[[ -f "$PEER_SYNC" ]] && pass "T1a: peer-sync.sh exists" || fail "T1a: peer-sync.sh missing"
[[ -f "$SHELL_ALIASES" ]] && pass "T1b: scripts/shell-aliases.sh exists" || fail "T1b: scripts/shell-aliases.sh missing"
[[ -f "$TLX_PRESYNC" ]] && pass "T1c: tlx-presync.sh exists" || fail "T1c: tlx-presync.sh missing"

# ---- T2: Syntax checks ----
bash -n "$PEER_SYNC" 2>/dev/null && pass "T2a: peer-sync.sh syntax valid" || fail "T2a: peer-sync.sh syntax error"
bash -n "$SHELL_ALIASES" 2>/dev/null && pass "T2b: scripts/shell-aliases.sh syntax valid" || fail "T2b: scripts/shell-aliases.sh syntax error"
bash -n "$TLX_PRESYNC" 2>/dev/null && pass "T2c: tlx-presync.sh syntax valid" || fail "T2c: tlx-presync.sh syntax error"

# ---- T3: peer-sync.sh structure ----
grep -q 'push-all' "$PEER_SYNC" && pass "T3a: peer-sync.sh has push-all" || fail "T3a: missing push-all"
grep -q 'pull-all' "$PEER_SYNC" && pass "T3b: peer-sync.sh has pull-all" || fail "T3b: missing pull-all"
grep -q 'sync-claude-config.sh' "$PEER_SYNC" && pass "T3c: references sync-claude-config.sh" || fail "T3c: missing sync-claude-config.sh ref"
grep -q 'sync-dashboard-db.sh' "$PEER_SYNC" && pass "T3d: references sync-dashboard-db.sh" || fail "T3d: missing sync-dashboard-db.sh ref"
grep -qE '^# Version: ' "$PEER_SYNC" && pass "T3e: has version header" || fail "T3e: missing version header"

# ---- T4: peer-sync.sh has all commands ----
grep -q 'push)' "$PEER_SYNC" && pass "T4a: has push command" || fail "T4a: missing push command"
grep -q 'pull)' "$PEER_SYNC" && pass "T4b: has pull command" || fail "T4b: missing pull command"
grep -q 'status)' "$PEER_SYNC" && pass "T4c: has status command" || fail "T4c: missing status command"

# ---- T5: peer-sync.sh exit summary ----
grep -qE 'synced|failed|offline' "$PEER_SYNC" && pass "T5: has exit summary output" || fail "T5: missing exit summary (synced/failed/offline)"

# ---- T6: No hardcoded machine names ----
# Check for common hardcoded hostnames (C-07)
if grep -qE '\bomarchy\b|\btlx\b' "$PEER_SYNC" 2>/dev/null; then
	fail "T6: peer-sync.sh has hardcoded machine name" "no hardcoded names" "found"
else
	pass "T6: no hardcoded machine names in peer-sync.sh"
fi

# ---- T7: shell-aliases.sh has psync ----
grep -q 'psync' "$SHELL_ALIASES" && pass "T7a: scripts/shell-aliases.sh has psync alias" || fail "T7a: missing psync in scripts/shell-aliases.sh"
grep -q 'peer-sync.sh' "$SHELL_ALIASES" && pass "T7b: psync points to peer-sync.sh" || fail "T7b: psync does not reference peer-sync.sh"

# ---- T8: tlx-presync.sh has no hardcoded hostname ----
if grep -q 'omarchy' "$TLX_PRESYNC" 2>/dev/null; then
	fail "T8: tlx-presync.sh has hardcoded 'omarchy'" "no hardcoded hostname" "omarchy found"
else
	pass "T8: tlx-presync.sh no hardcoded hostname"
fi

# ---- T9: tlx-presync.sh uses peers_check ----
grep -q 'peers_check\|peers_load\|peers' "$TLX_PRESYNC" && pass "T9: tlx-presync.sh references peers functions" || fail "T9: tlx-presync.sh missing peers_check/peers_load"

# ---- T10: peer-sync.sh sources peers.sh ----
grep -q 'peers.sh' "$PEER_SYNC" && pass "T10: peer-sync.sh sources peers.sh" || fail "T10: peer-sync.sh should source lib/peers.sh"

# ---- T11: peer-sync.sh parallel execution ----
grep -qE '&\s*$|&$' "$PEER_SYNC" && pass "T11: peer-sync.sh uses parallel execution (&)" || fail "T11: should run commands in parallel with &"

# ---- T12: Line count limits ----
LC_PEER=$(wc -l <"$PEER_SYNC" | tr -d ' ')
[[ "$LC_PEER" -le 250 ]] && pass "T12a: peer-sync.sh ≤250 lines (got $LC_PEER)" || fail "T12a: peer-sync.sh exceeds 250 lines" "≤250" "$LC_PEER"

LC_ALIASES=$(wc -l <"$SHELL_ALIASES" | tr -d ' ')
[[ "$LC_ALIASES" -le 250 ]] && pass "T12b: scripts/shell-aliases.sh ≤250 lines (got $LC_ALIASES)" || fail "T12b: exceeds 250 lines" "≤250" "$LC_ALIASES"

# ---- T13: peer-sync.sh is executable ----
[[ -x "$PEER_SYNC" ]] && pass "T13: peer-sync.sh is executable" || fail "T13: peer-sync.sh not executable"

# ---- T14: peer-sync.sh help output ----
HELP_OUT=$(bash "$PEER_SYNC" --help 2>&1 || bash "$PEER_SYNC" -h 2>&1 || true)
echo "$HELP_OUT" | grep -qiE 'push|pull|status|usage' && pass "T14: peer-sync.sh has help output" || fail "T14: peer-sync.sh missing help/usage"

# ---- T15: peer-sync.sh unknown cmd exits non-zero ----
bash "$PEER_SYNC" unknown_cmd_xyz 2>/dev/null
RC=$?
[[ "$RC" -ne 0 ]] && pass "T15: peer-sync.sh exits non-zero on unknown cmd" || fail "T15: should exit non-zero" "non-zero" "$RC"

echo ""
echo "========================================="
echo "Total: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
echo "========================================="
[[ "$TESTS_FAILED" -eq 0 ]] && exit 0 || exit 1
