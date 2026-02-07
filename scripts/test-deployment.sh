#!/bin/bash

# =============================================================================
# MYCONVERGIO DEPLOYMENT TEST SCRIPT
# =============================================================================
# Tests the agent deployment and validation
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$ROOT_DIR/.claude/agents"
TEST_DIR="/tmp/myconvergio-test-$$"

# Counters
PASSED=0
FAILED=0

# Cleanup on exit
cleanup() {
	rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo -e "${BLUE}MyConvergio Deployment Tests${NC}"
echo "======================================"
echo ""

# Function to run a test
run_test() {
	local test_name="$1"
	local test_cmd="$2"
	local expected="${3:-0}"

	echo -n "Testing: $test_name... "

	set +e
	eval "$test_cmd" >/dev/null 2>&1
	local result=$?
	set -e

	if [ "$result" -eq "$expected" ]; then
		echo -e "${GREEN}PASS${NC}"
		PASSED=$((PASSED + 1))
		return 0
	else
		echo -e "${RED}FAIL${NC}"
		FAILED=$((FAILED + 1))
		return 1
	fi
}

# =============================================================================
# TEST 1: Directory structure
# =============================================================================
echo -e "${BLUE}Test Suite: Directory Structure${NC}"

run_test "Agents directory exists" "[ -d '$AGENTS_DIR' ]"
run_test "Rules directory exists" "[ -d '$ROOT_DIR/.claude/rules' ]"
run_test "Skills directory exists" "[ -d '$ROOT_DIR/.claude/skills' ]"
run_test "Makefile exists" "[ -f '$ROOT_DIR/Makefile' ]"
run_test "VERSION file exists" "[ -f '$ROOT_DIR/VERSION' ]"

echo ""

# =============================================================================
# TEST 2: Agent file validation
# =============================================================================
echo -e "${BLUE}Test Suite: Agent Files${NC}"

# Count agents
AGENT_COUNT=$(/usr/bin/find "$AGENTS_DIR" -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' ! -name 'SECURITY_FRAMEWORK_TEMPLATE.md' ! -name 'MICROSOFT_VALUES.md' 2>/dev/null | /usr/bin/wc -l | tr -d ' ')
run_test "At least 50 agents exist ($AGENT_COUNT found)" "[ '$AGENT_COUNT' -ge 50 ]"

# Check YAML frontmatter
YAML_ERRORS=0
for file in $(/usr/bin/find "$AGENTS_DIR" -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' ! -name 'SECURITY_FRAMEWORK_TEMPLATE.md' ! -name 'MICROSOFT_VALUES.md'); do
	if ! head -1 "$file" | grep -q '^---$'; then
		YAML_ERRORS=$((YAML_ERRORS + 1))
	fi
done
run_test "All agents have YAML frontmatter ($YAML_ERRORS errors)" "[ '$YAML_ERRORS' -eq 0 ]"

# Check for required fields
MISSING_NAME=0
MISSING_DESC=0
for file in $(/usr/bin/find "$AGENTS_DIR" -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' ! -name 'SECURITY_FRAMEWORK_TEMPLATE.md' ! -name 'MICROSOFT_VALUES.md'); do
	if ! grep -q '^name:' "$file"; then
		MISSING_NAME=$((MISSING_NAME + 1))
	fi
	if ! grep -q '^description:' "$file"; then
		MISSING_DESC=$((MISSING_DESC + 1))
	fi
done
run_test "All agents have 'name' field ($MISSING_NAME missing)" "[ '$MISSING_NAME' -eq 0 ]"
run_test "All agents have 'description' field ($MISSING_DESC missing)" "[ '$MISSING_DESC' -eq 0 ]"

echo ""

# =============================================================================
# TEST 3: Constitution compliance
# =============================================================================
echo -e "${BLUE}Test Suite: Constitution Compliance${NC}"

CONSTITUTION="$AGENTS_DIR/core_utility/CONSTITUTION.md"
run_test "CONSTITUTION.md exists" "[ -f '$CONSTITUTION' ]"

if [ -f "$CONSTITUTION" ]; then
	run_test "Constitution has Article I (Identity)" "grep -q 'Article I' '$CONSTITUTION'"
	run_test "Constitution has Article VII (Accessibility)" "grep -q 'Article VII' '$CONSTITUTION'"
	run_test "Constitution mentions 'NON-NEGOTIABLE'" "grep -q 'NON-NEGOTIABLE' '$CONSTITUTION'"
fi

echo ""

# =============================================================================
# TEST 4: Category structure
# =============================================================================
echo -e "${BLUE}Test Suite: Agent Categories${NC}"

EXPECTED_CATEGORIES=(
	"leadership_strategy"
	"technical_development"
	"business_operations"
	"design_ux"
	"compliance_legal"
	"specialized_experts"
	"core_utility"
	"release_management"
)

for category in "${EXPECTED_CATEGORIES[@]}"; do
	run_test "Category '$category' exists" "[ -d '$AGENTS_DIR/$category' ]"
done

echo ""

# =============================================================================
# TEST 5: Hooks system
# =============================================================================
echo -e "${BLUE}Test Suite: Hooks System${NC}"

run_test "Hooks directory exists" "[ -d '$ROOT_DIR/hooks' ]"
run_test "Hook lib directory exists" "[ -d '$ROOT_DIR/hooks/lib' ]"
run_test "prefer-ci-summary.sh exists" "[ -f '$ROOT_DIR/hooks/prefer-ci-summary.sh' ]"
run_test "enforce-line-limit.sh exists" "[ -f '$ROOT_DIR/hooks/enforce-line-limit.sh' ]"
run_test "worktree-guard.sh exists" "[ -f '$ROOT_DIR/hooks/worktree-guard.sh' ]"
run_test "lib/common.sh exists" "[ -f '$ROOT_DIR/hooks/lib/common.sh' ]"

HOOK_COUNT=$(/usr/bin/find "$ROOT_DIR/hooks" -name '*.sh' -type f 2>/dev/null | /usr/bin/wc -l | tr -d ' ')
run_test "At least 10 hooks exist ($HOOK_COUNT found)" "[ '$HOOK_COUNT' -ge 10 ]"

# Check hooks are executable
NON_EXEC=0
for hook in $(/usr/bin/find "$ROOT_DIR/hooks" -name '*.sh' -type f); do
	if [ ! -x "$hook" ]; then
		NON_EXEC=$((NON_EXEC + 1))
	fi
done
run_test "All hooks are executable ($NON_EXEC not executable)" "[ '$NON_EXEC' -eq 0 ]"

echo ""

# =============================================================================
# TEST 6: Reference documentation
# =============================================================================
echo -e "${BLUE}Test Suite: Reference Documentation${NC}"

run_test "Reference directory exists" "[ -d '$ROOT_DIR/.claude/reference/operational' ]"

REF_COUNT=$(/usr/bin/find "$ROOT_DIR/.claude/reference" -name '*.md' -type f 2>/dev/null | /usr/bin/wc -l | tr -d ' ')
run_test "At least 5 reference docs exist ($REF_COUNT found)" "[ '$REF_COUNT' -ge 5 ]"

echo ""

# =============================================================================
# TEST 7: No legacy files
# =============================================================================
echo -e "${BLUE}Test Suite: Legacy Cleanup${NC}"

run_test "No claude-agents/ folder" "[ ! -d '$ROOT_DIR/claude-agents' ]"
run_test "No claude-agenti/ folder" "[ ! -d '$ROOT_DIR/claude-agenti' ]"
run_test "No start.sh script" "[ ! -f '$ROOT_DIR/start.sh' ]"
run_test "No translate-agents.sh script" "[ ! -f '$ROOT_DIR/scripts/translate-agents.sh' ]"

echo ""

# =============================================================================
# TEST 6: Makefile commands
# =============================================================================
echo -e "${BLUE}Test Suite: Makefile Commands${NC}"

mkdir -p "$TEST_DIR"

run_test "make help works" "cd '$ROOT_DIR' && make help"
run_test "make version works" "cd '$ROOT_DIR' && make version"
run_test "make lint works" "cd '$ROOT_DIR' && make lint"

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "======================================"
echo -e "${BLUE}Test Summary${NC}"
echo "======================================"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ "$FAILED" -eq 0 ]; then
	echo -e "${GREEN}✅ All tests passed!${NC}"
	exit 0
else
	echo -e "${RED}❌ Some tests failed${NC}"
	exit 1
fi
