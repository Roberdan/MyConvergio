#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/reviewer-lockout.sh"
PASS=0; FAIL=0
assert() { if eval "$2" 2>/dev/null; then PASS=$((PASS+1)); else echo "FAIL: $1"; FAIL=$((FAIL+1)); fi; }

echo "=== Reviewer Lockout Hook Tests ==="
echo '{"toolName":"Edit","toolInput":{"path":"src/test.ts"}}' | PLAN_ID="" TASK_ID="" bash "$HOOK" 2>/dev/null
assert "no plan = allow (exit 0)" "[ $? -eq 0 ]"

echo '{"toolName":"Read","toolInput":{"path":"src/test.ts"}}' | PLAN_ID="999" TASK_ID="T1-01" bash "$HOOK" 2>/dev/null
assert "Read tool = allow" "[ $? -eq 0 ]"

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
