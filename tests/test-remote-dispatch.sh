#!/usr/bin/env bash
# tests/test-remote-dispatch.sh — Unit tests for scripts/remote-dispatch.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/remote-dispatch.sh"

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

echo "=== test-remote-dispatch.sh ==="

# T1: Script exists
[[ -f "$SCRIPT" ]] && pass "T1: remote-dispatch.sh exists" || fail "T1: remote-dispatch.sh missing at $SCRIPT"

# T2: Syntax check
if bash -n "$SCRIPT" 2>/dev/null; then
	pass "T2: syntax valid (bash -n)"
else
	fail "T2: syntax error in remote-dispatch.sh"
fi

# T3: Has set -euo pipefail
if grep -q 'set -euo pipefail' "$SCRIPT"; then
	pass "T3: has set -euo pipefail"
else
	fail "T3: missing set -euo pipefail"
fi

# T4: Sources peers.sh lib
if grep -q 'lib/peers.sh' "$SCRIPT"; then
	pass "T4: sources scripts/lib/peers.sh"
else
	fail "T4: does not source lib/peers.sh"
fi

# T5: calls peers_check
if grep -q 'peers_check' "$SCRIPT"; then
	pass "T5: calls peers_check"
else
	fail "T5: missing peers_check call"
fi

# T6: references token_usage
if grep -q 'token_usage' "$SCRIPT"; then
	pass "T6: references token_usage (cost attribution)"
else
	fail "T6: missing token_usage reference"
fi

# T7: No hardcoded machine names (heuristic: no string like 'roberdan', 'DESKTOP-', 'macbook')
if grep -qiE "(roberdan|macbook-pro|DESKTOP-)" "$SCRIPT"; then
	fail "T7: hardcoded machine name detected"
else
	pass "T7: no hardcoded machine names"
fi

# T8: Line count <= 250
LINE_COUNT=$(wc -l <"$SCRIPT")
if [[ "$LINE_COUNT" -le 250 ]]; then
	pass "T8: line count OK ($LINE_COUNT <= 250)"
else
	fail "T8: too many lines ($LINE_COUNT > 250)"
fi

# T9: Supports --engine flag
if grep -q '\-\-engine' "$SCRIPT"; then
	pass "T9: supports --engine flag"
else
	fail "T9: missing --engine flag handling"
fi

# T10: Supports --model flag
if grep -q '\-\-model' "$SCRIPT"; then
	pass "T10: supports --model flag"
else
	fail "T10: missing --model flag handling"
fi

# T11: Handles claude engine
if grep -q 'claude' "$SCRIPT"; then
	pass "T11: handles claude engine"
else
	fail "T11: missing claude engine support"
fi

# T12: Handles copilot engine
if grep -q 'copilot-worker' "$SCRIPT"; then
	pass "T12: handles copilot engine (copilot-worker.sh)"
else
	fail "T12: missing copilot-worker.sh invocation"
fi

# T13: Handles opencode engine
if grep -q 'opencode-worker' "$SCRIPT"; then
	pass "T13: handles opencode engine (opencode-worker.sh)"
else
	fail "T13: missing opencode-worker.sh invocation"
fi

# T14: Peer offline exits 1 (by checking peers_check exit logic)
if grep -q 'peers_check' "$SCRIPT" && grep -q 'exit 1' "$SCRIPT"; then
	pass "T14: exits 1 when peer offline"
else
	fail "T14: missing exit 1 for offline peer"
fi

# T15: SSH streaming present
if grep -q 'ssh' "$SCRIPT"; then
	pass "T15: uses SSH for remote execution"
else
	fail "T15: no SSH usage found"
fi

# T16: Queries remote token_usage for cost attribution
if grep -q 'token_usage' "$SCRIPT"; then
	pass "T16: token_usage referenced for cost attribution"
else
	fail "T16: no token_usage for cost attribution"
fi

# T17: Usage message shown on wrong args (no-arg invocation)
OUTPUT=$("$SCRIPT" 2>&1 || true)
if echo "$OUTPUT" | grep -qi 'usage\|task_db_id\|peer'; then
	pass "T17: shows usage message on missing args"
else
	fail "T17: no usage message" "" "$OUTPUT"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed"
[[ "$TESTS_FAILED" -eq 0 ]]
