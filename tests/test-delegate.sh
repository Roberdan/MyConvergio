#!/usr/bin/env bash
# Test: delegate.sh syntax, routing references, privacy, budget, line count
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${SCRIPT_DIR}/scripts/delegate.sh"
PASS=0
FAIL=0

pass() {
	PASS=$((PASS + 1))
	echo "  PASS: $1"
}
fail() {
	FAIL=$((FAIL + 1))
	echo "  FAIL: $1"
}

echo "=== test-delegate.sh ==="

# T1: File exists and is executable
if [ -x "$TARGET" ]; then
	pass "file exists and is executable"
else fail "file not found or not executable"; fi

# T2: Bash syntax check
if bash -n "$TARGET" 2>/dev/null; then
	pass "bash -n"
else fail "bash -n failed"; fi

# T3: Routes to copilot-worker
if grep -q 'copilot-worker' "$TARGET"; then
	pass "routes to copilot-worker"
else fail "missing copilot-worker routing"; fi

# T4: Routes to opencode-worker
if grep -q 'opencode-worker' "$TARGET"; then
	pass "routes to opencode-worker"
else fail "missing opencode-worker routing"; fi

# T5: Routes to gemini-worker
if grep -q 'gemini-worker' "$TARGET"; then
	pass "routes to gemini-worker"
else fail "missing gemini-worker routing"; fi

# T6: Privacy check
if grep -q 'privacy' "$TARGET"; then
	pass "privacy check present"
else fail "missing privacy check"; fi

# T7: Budget check
if grep -q 'budget' "$TARGET"; then
	pass "budget check present"
else fail "missing budget check"; fi

# T8: Sources delegate-utils
if grep -q 'delegate-utils' "$TARGET"; then
	pass "sources delegate-utils"
else fail "missing delegate-utils source"; fi

# T9: Reads task data from DB
if grep -q 'sqlite3\|DB_FILE\|dashboard.db' "$TARGET"; then
	pass "reads from DB"
else fail "missing DB access"; fi

# T10: Worktree safety reference
if grep -q 'worktree-safety\|worktree' "$TARGET"; then
	pass "worktree safety reference"
else fail "missing worktree safety"; fi

# T11: orchestrator.yaml reference
if grep -q 'orchestrator.yaml' "$TARGET"; then
	pass "orchestrator.yaml reference"
else fail "missing orchestrator.yaml"; fi

# T12: Line count <= 250 (verify criteria: awk exits 1 if >250)
lines=$(wc -l <"$TARGET")
if [ "$lines" -le 250 ]; then
	pass "$lines lines (<=250)"
else fail "$lines lines (>250)"; fi

# T13: --host flag present in argument parser
if grep -q -- '--host' "$TARGET"; then
	pass "--host flag in argument parser"
else fail "--host flag missing"; fi

# T14: remote-dispatch.sh invocation present
if grep -q 'remote-dispatch' "$TARGET"; then
	pass "remote-dispatch.sh invocation present"
else fail "remote-dispatch.sh not referenced"; fi

# T15: peers_self check (lazy-loaded peers.sh only on --host)
if grep -q 'peers_self\|peers\.sh' "$TARGET"; then
	pass "peers_self / peers.sh reference present"
else fail "peers_self / peers.sh reference missing"; fi

# T16: No hardcoded machine names (check for common hostname patterns)
if grep -qE '(macbook|MacBook|laptop|desktop|imac|iMac|workstation)[^-]' "$TARGET"; then
	fail "hardcoded machine names detected"
else pass "no hardcoded machine names"; fi

# T17: mesh: section in orchestrator.yaml
YAML="${SCRIPT_DIR}/config/orchestrator.yaml"
if grep -q 'max_tasks_per_peer' "$YAML" && grep -q 'dispatch_timeout' "$YAML"; then
	pass "orchestrator.yaml has mesh defaults"
else fail "orchestrator.yaml missing mesh defaults"; fi

echo ""
echo "=== Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
