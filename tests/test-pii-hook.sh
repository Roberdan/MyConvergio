#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/pii-advisory.sh"
PASS=0; FAIL=0
assert() { if eval "$2" 2>/dev/null; then PASS=$((PASS+1)); else echo "FAIL: $1"; FAIL=$((FAIL+1)); fi; }

echo "=== PII Advisory Hook Tests ==="
echo '{"toolName":"bash","toolOutput":"contact admin@secret.com for help"}' | bash "$HOOK" 2>/dev/null
assert "PII hook exits 0 (allow)" "[ $? -eq 0 ]"

echo '{"toolName":"bash","toolOutput":"Server at 192.168.1.100:3000"}' | bash "$HOOK" 2>/dev/null
assert "RFC1918 no crash" "[ $? -eq 0 ]"

echo '{"toolName":"Read","toolOutput":"admin@secret.com"}' | bash "$HOOK" 2>/dev/null
assert "non-bash tool skipped" "[ $? -eq 0 ]"

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
