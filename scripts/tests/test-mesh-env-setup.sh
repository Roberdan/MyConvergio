#!/bin/bash
# test-mesh-env-setup.sh — Tests for mesh-env-setup.sh and lib/mesh-env-tools.sh
# Version: 1.0.0
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MESH_SETUP="$SCRIPT_DIR/mesh-env-setup.sh"
MESH_TOOLS="$SCRIPT_DIR/lib/mesh-env-tools.sh"
PASS=0
FAIL=0
TOTAL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
	PASS=$((PASS + 1))
	TOTAL=$((TOTAL + 1))
	echo -e "  ${GREEN}PASS${NC} $1"
}
fail() {
	FAIL=$((FAIL + 1))
	TOTAL=$((TOTAL + 1))
	echo -e "  ${RED}FAIL${NC} $1: $2"
}
section() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }

section "File existence"
[[ -f "$MESH_SETUP" ]] && pass "mesh-env-setup.sh exists" || fail "mesh-env-setup.sh exists" "file not found"
[[ -f "$MESH_TOOLS" ]] && pass "lib/mesh-env-tools.sh exists" || fail "lib/mesh-env-tools.sh exists" "file not found"
[[ -x "$MESH_SETUP" ]] && pass "mesh-env-setup.sh is executable" || fail "mesh-env-setup.sh is executable" "not executable"
[[ -x "$MESH_TOOLS" ]] && pass "lib/mesh-env-tools.sh is executable" || fail "lib/mesh-env-tools.sh is executable" "not executable"

section "Syntax check"
bash -n "$MESH_SETUP" 2>/dev/null && pass "mesh-env-setup.sh syntax valid" || fail "mesh-env-setup.sh syntax valid" "syntax error"
bash -n "$MESH_TOOLS" 2>/dev/null && pass "lib/mesh-env-tools.sh syntax valid" || fail "lib/mesh-env-tools.sh syntax valid" "syntax error"

section "Line count (max 250)"
setup_lines=$(wc -l <"$MESH_SETUP" 2>/dev/null || echo 9999)
tools_lines=$(wc -l <"$MESH_TOOLS" 2>/dev/null || echo 9999)
[[ "$setup_lines" -le 250 ]] && pass "mesh-env-setup.sh <= 250 lines ($setup_lines)" || fail "mesh-env-setup.sh <= 250 lines" "$setup_lines lines"
[[ "$tools_lines" -le 250 ]] && pass "lib/mesh-env-tools.sh <= 250 lines ($tools_lines)" || fail "lib/mesh-env-tools.sh <= 250 lines" "$tools_lines lines"

section "Flag presence in source"
grep -q -- '--check' "$MESH_SETUP" 2>/dev/null && pass "--check flag present" || fail "--check flag present" "not found in source"
grep -q -- '--tools-only' "$MESH_SETUP" 2>/dev/null && pass "--tools-only flag present" || fail "--tools-only flag present" "not found"
grep -q -- '--hooks-only' "$MESH_SETUP" 2>/dev/null && pass "--hooks-only flag present" || fail "--hooks-only flag present" "not found"
grep -q -- '--full' "$MESH_SETUP" 2>/dev/null && pass "--full flag present" || fail "--full flag present" "not found"

section "No hardcoded paths"
grep -qP '/Users/\w+' "$MESH_SETUP" 2>/dev/null && fail "no hardcoded user paths in setup" "found /Users/..." || pass "no hardcoded user paths in setup"
grep -qP '/Users/\w+' "$MESH_TOOLS" 2>/dev/null && fail "no hardcoded user paths in tools" "found /Users/..." || pass "no hardcoded user paths in tools"

section "\$CLAUDE_HOME usage"
grep -q 'CLAUDE_HOME' "$MESH_SETUP" 2>/dev/null && pass "CLAUDE_HOME referenced in setup" || fail "CLAUDE_HOME referenced in setup" "not found"
grep -q 'CLAUDE_HOME' "$MESH_TOOLS" 2>/dev/null && pass "CLAUDE_HOME referenced in tools" || fail "CLAUDE_HOME referenced in tools" "not found"

section "set -euo pipefail"
grep -q 'set -euo pipefail' "$MESH_SETUP" 2>/dev/null && pass "set -euo pipefail in setup" || fail "set -euo pipefail in setup" "not found"
grep -q 'set -euo pipefail' "$MESH_TOOLS" 2>/dev/null && pass "set -euo pipefail in tools" || fail "set -euo pipefail in tools" "not found"

section "--check flag functional"
if [[ -f "$MESH_SETUP" ]]; then
	check_out=$(bash "$MESH_SETUP" --check 2>&1)
	check_exit=$?
	[[ $check_exit -eq 0 ]] && pass "--check exits 0" || fail "--check exits 0" "exited $check_exit"
	echo "$check_out" | grep -q 'bat\|eza\|rg\|jq\|sqlite3\|git' && pass "--check output mentions tools" || fail "--check output mentions tools" "output: $check_out"
fi

section "OS detection in tools"
grep -qiE 'brew|apt|linux|darwin|macOS' "$MESH_TOOLS" 2>/dev/null && pass "OS detection in tools" || fail "OS detection in tools" "not found"

# Summary
echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo -e "${GREEN}ALL PASS${NC}" && exit 0 || {
	echo -e "${RED}FAILURES: $FAIL${NC}"
	exit 1
}
