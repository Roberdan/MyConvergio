#!/bin/bash
# test-copilot-worker.sh - Test copilot-worker.sh retry logic, exit codes, Thor validation, and file-lock integration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKER="${SCRIPT_DIR}/../scripts/copilot-worker.sh"
PASS=0
FAIL=0

# Test helper
test_pattern() {
	((PASS++)) 2>/dev/null || PASS=1
	if ! grep -qE "$1" "$WORKER"; then
		echo "✗ FAIL: $2"
		((FAIL++)) 2>/dev/null || FAIL=1
		((PASS--))
	fi
}

test_count() {
	local count=$(grep -cE "$1" "$WORKER" || true)
	((PASS++)) 2>/dev/null || PASS=1
	if [[ "$count" -ne "$2" ]]; then
		echo "✗ FAIL: $3 (expected $2, got $count)"
		((FAIL++)) 2>/dev/null || FAIL=1
		((PASS--))
	fi
}

[[ ! -f "$WORKER" ]] && {
	echo "ERROR: copilot-worker.sh not found"
	exit 1
}

echo "Testing copilot-worker.sh..."
echo "===================================="

# Test 1: Retry Logic
test_pattern "^MAX_RETRIES=" "MAX_RETRIES defined"
test_pattern "^RETRY_DELAYS=\(" "RETRY_DELAYS array defined"
test_pattern "while.*ATTEMPT.*-le.*MAX_RETRIES" "Retry loop exists"
test_pattern "ATTEMPT\+\+" "Attempt counter incremented"
test_pattern "Attempt.*ATTEMPT.*MAX_RETRIES" "Retry logging"
test_pattern "RETRY_DELAY.*RETRY_DELAYS" "Delay from array"
test_pattern "sleep.*RETRY_DELAY" "Sleep on retry"
test_pattern "Retrying in.*RETRY_DELAY" "Retry message"
test_pattern "Timeout after.*MAX_RETRIES.*attempts" "Max retries message"

# Test 2: Exit Code Handling
test_pattern "# Exit codes: 0=success, 1=error, 124=timeout, 130=interrupted" "Exit code docs"
test_pattern "EXEC_EXIT_CODE.*-eq 0" "Exit 0 check"
test_pattern "EXEC_EXIT_CODE.*-eq 124" "Exit 124 check"
test_pattern "EXEC_EXIT_CODE.*-eq 130" "Exit 130 check"
test_pattern "exit.*EXIT_CODE" "Proper exit"
test_pattern "FINAL_EXIT_CODE" "Final exit code var"
test_pattern "EXIT_CODE.*-eq 124" "Timeout handling"
test_pattern "status.*timeout" "Timeout status"
test_pattern "EXIT_CODE.*-eq 130" "Interrupted handling"
test_pattern "status.*interrupted" "Interrupted status"
test_pattern "EXIT_CODE.*-ne 0" "Non-zero differentiation"

# Test 3: Thor Validation
test_pattern "THOR_RESULT" "THOR_RESULT variable"
test_pattern "plan-db.sh\" validate-task" "Thor validation command invoked"
test_pattern "THOR_RESULT=\"PASS\"" "THOR_RESULT PASS"
test_pattern "THOR_RESULT=\"REJECT\"" "THOR_RESULT REJECT"
test_pattern "THOR_RESULT=\"UNKNOWN\"" "THOR_RESULT UNKNOWN"
test_pattern "Running Thor per-task validation" "Thor message"
test_pattern "FINAL_STATUS.*done.*THOR_RESULT.*PASS" "Thor on success only"
test_pattern "validate-task.*TASK_ID.*PLAN_ID.*thor" "Thor gets PLAN_ID"
test_pattern "Thor validation: PASSED" "Thor pass message"
test_pattern "Thor validation: FAILED" "Thor fail message"
test_pattern "log_delegation" "log_delegation exists"
test_pattern "THOR_RESULT.*0.*unknown" "THOR_RESULT logged"

# Test 4: File-Lock Integration
test_pattern "source.*delegate-utils.sh" "delegate-utils sourced"
test_pattern "safe_update_task" "safe_update_task used"
test_count "safe_update_task" 6 "safe_update_task called 6x"
test_pattern "log_delegation" "log_delegation used"

# Test 5: Execution Function
test_pattern "execute_copilot" "execute_copilot function"
test_pattern "timeout.*TIMEOUT.*copilot" "Timeout wraps copilot"
test_pattern "copilot --yolo" "Yolo mode flag"
test_pattern "add-dir.*WT" "Worktree dir passed"
test_pattern "model.*MODEL" "Model passed"
test_pattern " -p.*PROMPT" "Prompt passed"

# Test 6: Error Handling
test_pattern "^set -euo pipefail" "Strict mode"
test_pattern "if.*-z.*TASK_ID" "TASK_ID validation"
test_pattern "if ! command -v copilot" "Copilot check"
test_pattern "GH_TOKEN.*COPILOT_TOKEN" "Auth check"
test_pattern "if.*-z.*STATUS" "Task exists check"
test_pattern "STATUS.*pending.*in_progress" "Status validation"

# Test 7: Output and Logging
test_pattern "parse_worker_result" "Worker result parsing"
test_pattern "TOKENS_USED" "Token tracking"
test_pattern "PROMPT_TOKENS" "Prompt tokens"
test_pattern "DURATION_MS" "Duration in ms"
test_pattern "TOTAL_DURATION" "Total duration"

# Test 8: Stash Handling
test_pattern "git stash push" "Git stash"
test_pattern "STASH_REF" "Stash ref captured"
test_pattern "verify_work_done" "Work verification"
test_pattern "stash=.*STASH_REF" "Stash in note"

# Test 9: Auto-completion
test_pattern "Auto-completed.*worker changed files" "Auto-complete message"
test_pattern "ARTIFACTS_JSON" "Artifacts captured"
test_pattern "OUTPUT_DATA" "Output data created"
test_pattern "output-data.*OUTPUT_DATA" "Output data passed"

# Summary
echo "===================================="
TOTAL=$((PASS + FAIL))
echo "Tests: $TOTAL | Passed: $PASS | Failed: $FAIL"
[[ $FAIL -eq 0 ]] && echo "✓ All tests passed!" && exit 0
echo "✗ Some tests failed!" && exit 1
