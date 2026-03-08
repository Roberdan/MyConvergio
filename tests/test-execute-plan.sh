#!/bin/bash
# Tests for execute-plan.sh
# Verifies: argument parsing, validation, engine checks, dry-run, resume logic
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXECUTE_SCRIPT="${SCRIPT_DIR}/../scripts/execute-plan.sh"
ENGINE_LIB="${SCRIPT_DIR}/../scripts/lib/execute-plan-engine.sh"

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

# -------------------------------------------------------------------
# T1: Script exists and is executable
# -------------------------------------------------------------------
echo "--- T1: Script exists and is executable ---"
if [[ -x "$EXECUTE_SCRIPT" ]]; then
	pass "execute-plan.sh exists and is executable"
else
	fail "execute-plan.sh not found or not executable"
fi

# -------------------------------------------------------------------
# T2: Bash syntax is valid
# -------------------------------------------------------------------
echo "--- T2: Bash syntax check ---"
if bash -n "$EXECUTE_SCRIPT" 2>/dev/null; then
	pass "bash -n passes"
else
	fail "bash -n failed"
fi

# -------------------------------------------------------------------
# T3: Help flag works
# -------------------------------------------------------------------
echo "--- T3: Help output ---"
HELP_OUT=$("$EXECUTE_SCRIPT" --help 2>&1 || true)
if echo "$HELP_OUT" | grep -q "Usage:"; then
	pass "--help shows Usage"
else
	fail "--help missing Usage line"
fi
if echo "$HELP_OUT" | grep -q "\-\-from"; then
	pass "--help mentions --from"
else
	fail "--help missing --from"
fi
if echo "$HELP_OUT" | grep -q "\-\-engine"; then
	pass "--help mentions --engine"
else
	fail "--help missing --engine"
fi
if echo "$HELP_OUT" | grep -q "\-\-dry-run"; then
	pass "--help mentions --dry-run"
else
	fail "--help missing --dry-run"
fi

# -------------------------------------------------------------------
# T4: Missing plan_id shows error
# -------------------------------------------------------------------
echo "--- T4: Missing plan_id ---"
ERR_OUT=$("$EXECUTE_SCRIPT" 2>&1 || true)
if echo "$ERR_OUT" | grep -qi "plan_id required\|usage"; then
	pass "Missing plan_id shows error"
else
	fail "Missing plan_id did not show error"
fi

# -------------------------------------------------------------------
# T5: Script references required components
# -------------------------------------------------------------------
echo "--- T5: Required components referenced ---"
CONTENT=$(cat "$EXECUTE_SCRIPT")
ENGINE_CONTENT="$(cat "$ENGINE_LIB")"

if echo "$CONTENT" | grep -q "delegate.sh"; then
	pass "References delegate.sh"
else
	fail "Missing delegate.sh reference"
fi

if echo "$CONTENT" | grep -q "copilot-worker.sh"; then
	pass "References copilot-worker.sh"
else
	fail "Missing copilot-worker.sh reference"
fi

if echo "$ENGINE_CONTENT" | grep -q "validate_task"; then
	pass "Has validate_task function"
else
	fail "Missing validate_task function"
fi

if echo "$ENGINE_CONTENT" | grep -q "validate_wave"; then
	pass "Has validate_wave function"
else
	fail "Missing validate_wave function"
fi

if echo "$ENGINE_CONTENT" | grep -q "plan-db.sh"; then
	pass "References plan-db.sh"
else
	fail "Missing plan-db.sh reference"
fi

# -------------------------------------------------------------------
# T6: Engine support check
# -------------------------------------------------------------------
echo "--- T6: Engine support ---"
if echo "$CONTENT" | grep -q "claude"; then
	pass "Supports claude engine"
else
	fail "Missing claude engine support"
fi

if echo "$CONTENT" | grep -q "copilot"; then
	pass "Supports copilot engine"
else
	fail "Missing copilot engine support"
fi

if echo "$CONTENT" | grep -q "opencode"; then
	pass "Supports opencode engine"
else
	fail "Missing opencode engine support"
fi

# -------------------------------------------------------------------
# T7: Dry-run flag support
# -------------------------------------------------------------------
echo "--- T7: Dry-run support ---"
if echo "$CONTENT" | grep -q "DRY_RUN"; then
	pass "DRY_RUN variable exists"
else
	fail "Missing DRY_RUN variable"
fi

if echo "$CONTENT" | grep -q "\-\-dry-run"; then
	pass "--dry-run flag parsed"
else
	fail "--dry-run flag not parsed"
fi

# -------------------------------------------------------------------
# T8: Resume logic (--from)
# -------------------------------------------------------------------
echo "--- T8: Resume logic ---"
if echo "$CONTENT" | grep -q "FROM_TASK"; then
	pass "FROM_TASK variable exists"
else
	fail "Missing FROM_TASK variable"
fi

if echo "$ENGINE_CONTENT" | grep -q "should_skip_task"; then
	pass "should_skip_task function exists"
else
	fail "Missing should_skip_task function"
fi

# -------------------------------------------------------------------
# T9: Timeout support
# -------------------------------------------------------------------
echo "--- T9: Timeout support ---"
if echo "$CONTENT" | grep -q "TASK_TIMEOUT"; then
	pass "TASK_TIMEOUT variable exists"
else
	fail "Missing TASK_TIMEOUT variable"
fi

if echo "$CONTENT" | grep -q "timeout"; then
	pass "timeout command used for task execution"
else
	fail "Missing timeout in task execution"
fi

# -------------------------------------------------------------------
# T10: Summary output
# -------------------------------------------------------------------
echo "--- T10: Summary section ---"
if echo "$ENGINE_CONTENT" | grep -q "EXECUTION SUMMARY"; then
	pass "Has execution summary section"
else
	fail "Missing execution summary"
fi

if echo "$ENGINE_CONTENT" | grep -q "TOTAL_TASKS"; then
	pass "Tracks total tasks"
else
	fail "Missing total tasks tracking"
fi

if echo "$ENGINE_CONTENT" | grep -q "FAILED_TASKS"; then
	pass "Tracks failed tasks"
else
	fail "Missing failed tasks tracking"
fi

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo ""
echo "=== RESULTS: $PASS/$TOTAL passed, $FAIL failed ==="
[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
