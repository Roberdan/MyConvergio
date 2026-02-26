#!/bin/bash
# test-enforcement-hooks.sh — Unit tests for workflow enforcement hooks
# Version: 1.0.0
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"
COPILOT_HOOKS_DIR="$SCRIPT_DIR/copilot-config/hooks"
DATA_DIR="$SCRIPT_DIR/data"

PASS=0
FAIL=0
TOTAL=0

# ============================================================================
# Test framework
# ============================================================================

pass() {
	PASS=$((PASS + 1))
	TOTAL=$((TOTAL + 1))
	echo "[PASS] $1"
}

fail() {
	FAIL=$((FAIL + 1))
	TOTAL=$((TOTAL + 1))
	echo "[FAIL] $1"
	if [ -n "${2:-}" ]; then
		echo "       Expected: $2"
	fi
	if [ -n "${3:-}" ]; then
		echo "       Got:      $3"
	fi
}

assert_exit() {
	local desc="$1"
	local expected="$2"
	local actual="$3"
	if [ "$actual" -eq "$expected" ]; then
		pass "$desc"
	else
		fail "$desc" "exit $expected" "exit $actual"
	fi
}

assert_output_contains() {
	local desc="$1"
	local pattern="$2"
	local output="$3"
	if echo "$output" | grep -q "$pattern"; then
		pass "$desc"
	else
		fail "$desc" "output containing '$pattern'" "'$output'"
	fi
}

assert_output_not_contains() {
	local desc="$1"
	local pattern="$2"
	local output="$3"
	if echo "$output" | grep -q "$pattern"; then
		fail "$desc" "output NOT containing '$pattern'" "'$output'"
	else
		pass "$desc"
	fi
}

# ============================================================================
# Temp state management
# ============================================================================

ORIG_PLAN_FILE_CONTENT=""
PLAN_FILE="$DATA_DIR/active-plan-id.txt"
TEST_PLAN_ID="99997"
FILES_CACHE="$DATA_DIR/plan-${TEST_PLAN_ID}-files.txt"

setup_plan_state() {
	# Backup original
	ORIG_PLAN_FILE_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null || true)
}

restore_plan_state() {
	if [ -n "$ORIG_PLAN_FILE_CONTENT" ]; then
		echo "$ORIG_PLAN_FILE_CONTENT" >"$PLAN_FILE" 2>/dev/null || true
	else
		rm -f "$PLAN_FILE"
	fi
	rm -f "$FILES_CACHE"
}

# ============================================================================
# Section 1: hooks/guard-plan-mode.sh (Claude Code — exit 0/2)
# ============================================================================

section_guard_plan_mode_claude() {
	local hook="$HOOKS_DIR/guard-plan-mode.sh"
	echo ""
	echo "=== 1. guard-plan-mode.sh (Claude Code) ==="

	# EnterPlanMode -> exit 2
	local exit_code=0
	echo '{"tool_name":"EnterPlanMode","tool_input":{}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "EnterPlanMode -> exit 2 (blocked)" 2 "$exit_code"

	# Edit tool -> exit 0
	exit_code=0
	echo '{"tool_name":"Edit","tool_input":{"file_path":"/some/file.ts"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "Edit tool -> exit 0 (allowed)" 0 "$exit_code"

	# Bash tool -> exit 0
	exit_code=0
	echo '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "Bash tool -> exit 0 (allowed)" 0 "$exit_code"

	# Empty input -> exit 0
	exit_code=0
	echo '' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "Empty input -> exit 0 (allowed)" 0 "$exit_code"

	# tool_name missing -> exit 0
	exit_code=0
	echo '{}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "No tool_name -> exit 0 (allowed)" 0 "$exit_code"
}

# ============================================================================
# Section 2: hooks/enforce-plan-db-safe.sh (Claude Code — exit 0/2)
# ============================================================================

section_enforce_plan_db_safe_claude() {
	local hook="$HOOKS_DIR/enforce-plan-db-safe.sh"
	echo ""
	echo "=== 2. enforce-plan-db-safe.sh (Claude Code) ==="

	# plan-db.sh update-task 42 done -> exit 2
	local exit_code=0
	echo '{"tool_input":{"command":"plan-db.sh update-task 42 done"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "plan-db.sh update-task 42 done -> exit 2 (blocked)" 2 "$exit_code"

	# plan-db-safe.sh update-task 42 done notes -> exit 0
	exit_code=0
	echo '{"tool_input":{"command":"plan-db-safe.sh update-task 42 done notes"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "plan-db-safe.sh update-task 42 done -> exit 0 (allowed)" 0 "$exit_code"

	# plan-db.sh status -> exit 0 (not an update-task done)
	exit_code=0
	echo '{"tool_input":{"command":"plan-db.sh status"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "plan-db.sh status -> exit 0 (allowed)" 0 "$exit_code"

	# plan-db.sh update-task 42 in_progress -> exit 0
	exit_code=0
	echo '{"tool_input":{"command":"plan-db.sh update-task 42 in_progress"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "plan-db.sh update-task 42 in_progress -> exit 0 (allowed)" 0 "$exit_code"

	# plan-db.sh update-task 100 done "with notes" -> exit 2
	exit_code=0
	echo '{"tool_input":{"command":"plan-db.sh update-task 100 done \"with notes\""}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "plan-db.sh update-task 100 done with notes -> exit 2 (blocked)" 2 "$exit_code"

	# Empty command -> exit 0
	exit_code=0
	echo '{"tool_input":{"command":""}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "Empty command -> exit 0 (allowed)" 0 "$exit_code"

	# No tool_input -> exit 0
	exit_code=0
	echo '{}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "No tool_input -> exit 0 (allowed)" 0 "$exit_code"
}

# ============================================================================
# Section 3: hooks/enforce-plan-edit.sh (Claude Code — exit 0/2)
# ============================================================================

section_enforce_plan_edit_claude() {
	local hook="$HOOKS_DIR/enforce-plan-edit.sh"
	echo ""
	echo "=== 3. enforce-plan-edit.sh (Claude Code) ==="

	setup_plan_state

	# No active-plan-id.txt -> exit 0
	rm -f "$PLAN_FILE"
	local exit_code=0
	echo '{"tool_input":{"file_path":"/any/file.ts"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "No active-plan-id.txt -> exit 0 (allowed)" 0 "$exit_code"

	# Active plan, no files cache -> exit 0
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	rm -f "$FILES_CACHE"
	exit_code=0
	echo '{"tool_input":{"file_path":"/any/file.ts"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "Plan active, no files cache -> exit 0 (allowed)" 0 "$exit_code"

	# Active plan, untracked file -> exit 0
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	echo "/some/other/file.ts" >"$FILES_CACHE"
	exit_code=0
	echo '{"tool_input":{"file_path":"/some/unrelated/file.ts"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "Untracked file -> exit 0 (allowed)" 0 "$exit_code"

	# Active plan, tracked file, no CLAUDE_TASK_EXECUTOR -> exit 2
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	echo "/tracked/file.ts" >"$FILES_CACHE"
	unset CLAUDE_TASK_EXECUTOR 2>/dev/null || true
	exit_code=0
	echo '{"tool_input":{"file_path":"/tracked/file.ts"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "Tracked file without CLAUDE_TASK_EXECUTOR -> exit 2 (blocked)" 2 "$exit_code"

	# Active plan, tracked file, WITH CLAUDE_TASK_EXECUTOR=1 -> exit 0
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	echo "/tracked/file.ts" >"$FILES_CACHE"
	exit_code=0
	CLAUDE_TASK_EXECUTOR=1 bash -c "echo '{\"tool_input\":{\"file_path\":\"/tracked/file.ts\"}}' | '$hook'" 2>/dev/null
	exit_code=$?
	assert_exit "Tracked file WITH CLAUDE_TASK_EXECUTOR=1 -> exit 0 (allowed)" 0 "$exit_code"

	# Active plan, empty plan_id in file -> exit 0
	echo "" >"$PLAN_FILE"
	exit_code=0
	echo '{"tool_input":{"file_path":"/tracked/file.ts"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "Empty plan_id in file -> exit 0 (allowed)" 0 "$exit_code"

	# Active plan, tracked file via ~/ path -> exit 2
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	echo "${HOME}/.claude/some-config.sh" >"$FILES_CACHE"
	unset CLAUDE_TASK_EXECUTOR 2>/dev/null || true
	exit_code=0
	echo '{"tool_input":{"file_path":"~/.claude/some-config.sh"}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "Tracked file via ~/ path expansion -> exit 2 (blocked)" 2 "$exit_code"

	# No file_path in input -> exit 0
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	echo "/tracked/file.ts" >"$FILES_CACHE"
	exit_code=0
	echo '{"tool_input":{}}' | "$hook" 2>/dev/null
	exit_code=$?
	assert_exit "No file_path in input -> exit 0 (allowed)" 0 "$exit_code"

	restore_plan_state
}

# ============================================================================
# Section 4: plan-db-safe.sh static checks
# ============================================================================

section_plan_db_safe_static() {
	local script="$SCRIPT_DIR/scripts/plan-db-safe.sh"
	echo ""
	echo "=== 4. plan-db-safe.sh static checks ==="

	# No --force flag anywhere
	if grep -q "\-\-force" "$script" 2>/dev/null; then
		fail "No --force flag in plan-db-safe.sh" "no match" "found --force"
	else
		pass "No --force flag in plan-db-safe.sh"
	fi

	# plan-db-safe-auto string exists (used as caller identifier)
	if grep -q "plan-db-safe-auto" "$script" 2>/dev/null; then
		pass "plan-db-safe-auto string present in script"
	else
		fail "plan-db-safe-auto string present in script" "found" "not found"
	fi

	# Script has shebang
	if head -1 "$script" | grep -q "^#!/"; then
		pass "plan-db-safe.sh has shebang line"
	else
		fail "plan-db-safe.sh has shebang line" "#!/..." "missing"
	fi

	# Script is executable
	if [ -x "$script" ]; then
		pass "plan-db-safe.sh is executable"
	else
		fail "plan-db-safe.sh is executable" "executable" "not executable"
	fi
}

# ============================================================================
# Section 5: Copilot guard-plan-mode.sh (permissionDecision protocol)
# ============================================================================

section_guard_plan_mode_copilot() {
	local hook="$COPILOT_HOOKS_DIR/guard-plan-mode.sh"
	echo ""
	echo "=== 5. guard-plan-mode.sh (Copilot — permissionDecision) ==="

	# EnterPlanMode -> output contains "deny", exit 0
	local output=""
	local exit_code=0
	output=$(echo '{"toolName":"EnterPlanMode","toolArgs":{}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "EnterPlanMode -> exit 0 (Copilot deny protocol)" 0 "$exit_code"
	assert_output_contains "EnterPlanMode -> output contains 'deny'" "deny" "$output"

	# Edit tool -> exit 0, no deny output
	output=""
	exit_code=0
	output=$(echo '{"toolName":"edit","toolArgs":{"file_path":"/some/file.ts"}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "Edit tool -> exit 0 (allowed)" 0 "$exit_code"
	assert_output_not_contains "Edit tool -> no deny output" "deny" "$output"

	# Bash tool -> exit 0, no deny
	output=""
	exit_code=0
	output=$(echo '{"toolName":"bash","toolArgs":{"command":"echo hi"}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "Bash tool -> exit 0 (allowed)" 0 "$exit_code"
	assert_output_not_contains "Bash tool -> no deny output" "deny" "$output"

	# Valid JSON output when blocked
	output=""
	output=$(echo '{"toolName":"EnterPlanMode","toolArgs":{}}' | "$hook" 2>/dev/null)
	if echo "$output" | jq -e '.permissionDecision == "deny"' >/dev/null 2>&1; then
		pass "EnterPlanMode -> valid JSON with permissionDecision=deny"
	else
		fail "EnterPlanMode -> valid JSON with permissionDecision=deny" '{"permissionDecision":"deny",...}' "$output"
	fi
}

# ============================================================================
# Section 6: Copilot enforce-plan-db-safe.sh (permissionDecision protocol)
# ============================================================================

section_enforce_plan_db_safe_copilot() {
	local hook="$COPILOT_HOOKS_DIR/enforce-plan-db-safe.sh"
	echo ""
	echo "=== 6. enforce-plan-db-safe.sh (Copilot — permissionDecision) ==="

	# bash tool + direct plan-db.sh done -> output contains "deny", exit 0
	local output=""
	local exit_code=0
	output=$(echo '{"toolName":"bash","toolArgs":{"command":"plan-db.sh update-task 42 done"}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "Direct plan-db.sh done (bash) -> exit 0 (Copilot deny protocol)" 0 "$exit_code"
	assert_output_contains "Direct plan-db.sh done -> output contains 'deny'" "deny" "$output"

	# plan-db-safe.sh -> no deny, exit 0
	output=""
	exit_code=0
	output=$(echo '{"toolName":"bash","toolArgs":{"command":"plan-db-safe.sh update-task 42 done notes"}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "plan-db-safe.sh (bash) -> exit 0 (allowed)" 0 "$exit_code"
	assert_output_not_contains "plan-db-safe.sh -> no deny output" "deny" "$output"

	# Non-bash tool (Edit) -> no deny, exit 0
	output=""
	exit_code=0
	output=$(echo '{"toolName":"edit","toolArgs":{"file_path":"/some/file.ts"}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "Non-bash tool -> exit 0 (pass-through)" 0 "$exit_code"
	assert_output_not_contains "Non-bash tool -> no deny output" "deny" "$output"

	# plan-db.sh status (bash) -> no deny, exit 0
	output=""
	exit_code=0
	output=$(echo '{"toolName":"bash","toolArgs":{"command":"plan-db.sh status"}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "plan-db.sh status (bash) -> exit 0 (allowed)" 0 "$exit_code"
	assert_output_not_contains "plan-db.sh status -> no deny" "deny" "$output"

	# Valid JSON output when blocked
	output=$(echo '{"toolName":"bash","toolArgs":{"command":"plan-db.sh update-task 10 done"}}' | "$hook" 2>/dev/null)
	if echo "$output" | jq -e '.permissionDecision == "deny"' >/dev/null 2>&1; then
		pass "Blocked command -> valid JSON with permissionDecision=deny"
	else
		fail "Blocked command -> valid JSON with permissionDecision=deny" '{"permissionDecision":"deny",...}' "$output"
	fi
}

# ============================================================================
# Section 7: Copilot enforce-plan-edit.sh (permissionDecision protocol)
# ============================================================================

section_enforce_plan_edit_copilot() {
	local hook="$COPILOT_HOOKS_DIR/enforce-plan-edit.sh"
	echo ""
	echo "=== 7. enforce-plan-edit.sh (Copilot — permissionDecision) ==="

	setup_plan_state

	# No active plan -> no deny, exit 0
	rm -f "$PLAN_FILE"
	local output=""
	local exit_code=0
	output=$(echo '{"toolName":"edit","toolArgs":{"file_path":"/any/file.ts"}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "No active plan -> exit 0 (allowed)" 0 "$exit_code"
	assert_output_not_contains "No active plan -> no deny output" "deny" "$output"

	# Non-edit tool -> no deny, exit 0
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	echo "/tracked/file.ts" >"$FILES_CACHE"
	output=""
	exit_code=0
	output=$(echo '{"toolName":"bash","toolArgs":{"command":"echo hi"}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "Non-edit tool -> exit 0 (pass-through)" 0 "$exit_code"
	assert_output_not_contains "Non-edit tool -> no deny output" "deny" "$output"

	# Active plan, tracked file, no executor -> deny, exit 0
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	echo "/tracked/file.ts" >"$FILES_CACHE"
	unset CLAUDE_TASK_EXECUTOR 2>/dev/null || true
	output=""
	exit_code=0
	output=$(echo '{"toolName":"edit","toolArgs":{"file_path":"/tracked/file.ts"}}' | "$hook" 2>/dev/null)
	exit_code=$?
	assert_exit "Tracked file, no executor (Copilot) -> exit 0 (deny protocol)" 0 "$exit_code"
	assert_output_contains "Tracked file, no executor -> output contains 'deny'" "deny" "$output"

	# Active plan, tracked file, WITH executor -> no deny, exit 0
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	echo "/tracked/file.ts" >"$FILES_CACHE"
	output=""
	exit_code=0
	output=$(CLAUDE_TASK_EXECUTOR=1 bash -c "echo '{\"toolName\":\"edit\",\"toolArgs\":{\"file_path\":\"/tracked/file.ts\"}}' | '$hook'" 2>/dev/null)
	exit_code=$?
	assert_exit "Tracked file WITH executor (Copilot) -> exit 0 (allowed)" 0 "$exit_code"
	assert_output_not_contains "Tracked file WITH executor -> no deny" "deny" "$output"

	# Valid JSON output when blocked
	echo "$TEST_PLAN_ID" >"$PLAN_FILE"
	echo "/tracked/file.ts" >"$FILES_CACHE"
	unset CLAUDE_TASK_EXECUTOR 2>/dev/null || true
	output=$(echo '{"toolName":"write","toolArgs":{"file_path":"/tracked/file.ts"}}' | "$hook" 2>/dev/null)
	if echo "$output" | jq -e '.permissionDecision == "deny"' >/dev/null 2>&1; then
		pass "Tracked file write -> valid JSON with permissionDecision=deny"
	else
		fail "Tracked file write -> valid JSON with permissionDecision=deny" '{"permissionDecision":"deny",...}' "$output"
	fi

	restore_plan_state
}

# ============================================================================
# Main
# ============================================================================

echo "test-enforcement-hooks.sh — Enforcement Hook Unit Tests"
echo "======================================================="

section_guard_plan_mode_claude
section_enforce_plan_db_safe_claude
section_enforce_plan_edit_claude
section_plan_db_safe_static
section_guard_plan_mode_copilot
section_enforce_plan_db_safe_copilot
section_enforce_plan_edit_copilot

echo ""
echo "======================================================="
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "======================================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
