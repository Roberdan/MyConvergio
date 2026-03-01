#!/usr/bin/env bash
# tests/test-mesh-env.sh — Syntax and structure tests for scripts/mesh-env-setup.sh
# Plan 297 / TF-tests | F-closure
# Tests: bash -n syntax, --check flag, required features, no hardcoded paths
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/test-helpers.sh"

SCRIPT="$REPO_ROOT/scripts/mesh-env-setup.sh"
LIB="$REPO_ROOT/scripts/lib/mesh-env-tools.sh"

echo "=== test-mesh-env.sh: mesh-env-setup.sh syntax and structure tests ==="
echo ""

# --- T1: mesh-env-setup.sh exists ---
assert_file_exists "$SCRIPT" "T1: mesh-env-setup.sh exists"

# --- T2: bash -n syntax check passes ---
assert_bash_syntax "$SCRIPT" "T2: mesh-env-setup.sh bash -n passes"

# --- T3: mesh-env-tools.sh (lib) exists ---
assert_file_exists "$LIB" "T3: scripts/lib/mesh-env-tools.sh exists"

# --- T4: mesh-env-tools.sh bash -n passes ---
assert_bash_syntax "$LIB" "T4: mesh-env-tools.sh bash -n passes"

# --- T5: mesh-env-setup.sh is executable ---
assert_executable "$SCRIPT" "T5: mesh-env-setup.sh is executable"

# --- T6: shebang is #!/usr/bin/env bash ---
TESTS_RUN=$((TESTS_RUN + 1))
FIRST_LINE="$(sed -n '1p' "$SCRIPT")"
if [[ "$FIRST_LINE" == "#!/usr/bin/env bash" ]]; then
	pass "T6: shebang is #!/usr/bin/env bash"
else
	fail "T6: shebang check" "#!/usr/bin/env bash" "$FIRST_LINE"
fi

# --- T7: set -euo pipefail present ---
assert_grep "set -euo pipefail" "$SCRIPT" "T7: set -euo pipefail present in mesh-env-setup.sh"
assert_grep "set -euo pipefail" "$LIB" "T7b: set -euo pipefail present in mesh-env-tools.sh"

# --- T8: --check flag handled ---
assert_grep '\-\-check' "$SCRIPT" "T8: --check flag present in mesh-env-setup.sh"

# --- T9: --tools-only flag handled ---
assert_grep '\-\-tools-only' "$SCRIPT" "T9: --tools-only flag present"

# --- T10: --hooks-only flag handled ---
assert_grep '\-\-hooks-only' "$SCRIPT" "T10: --hooks-only flag present"

# --- T11: --full flag handled ---
assert_grep '\-\-full' "$SCRIPT" "T11: --full flag present"

# --- T12: sources mesh-env-tools.sh ---
assert_grep "mesh-env-tools.sh" "$SCRIPT" "T12: sources scripts/lib/mesh-env-tools.sh"

# --- T13: CLAUDE_HOME variable used (no hardcoded paths) ---
assert_grep "CLAUDE_HOME" "$SCRIPT" "T13: uses CLAUDE_HOME variable"
assert_grep "CLAUDE_HOME" "$LIB" "T13b: mesh-env-tools.sh uses CLAUDE_HOME"

# --- T14: No hardcoded home paths ---
_HP="/""Users""/[a-z]|/""home""/[a-z]"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE "$_HP" "$SCRIPT"; then
	MATCH=$(grep -E "$_HP" "$SCRIPT" | tr -d '\n')
	fail "T14: hardcoded home path in mesh-env-setup.sh (C-07)" "no hardcoded paths" "$MATCH"
else
	pass "T14: no hardcoded home paths in mesh-env-setup.sh"
fi

TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE "$_HP" "$LIB"; then
	MATCH=$(grep -E "$_HP" "$LIB" | tr -d '\n')
	fail "T14b: hardcoded home path in mesh-env-tools.sh (C-07)" "no hardcoded paths" "$MATCH"
else
	pass "T14b: no hardcoded home paths in mesh-env-tools.sh"
fi

# --- T15: No personal hostnames hardcoded ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'roberdan|omarchy|mariodan' "$SCRIPT"; then
	MATCH=$(grep -E 'roberdan|omarchy|mariodan' "$SCRIPT" | tr -d '\n')
	fail "T15: personal hostnames hardcoded in mesh-env-setup.sh (C-07 violation)" "none" "$MATCH"
else
	pass "T15: no personal hostnames in mesh-env-setup.sh"
fi

# --- T16: print_check_table function in mesh-env-tools.sh ---
assert_grep "print_check_table" "$LIB" "T16: print_check_table function in mesh-env-tools.sh"

# --- T17: install_tools function in mesh-env-tools.sh ---
assert_grep "install_tools" "$LIB" "T17: install_tools function in mesh-env-tools.sh"

# --- T18: detect_os function in mesh-env-tools.sh ---
assert_grep "detect_os" "$LIB" "T18: detect_os function in mesh-env-tools.sh"

# --- T19: --check mode runs print_check_table (check function call in dispatch) ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'check\)' "$SCRIPT" && grep -q 'print_check_table' "$SCRIPT"; then
	pass "T19: --check mode calls print_check_table"
else
	fail "T19: --check mode should call print_check_table"
fi

# --- T20: Under 250 lines ---
assert_line_count "$SCRIPT" 250 "T20: mesh-env-setup.sh under 250 lines"
assert_line_count "$LIB" 250 "T20b: mesh-env-tools.sh under 250 lines"

# --- T21: --check exits 0 (no side effects, just table output) ---
TESTS_RUN=$((TESTS_RUN + 1))
CHECK_OUT=$(bash "$SCRIPT" --check 2>&1 || true)
CHECK_RC=0
bash "$SCRIPT" --check >/dev/null 2>&1 || CHECK_RC=$?
if [[ "$CHECK_RC" -eq 0 ]]; then
	pass "T21: --check exits 0"
else
	fail "T21: --check should exit 0" "0" "$CHECK_RC"
fi

# --- T22: --check output contains TOOL header ---
TESTS_RUN=$((TESTS_RUN + 1))
if echo "$CHECK_OUT" | grep -qi 'TOOL\|STATUS\|installed\|MISSING'; then
	pass "T22: --check output shows tool status table"
else
	fail "T22: --check should show tool table" "TOOL/STATUS columns" "$CHECK_OUT"
fi

# --- T23: --help exits 0 ---
TESTS_RUN=$((TESTS_RUN + 1))
HELP_RC=0
bash "$SCRIPT" --help >/dev/null 2>&1 || HELP_RC=$?
if [[ "$HELP_RC" -eq 0 ]]; then
	pass "T23: --help exits 0"
else
	fail "T23: --help should exit 0" "0" "$HELP_RC"
fi

# --- T24: SCRIPT_DIR pattern used (portable paths) ---
assert_grep 'SCRIPT_DIR' "$SCRIPT" "T24: SCRIPT_DIR pattern used for portable paths"

echo ""
print_test_summary "test-mesh-env.sh"
