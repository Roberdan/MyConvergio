#!/bin/bash
# test-enforce-plan-edit.sh - Tests for enforce-plan-edit.sh
# Version: 1.0.0
set -uo pipefail

HOOK="$HOME/.claude/hooks/enforce-plan-edit.sh"
PLAN_FILE="$HOME/.claude/data/active-plan-id.txt"
DATA_DIR="$HOME/.claude/data"

PASS=0
FAIL=0

assert_exit() {
	local desc="$1" expected="$2" actual="$3"
	if [ "$actual" -eq "$expected" ]; then
		echo "[PASS] $desc"
		PASS=$((PASS + 1))
	else
		echo "[FAIL] $desc (expected exit $expected, got $actual)"
		FAIL=$((FAIL + 1))
	fi
}

# Backup original active-plan-id.txt
ORIG_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null || true)

cleanup() {
	# Restore original
	echo "$ORIG_CONTENT" >"$PLAN_FILE" 2>/dev/null || true
	rm -f "$DATA_DIR/plan-9999-files.txt"
}
trap cleanup EXIT

# T1: No active plan (empty file) -> exit 0
echo "" >"$PLAN_FILE"
echo '{"tool_input":{"file_path":"/any/file.txt"}}' | "$HOOK"
assert_exit "T1: Empty active-plan-id.txt -> allow" 0 $?

# T2: No plan file (remove it) -> exit 0
rm -f "$PLAN_FILE"
echo '{"tool_input":{"file_path":"/any/file.txt"}}' | "$HOOK"
assert_exit "T2: Missing active-plan-id.txt -> allow" 0 $?
# Recreate
touch "$PLAN_FILE"

# T3: Plan active, no files cache -> exit 0
echo "9999" >"$PLAN_FILE"
rm -f "$DATA_DIR/plan-9999-files.txt"
echo '{"tool_input":{"file_path":"/any/file.txt"}}' | "$HOOK"
assert_exit "T3: Plan active, no files cache -> allow" 0 $?

# T4: Plan active, file NOT in cache -> exit 0
echo "9999" >"$PLAN_FILE"
echo "/some/other/file.txt" >"$DATA_DIR/plan-9999-files.txt"
echo '{"tool_input":{"file_path":"/any/file.txt"}}' | "$HOOK"
assert_exit "T4: File not tracked -> allow" 0 $?

# T5: Plan active, file IN cache, running as task-executor -> exit 0
echo "9999" >"$PLAN_FILE"
echo "/tracked/file.txt" >"$DATA_DIR/plan-9999-files.txt"
CLAUDE_TASK_EXECUTOR=1 bash -c "echo '{\"tool_input\":{\"file_path\":\"/tracked/file.txt\"}}' | '$HOOK'"
assert_exit "T5: Tracked file + CLAUDE_TASK_EXECUTOR=1 -> allow" 0 $?

# T6: Plan active, file IN cache, NOT task-executor -> exit 2
echo "9999" >"$PLAN_FILE"
echo "/tracked/file.txt" >"$DATA_DIR/plan-9999-files.txt"
unset CLAUDE_TASK_EXECUTOR 2>/dev/null || true
echo '{"tool_input":{"file_path":"/tracked/file.txt"}}' | "$HOOK" 2>/dev/null
assert_exit "T6: Tracked file, no executor env -> block (exit 2)" 2 $?

# T7: ~/- expansion works
echo "9999" >"$PLAN_FILE"
echo "$HOME/.claude/test-file.txt" >"$DATA_DIR/plan-9999-files.txt"
echo '{"tool_input":{"file_path":"~/.claude/test-file.txt"}}' | "$HOOK" 2>/dev/null
assert_exit "T7: ~/. path expansion -> block (exit 2)" 2 $?

# T8: Empty tool_input.file_path -> exit 0
echo "9999" >"$PLAN_FILE"
echo '{"tool_input":{"file_path":""}}' | "$HOOK"
assert_exit "T8: Empty file_path -> allow" 0 $?

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
