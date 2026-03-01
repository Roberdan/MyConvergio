#!/usr/bin/env bash
# test-c-dispatcher.sh — test suite for c dispatcher | Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCHER="$SCRIPT_DIR/../c"
COMPACT_LIB="$SCRIPT_DIR/../lib/c-compact.sh"

export PATH="$SCRIPT_DIR/..:$PATH"

PASS=0
FAIL=0

_ok() {
	echo "PASS: $1"
	PASS=$((PASS + 1))
}
_fail() {
	echo "FAIL: $1 — $2"
	FAIL=$((FAIL + 1))
}

# Test 1: c executable
if test -x "$DISPATCHER"; then
	_ok "c executable"
else
	_fail "c executable" "not found or not executable at $DISPATCHER"
fi

# Test 2: c --help responds with groups
if "$DISPATCHER" --help 2>&1 | grep -qE 'd|p|db'; then
	_ok "c --help shows groups"
else
	_fail "c --help shows groups" "missing group names in help output"
fi

# Test 3: c d --help shows original script
if "$DISPATCHER" d --help 2>&1 | grep -q 'service-digest\|git-digest'; then
	_ok "c d --help shows script equiv"
else
	_fail "c d --help shows script equiv" "missing service-digest or git-digest"
fi

# Test 4: c p --help shows plan-db
if "$DISPATCHER" p --help 2>&1 | grep -q 'plan-db'; then
	_ok "c p --help shows script equiv"
else
	_fail "c p --help shows script equiv" "missing plan-db reference"
fi

# Test 5: c db --help shows db-digest
if "$DISPATCHER" db --help 2>&1 | grep -q 'db-digest'; then
	_ok "c db --help shows script equiv"
else
	_fail "c db --help shows script equiv" "missing db-digest reference"
fi

# Test 6: c db stats returns valid JSON
if "$DISPATCHER" db stats 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "total_plans" in d' 2>/dev/null; then
	_ok "c db stats returns valid JSON with total_plans"
else
	_fail "c db stats returns valid JSON" "invalid or missing total_plans"
fi

# Test 7: c db token-stats returns valid JSON with tasks_done
if "$DISPATCHER" db token-stats 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "tasks_done" in d' 2>/dev/null; then
	_ok "c db token-stats valid JSON with tasks_done"
else
	_fail "c db token-stats valid JSON" "invalid or missing tasks_done"
fi

# Test 8: c db monthly returns array JSON
if "$DISPATCHER" db monthly 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d,list)' 2>/dev/null; then
	_ok "c db monthly returns JSON array"
else
	_fail "c db monthly returns JSON array" "not a list or invalid JSON"
fi

# Test 9: c d git returns valid JSON
if "$DISPATCHER" d git 2>/dev/null | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
	_ok "c d git returns valid JSON"
else
	_fail "c d git returns valid JSON" "invalid JSON output"
fi

# Test 10: c_strip_defaults removes null/0/false/[]
# shellcheck source=../lib/c-compact.sh
source "$COMPACT_LIB"
RESULT=$(echo '{"a":null,"b":0,"c":false,"d":"val","e":[]}' | c_strip_defaults)
if echo "$RESULT" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "d" in d and "a" not in d and "b" not in d and "c" not in d and "e" not in d' 2>/dev/null; then
	_ok "c_strip_defaults removes null/0/false/[] fields"
else
	_fail "c_strip_defaults removes null/0/false/[]" "got: $RESULT"
fi

# Test 11: Original keys preserved (no abbreviation)
RESULT=$(echo '{"status":"ok","ahead":0}' | c_strip_defaults)
if echo "$RESULT" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get("status")=="ok" and "s" not in d' 2>/dev/null; then
	_ok "keys preserved — no abbreviation (status not renamed to s)"
else
	_fail "keys preserved — no abbreviation" "got: $RESULT"
fi

# Test 12: Unknown subcommand exits non-zero
if "$DISPATCHER" xyz abc 2>/dev/null; then
	_fail "unknown subcommand exits non-zero" "exit code was 0"
else
	_ok "unknown subcommand exits non-zero"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
