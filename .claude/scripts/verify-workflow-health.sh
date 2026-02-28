#!/usr/bin/env bash
set -euo pipefail
# verify-workflow-health.sh — Full verification of Claude Code + Copilot CLI workflow
# Run from any context: Claude Code, Copilot CLI, or terminal
# Usage: verify-workflow-health.sh [--verbose] [--json]
# Version: 1.0.0

VERBOSE=false
JSON_OUTPUT=false
PASS=0
FAIL=0
WARN=0
RESULTS=()

while [[ $# -gt 0 ]]; do
	case "$1" in
	--verbose)
		VERBOSE=true
		shift
		;;
	--json)
		JSON_OUTPUT=true
		shift
		;;
	*) shift ;;
	esac
done

# --- Helpers ---
check() {
	local name="$1" cmd="$2" expected="${3:-0}"
	local result
	result=$(bash -c "$cmd" 2>/dev/null) || true
	local exit_code=$?
	if [[ "$expected" == "0" && $exit_code -eq 0 ]] || [[ "$result" == *"$expected"* ]]; then
		PASS=$((PASS + 1))
		RESULTS+=("PASS|$name")
		$VERBOSE && echo "[PASS] $name"
	else
		FAIL=$((FAIL + 1))
		RESULTS+=("FAIL|$name|got: $result (exit $exit_code)")
		$VERBOSE && echo "[FAIL] $name — got: $result (exit $exit_code)"
	fi
}

check_exit() {
	local name="$1" cmd="$2" expected_exit="$3"
	local actual_exit=0
	bash -c "$cmd" >/dev/null 2>&1 && actual_exit=0 || actual_exit=$?
	if [[ "$actual_exit" -eq "$expected_exit" ]]; then
		PASS=$((PASS + 1))
		RESULTS+=("PASS|$name")
		$VERBOSE && echo "[PASS] $name"
	else
		FAIL=$((FAIL + 1))
		RESULTS+=("FAIL|$name|expected exit $expected_exit, got $actual_exit")
		$VERBOSE && echo "[FAIL] $name — expected exit $expected_exit, got $actual_exit"
	fi
}

check_exists() {
	local name="$1" path="$2"
	if [[ -f "$path" ]] || [[ -L "$path" ]]; then
		PASS=$((PASS + 1))
		RESULTS+=("PASS|$name")
		$VERBOSE && echo "[PASS] $name"
	else
		FAIL=$((FAIL + 1))
		RESULTS+=("FAIL|$name|not found: $path")
		$VERBOSE && echo "[FAIL] $name — not found: $path"
	fi
}

echo "============================================"
echo "  Workflow Health Verification"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

# === 1. CORE SCRIPTS ===
echo "--- 1. Core Scripts ---"
check "plan-db-safe.sh: no --force" "bash -c 'grep -c \"\\\\-\\\\-force\" ~/.claude/scripts/plan-db-safe.sh'" "0"
check "plan-db-safe.sh: uses plan-db-safe-auto" "bash -c 'grep -c plan-db-safe-auto ~/.claude/scripts/plan-db-safe.sh'" ""
check "plan-db-safe.sh: has rollback logic" "bash -c 'grep -c \"in_progress.*validated_at\" ~/.claude/scripts/plan-db-safe.sh'" ""
check "plan-db-validate.sh: accepts plan-db-safe-auto" "bash -c 'grep -c plan-db-safe-auto ~/.claude/scripts/lib/plan-db-validate.sh'" ""
check "plan-db-import.sh: has file cache" "bash -c 'grep -c _build_plan_file_cache ~/.claude/scripts/lib/plan-db-import.sh'" ""
check "plan-db-crud.sh: has cleanup cache" "bash -c 'grep -c _cleanup_plan_file_cache ~/.claude/scripts/lib/plan-db-crud.sh'" ""

# === 2. CLAUDE CODE HOOKS ===
echo ""
echo "--- 2. Claude Code Hooks ---"
check_exists "hook: guard-plan-mode.sh" "$HOME/.claude/hooks/guard-plan-mode.sh"
check_exists "hook: enforce-plan-db-safe.sh" "$HOME/.claude/hooks/enforce-plan-db-safe.sh"
check_exists "hook: enforce-plan-edit.sh" "$HOME/.claude/hooks/enforce-plan-edit.sh"

# Functional tests
check_exit "guard-plan-mode: blocks EnterPlanMode" \
	"bash -c 'echo \"{\\\"tool_name\\\":\\\"EnterPlanMode\\\"}\" | ~/.claude/hooks/guard-plan-mode.sh'" 2
check_exit "guard-plan-mode: allows Edit" \
	"bash -c 'echo \"{\\\"tool_name\\\":\\\"Edit\\\"}\" | ~/.claude/hooks/guard-plan-mode.sh'" 0
check_exit "enforce-plan-db-safe: blocks direct done" \
	"bash -c 'echo \"{\\\"tool_input\\\":{\\\"command\\\":\\\"plan-db.sh update-task 42 done\\\"}}\" | ~/.claude/hooks/enforce-plan-db-safe.sh'" 2
check_exit "enforce-plan-db-safe: allows safe" \
	"bash -c 'echo \"{\\\"tool_input\\\":{\\\"command\\\":\\\"plan-db-safe.sh update-task 42 done x\\\"}}\" | ~/.claude/hooks/enforce-plan-db-safe.sh'" 0
check_exit "enforce-plan-edit: allows when no plan" \
	"bash -c 'echo \"{\\\"tool_input\\\":{\\\"file_path\\\":\\\"/any\\\"}}\" | ~/.claude/hooks/enforce-plan-edit.sh'" 0

# === 3. SETTINGS.JSON ===
echo ""
echo "--- 3. Settings Configuration ---"
check "settings.json: valid JSON" "jq . ~/.claude/settings.json >/dev/null 2>&1 && echo OK" "OK"
check "settings.json: 4 PreToolUse entries" "jq '.hooks.PreToolUse | length' ~/.claude/settings.json" "4"
check "settings.json: EnterPlanMode matcher" "jq -r '.hooks.PreToolUse[] | select(.matcher == \"EnterPlanMode\") | .hooks[0].command' ~/.claude/settings.json" "guard-plan-mode"
check "settings.json: 5 Bash hooks" "jq '.hooks.PreToolUse[] | select(.matcher == \"Bash\") | .hooks | length' ~/.claude/settings.json" "5"
check "settings.json: 2 Edit hooks" "jq '.hooks.PreToolUse[] | select(.matcher == \"Edit|Write|MultiEdit\") | .hooks | length' ~/.claude/settings.json" "2"

# === 4. COPILOT CLI HOOKS ===
echo ""
echo "--- 4. Copilot CLI Hooks ---"
COPILOT_HOOKS=(guard-plan-mode enforce-plan-db-safe enforce-plan-edit warn-bash-antipatterns warn-infra-plan-drift auto-format guard-settings verify-before-claim session-file-lock session-file-unlock enforce-standards enforce-line-limit worktree-guard session-task-recovery session-tokens)
for h in "${COPILOT_HOOKS[@]}"; do
	check_exists "copilot: $h.sh" "$HOME/.copilot/hooks/$h.sh"
done

# Copilot functional tests (use Copilot JSON format)
check "copilot guard-plan-mode: blocks EPM" \
	"bash -c 'echo \"{\\\"toolName\\\":\\\"EnterPlanMode\\\"}\" | ~/.copilot/hooks/guard-plan-mode.sh 2>/dev/null | jq -r .permissionDecision'" "deny"
check "copilot enforce-plan-db-safe: blocks done" \
	"bash -c 'echo \"{\\\"toolName\\\":\\\"bash\\\",\\\"toolArgs\\\":{\\\"command\\\":\\\"plan-db.sh update-task 42 done\\\"}}\" | ~/.copilot/hooks/enforce-plan-db-safe.sh 2>/dev/null | jq -r .permissionDecision'" "deny"

# === 5. HOOKS.JSON ===
echo ""
echo "--- 5. Copilot hooks.json ---"
check "hooks.json: valid JSON" "jq . ~/.claude/copilot-config/hooks.json >/dev/null 2>&1 && echo OK" "OK"
check "hooks.json: 8 preToolUse" "jq '.hooks.preToolUse | length' ~/.claude/copilot-config/hooks.json" "8"
check "hooks.json: 4 postToolUse" "jq '.hooks.postToolUse | length' ~/.claude/copilot-config/hooks.json" "4"
check "hooks.json: 3 sessionEnd" "jq '.hooks.sessionEnd | length' ~/.claude/copilot-config/hooks.json" "3"

# === 6. DOCUMENTATION ===
echo ""
echo "--- 6. Documentation ---"
check_exists "doc: enforcement-hooks.md" "$HOME/.claude/reference/operational/enforcement-hooks.md"
check "CLAUDE.md: references guard-plan-mode" "bash -c 'grep -c guard-plan-mode ~/.claude/CLAUDE.md'" ""

# === 7. TESTS ===
echo ""
echo "--- 7. Test Suite ---"
check_exists "test: test-enforcement-hooks.sh" "$HOME/.claude/tests/test-enforcement-hooks.sh"
if [[ -f "$HOME/.claude/tests/test-enforcement-hooks.sh" ]]; then
	RESULT=$(bash "$HOME/.claude/tests/test-enforcement-hooks.sh" 2>&1 | grep -E "^Results:" | tail -1)
	if echo "$RESULT" | grep -q "0 failed"; then
		PASS=$((PASS + 1))
		RESULTS+=("PASS|enforcement tests: $RESULT")
		$VERBOSE && echo "[PASS] enforcement tests: $RESULT"
	else
		FAIL=$((FAIL + 1))
		RESULTS+=("FAIL|enforcement tests: $RESULT")
		$VERBOSE && echo "[FAIL] enforcement tests: $RESULT"
	fi
fi

# === 8. AUTO-VERSION ===
echo ""
echo "--- 8. Auto-Version ---"
check_exists "script: auto-version.sh" "$HOME/.claude/scripts/auto-version.sh"
check "auto-version: dry run works" "bash -c '~/.claude/scripts/auto-version.sh --dry-run 2>&1 | head -1'" ""

# === SUMMARY ===
TOTAL=$((PASS + FAIL))
echo ""
echo "============================================"
if [[ $FAIL -eq 0 ]]; then
	echo "  RESULT: ALL PASS ($PASS/$TOTAL)"
else
	echo "  RESULT: $FAIL FAILURES ($PASS/$TOTAL passed)"
	echo ""
	echo "  Failed checks:"
	for r in "${RESULTS[@]}"; do
		if [[ "$r" == FAIL* ]]; then
			echo "    - ${r#FAIL|}"
		fi
	done
fi
echo "============================================"

if $JSON_OUTPUT; then
	echo ""
	echo "{"
	echo "  \"total\": $TOTAL,"
	echo "  \"pass\": $PASS,"
	echo "  \"fail\": $FAIL,"
	echo "  \"status\": \"$([ $FAIL -eq 0 ] && echo 'healthy' || echo 'degraded')\","
	echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
	echo "}"
fi

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
