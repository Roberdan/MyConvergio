#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLANNER_SCRIPT="$ROOT_DIR/scripts/copilot-planner.sh"
ALIASES_FILE="$ROOT_DIR/shell-aliases.sh"
SKILL_FILE="$ROOT_DIR/.github/skills/planner.md"
PASS=0
FAIL=0

pass() {
	((PASS++)) 2>/dev/null || PASS=1
}

fail() {
	echo "✗ FAIL: $1"
	((FAIL++)) 2>/dev/null || FAIL=1
}

echo "Testing copilot-planner wrapper..."
echo "===================================="

[[ -f "$PLANNER_SCRIPT" ]] || fail "copilot-planner.sh not found"
[[ -x "$PLANNER_SCRIPT" ]] || fail "copilot-planner.sh is not executable"
bash -n "$PLANNER_SCRIPT" || fail "copilot-planner.sh has invalid bash syntax"

OUTPUT="$("$PLANNER_SCRIPT" --print "Plan a release hardening rollout")"
[[ "$OUTPUT" == *"@planner"* ]] || fail "prompt does not invoke @planner"
[[ "$OUTPUT" == *"claude-opus-4.6-1m"* ]] || fail "prompt does not pin planner model"
[[ "$OUTPUT" == *"not the built-in /plan command"* ]] || fail "prompt does not block /plan fallback"

grep -q 'cplanner()' "$ALIASES_FILE" || fail "shell alias cplanner missing"
grep -q 'cplannerp()' "$ALIASES_FILE" || fail "shell alias cplannerp missing"
grep -q 'Copilot CLI: `@planner` or `cplanner "goal"`' "$SKILL_FILE" || fail "planner skill usage not updated"

if [[ "$FAIL" -eq 0 ]]; then
	pass
	echo "✓ All tests passed!"
else
	echo "===================================="
	echo "Tests: $((PASS + FAIL)) | Passed: $PASS | Failed: $FAIL"
	exit 1
fi
