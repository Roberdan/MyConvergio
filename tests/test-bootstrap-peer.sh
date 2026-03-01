#!/usr/bin/env bash
# test-bootstrap-peer.sh — Static tests for scripts/bootstrap-peer.sh
# Tests: syntax, required patterns, structure (no real SSH)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="$REPO_ROOT/scripts/bootstrap-peer.sh"

source "$SCRIPT_DIR/lib/test-helpers.sh"

echo "=== bootstrap-peer.sh Tests ==="
echo ""

# T1: File exists
assert_file_exists "$TARGET" "bootstrap-peer.sh exists"

# T2: Valid bash syntax
assert_bash_syntax "$TARGET" "bootstrap-peer.sh has valid bash syntax (bash -n)"

# T3: Line count <= 250
assert_line_count "$TARGET" 250 "bootstrap-peer.sh <= 250 lines"

# T4: sources peers.sh library
assert_grep 'peers\.sh' "$TARGET" "sources scripts/lib/peers.sh"

# T5: calls peers_get
assert_grep 'peers_get' "$TARGET" "calls peers_get() from peers.sh"

# T6: ssh-copy-id or equivalent pattern for SSH key exchange
assert_grep 'ssh-copy-id\|ssh_copy\|authorized_keys' "$TARGET" "handles SSH key exchange (ssh-copy-id or authorized_keys)"

# T7: peer_heartbeats table write
assert_grep 'peer_heartbeats' "$TARGET" "writes heartbeat to peer_heartbeats table"

# T8: set -euo pipefail
assert_grep 'set -euo pipefail' "$TARGET" "uses set -euo pipefail"

# T9: uses CLAUDE_HOME not hardcoded ~/.claude
assert_grep 'CLAUDE_HOME' "$TARGET" "uses \$CLAUDE_HOME variable"

# T10: --skip-tools flag handling
assert_grep 'skip.tools\|skip_tools' "$TARGET" "handles --skip-tools flag"

# T11: JSON summary output
assert_grep 'ssh_ok\|db_ok\|path_ok' "$TARGET" "outputs JSON summary with ok fields"

# T12: mkdir -p on remote dirs
assert_grep 'mkdir.*-p' "$TARGET" "creates remote directories with mkdir -p"

# T13: init-db.sql referenced for DB init
assert_grep 'init-db' "$TARGET" "references init-db.sql for DB initialization"

# T14: bidirectional key setup
assert_grep 'bidirectional\|authorized_keys' "$TARGET" "bidirectional SSH key setup"

# T15: usage message on no args
result=$(bash "$TARGET" 2>&1 || true)
if echo "$result" | grep -qi "usage\|peer-name\|Usage"; then
	pass "Shows usage when called without args"
else
	fail "Shows usage when called without args" "Usage message" "$result"
fi

print_test_summary "bootstrap-peer.sh Tests"
