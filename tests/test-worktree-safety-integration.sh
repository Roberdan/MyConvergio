#!/usr/bin/env bash
# Test: worktree-safety.sh integration in delegate.sh and copilot-task-prompt.sh (T2-07)
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DELEGATE="${ROOT_DIR}/scripts/delegate.sh"
PROMPT="${ROOT_DIR}/scripts/copilot-task-prompt.sh"

PASS=0
FAIL=0
TOTAL=0

pass() {
	PASS=$((PASS + 1))
	TOTAL=$((TOTAL + 1))
	echo "  PASS: $1"
}
fail() {
	FAIL=$((FAIL + 1))
	TOTAL=$((TOTAL + 1))
	echo "  FAIL: $1"
}

echo "=== test-worktree-safety-integration.sh ==="

# delegate.sh: bash -n
if bash -n "$DELEGATE" >/dev/null 2>&1; then
	pass "delegate.sh: bash -n"
else
	fail "delegate.sh: bash -n"
fi

# delegate.sh: calls worktree-safety.sh
if grep -q 'worktree-safety' "$DELEGATE" 2>/dev/null; then
	pass "delegate.sh: references worktree-safety"
else
	fail "delegate.sh: references worktree-safety"
fi

# delegate.sh: calls pre-check subcommand
if grep -q 'pre-check' "$DELEGATE" 2>/dev/null; then
	pass "delegate.sh: calls pre-check subcommand"
else
	fail "delegate.sh: calls pre-check subcommand"
fi

# delegate.sh: pre-check called before worker dispatch (pre-check line before worker dispatch)
PRECHECK_LINE=$(grep -n 'pre-check' "$DELEGATE" 2>/dev/null | head -1 | cut -d: -f1)
DISPATCH_LINE=$(grep -n 'ROUTE_TARGET\|case "\$TASK_AGENT"' "$DELEGATE" 2>/dev/null | tail -1 | cut -d: -f1)
if [[ -n "$PRECHECK_LINE" && -n "$DISPATCH_LINE" && "$PRECHECK_LINE" -lt "$DISPATCH_LINE" ]]; then
	pass "delegate.sh: pre-check before worker dispatch (line $PRECHECK_LINE < $DISPATCH_LINE)"
else
	fail "delegate.sh: pre-check before worker dispatch (precheck=$PRECHECK_LINE dispatch=$DISPATCH_LINE)"
fi

# copilot-task-prompt.sh: bash -n
if bash -n "$PROMPT" >/dev/null 2>&1; then
	pass "copilot-task-prompt.sh: bash -n"
else
	fail "copilot-task-prompt.sh: bash -n"
fi

# copilot-task-prompt.sh: references worktree-safety
if grep -q 'worktree-safety' "$PROMPT" 2>/dev/null; then
	pass "copilot-task-prompt.sh: references worktree-safety"
else
	fail "copilot-task-prompt.sh: references worktree-safety"
fi

# copilot-task-prompt.sh: references audit subcommand
if grep -q 'audit' "$PROMPT" 2>/dev/null; then
	pass "copilot-task-prompt.sh: references audit subcommand"
else
	fail "copilot-task-prompt.sh: references audit subcommand"
fi

# Line count checks
DELEGATE_LINES=$(wc -l <"$DELEGATE")
if [[ "$DELEGATE_LINES" -le 250 ]]; then
	pass "delegate.sh: line count $DELEGATE_LINES <= 250"
else
	fail "delegate.sh: line count $DELEGATE_LINES > 250"
fi

PROMPT_LINES=$(wc -l <"$PROMPT")
if [[ "$PROMPT_LINES" -le 250 ]]; then
	pass "copilot-task-prompt.sh: line count $PROMPT_LINES <= 250"
else
	fail "copilot-task-prompt.sh: line count $PROMPT_LINES > 250"
fi

echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
