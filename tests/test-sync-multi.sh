#!/usr/bin/env bash
# tests/test-sync-multi.sh — Multi-peer sync tests (no real network)
# Tests: sync-claude-config.sh, sync-dashboard-db.sh, sync-dashboard-db-multi.sh,
#        peer-sync.sh, shell-aliases.sh, tlx-presync.sh
# F-08, C-02, C-07
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

SYNC_CONFIG="$REPO_ROOT/scripts/sync-claude-config.sh"
SYNC_DB="$REPO_ROOT/scripts/sync-dashboard-db.sh"
SYNC_DB_MULTI_LIB="$REPO_ROOT/scripts/lib/sync-dashboard-db-multi.sh"
PEER_SYNC="$REPO_ROOT/scripts/peer-sync.sh"
TLX_PRESYNC="$REPO_ROOT/scripts/tlx-presync.sh"
ALIASES="$REPO_ROOT/shell-aliases.sh"

echo "=== test-sync-multi.sh: multi-peer sync tests (no real network) ==="
echo ""

# --- T1: peers.sh sourced in sync-claude-config.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'source.*peers\.sh|\..*peers\.sh' "$SYNC_CONFIG" 2>/dev/null; then
	pass "T1: peers.sh sourced in sync-claude-config.sh"
else
	fail "T1: peers.sh not sourced in sync-claude-config.sh"
fi

# --- T2: push-all subcommand exists in sync-claude-config.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'push-all\)' "$SYNC_CONFIG" 2>/dev/null; then
	pass "T2: push-all subcommand in sync-claude-config.sh"
else
	fail "T2: push-all missing from sync-claude-config.sh"
fi

# --- T3: pull-all subcommand exists in sync-claude-config.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'pull-all\)' "$SYNC_CONFIG" 2>/dev/null; then
	pass "T3: pull-all subcommand in sync-claude-config.sh"
else
	fail "T3: pull-all missing from sync-claude-config.sh"
fi

# --- T4: status-all subcommand exists in sync-claude-config.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'status-all\)' "$SYNC_CONFIG" 2>/dev/null; then
	pass "T4: status-all subcommand in sync-claude-config.sh"
else
	fail "T4: status-all missing from sync-claude-config.sh"
fi

# --- T5: push-all subcommand exists in sync-dashboard-db.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'push-all\)' "$SYNC_DB" 2>/dev/null; then
	pass "T5: push-all subcommand in sync-dashboard-db.sh"
else
	fail "T5: push-all missing from sync-dashboard-db.sh"
fi

# --- T6: pull-all subcommand exists in sync-dashboard-db.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'pull-all\)' "$SYNC_DB" 2>/dev/null; then
	pass "T6: pull-all subcommand in sync-dashboard-db.sh"
else
	fail "T6: pull-all missing from sync-dashboard-db.sh"
fi

# --- T7: sync-dashboard-db-multi.sh (lib) exists ---
assert_file_exists "$SYNC_DB_MULTI_LIB" "T7: scripts/lib/sync-dashboard-db-multi.sh exists"

# --- T8: sync-dashboard-db-multi.sh passes bash -n ---
assert_bash_syntax "$SYNC_DB_MULTI_LIB" "T8: sync-dashboard-db-multi.sh valid bash syntax"

# --- T9: peer-sync.sh exists and passes bash -n ---
assert_file_exists "$PEER_SYNC" "T9: scripts/peer-sync.sh exists"
assert_bash_syntax "$PEER_SYNC" "T9b: peer-sync.sh valid bash syntax"

# --- T10: peer-sync.sh push subcommand present ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'push\)' "$PEER_SYNC" 2>/dev/null; then
	pass "T10: push subcommand in peer-sync.sh"
else
	fail "T10: push missing from peer-sync.sh"
fi

# --- T11: peer-sync.sh pull subcommand present ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'pull\)' "$PEER_SYNC" 2>/dev/null; then
	pass "T11: pull subcommand in peer-sync.sh"
else
	fail "T11: pull missing from peer-sync.sh"
fi

# --- T12: peer-sync.sh status subcommand present ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'status\)' "$PEER_SYNC" 2>/dev/null; then
	pass "T12: status subcommand in peer-sync.sh"
else
	fail "T12: status missing from peer-sync.sh"
fi

# --- T13: psync alias defined in shell-aliases.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE "alias psync=" "$ALIASES" 2>/dev/null; then
	pass "T13: psync alias defined in shell-aliases.sh"
else
	fail "T13: psync alias missing from shell-aliases.sh"
fi

# --- T14: psync alias points to peer-sync.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE "alias psync=.*peer-sync\.sh" "$ALIASES" 2>/dev/null; then
	pass "T14: psync alias references peer-sync.sh"
else
	PSYNC_LINE=$(grep -E "alias psync=" "$ALIASES" 2>/dev/null || echo "not found")
	fail "T14: psync alias does not reference peer-sync.sh" "peer-sync.sh" "$PSYNC_LINE"
fi

# --- T15: C-02 backward compat — REMOTE_HOST=test-host bash -n exits 0 ---
TESTS_RUN=$((TESTS_RUN + 1))
if REMOTE_HOST=test-host bash -n "$SYNC_CONFIG" 2>/dev/null; then
	pass "T15: C-02 REMOTE_HOST=test-host bash -n sync-claude-config.sh exits 0"
else
	SYNTAX_ERR=$(REMOTE_HOST=test-host bash -n "$SYNC_CONFIG" 2>&1 || true)
	fail "T15: C-02 backward compat syntax check failed" "exit 0" "$SYNTAX_ERR"
fi

# --- T16: tlx-presync.sh references peers_check (not hardcoded hostname) ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "peers_check" "$TLX_PRESYNC" 2>/dev/null; then
	pass "T16: tlx-presync.sh uses peers_check (dynamic routing)"
else
	fail "T16: tlx-presync.sh missing peers_check reference"
fi

# --- T17: tlx-presync.sh does NOT hardcode a hostname for connectivity check ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'ssh.*omarchy|ssh.*roberdan|ssh.*mariodan' "$TLX_PRESYNC" 2>/dev/null; then
	MATCH=$(grep -oE 'ssh[^;]+' "$TLX_PRESYNC" | head -1)
	fail "T17: tlx-presync.sh hardcodes hostname in connectivity check" "dynamic via peers_check" "$MATCH"
else
	pass "T17: tlx-presync.sh uses no hardcoded SSH hostname for connectivity"
fi

# --- T18: C-07 — No 'omarchy' in sync-claude-config.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "omarchy" "$SYNC_CONFIG" 2>/dev/null; then
	MATCH=$(grep "omarchy" "$SYNC_CONFIG" | head -1)
	fail "T18: C-07 'omarchy' found in sync-claude-config.sh" "none" "$MATCH"
else
	pass "T18: C-07 no 'omarchy' in sync-claude-config.sh"
fi

# --- T19: C-07 — No 'omarchy' in sync-dashboard-db.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "omarchy" "$SYNC_DB" 2>/dev/null; then
	MATCH=$(grep "omarchy" "$SYNC_DB" | head -1)
	fail "T19: C-07 'omarchy' found in sync-dashboard-db.sh" "none" "$MATCH"
else
	pass "T19: C-07 no 'omarchy' in sync-dashboard-db.sh"
fi

# --- T20: C-07 — No 'omarchy' in peer-sync.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "omarchy" "$PEER_SYNC" 2>/dev/null; then
	MATCH=$(grep "omarchy" "$PEER_SYNC" | head -1)
	fail "T20: C-07 'omarchy' found in peer-sync.sh" "none" "$MATCH"
else
	pass "T20: C-07 no 'omarchy' in peer-sync.sh"
fi

# --- T21: C-07 — No 'omarchy' in tlx-presync.sh ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "omarchy" "$TLX_PRESYNC" 2>/dev/null; then
	MATCH=$(grep "omarchy" "$TLX_PRESYNC" | head -1)
	fail "T21: C-07 'omarchy' found in tlx-presync.sh" "none" "$MATCH"
else
	pass "T21: C-07 no 'omarchy' in tlx-presync.sh"
fi

# --- T22: C-07 — No 'omarchy' in sync-dashboard-db-multi.sh (lib) ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "omarchy" "$SYNC_DB_MULTI_LIB" 2>/dev/null; then
	MATCH=$(grep "omarchy" "$SYNC_DB_MULTI_LIB" | head -1)
	fail "T22: C-07 'omarchy' found in sync-dashboard-db-multi.sh" "none" "$MATCH"
else
	pass "T22: C-07 no 'omarchy' in sync-dashboard-db-multi.sh"
fi

# --- T23: sync-claude-config.sh bash -n (full syntax check) ---
assert_bash_syntax "$SYNC_CONFIG" "T23: sync-claude-config.sh valid bash syntax"

# --- T24: sync-dashboard-db.sh bash -n ---
assert_bash_syntax "$SYNC_DB" "T24: sync-dashboard-db.sh valid bash syntax"

# --- T25: sync-dashboard-db-multi.sh sourced check (errors if run directly) ---
TESTS_RUN=$((TESTS_RUN + 1))
DIRECT_RUN=$(bash "$SYNC_DB_MULTI_LIB" 2>&1 || true)
if echo "$DIRECT_RUN" | grep -q "must be sourced"; then
	pass "T25: sync-dashboard-db-multi.sh rejects direct execution"
else
	fail "T25: sync-dashboard-db-multi.sh should reject direct run" "must be sourced" "$DIRECT_RUN"
fi

echo ""
print_test_summary "test-sync-multi.sh"
