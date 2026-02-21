#!/usr/bin/env bash
# Test script for scripts/generate-copilot-agents.sh
# Tests the conversion of .claude/agents/*.md to copilot-agents/*.agent.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_PATH="$REPO_ROOT/scripts/generate-copilot-agents.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_file_exists() {
  local file="$1"
  local test_name="$2"
  
  if [[ -f "$file" ]]; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: $test_name - File not found: $file"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_executable() {
  local file="$1"
  local test_name="$2"
  
  if [[ -x "$file" ]]; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: $test_name - File not executable: $file"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local test_name="$3"
  
  if grep -q "$pattern" "$file"; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: $test_name - Pattern not found: $pattern"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local test_name="$3"
  
  if ! grep -q "$pattern" "$file"; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: $test_name - Pattern found but shouldn't: $pattern"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Main tests
echo "========================================"
echo "Testing generate-copilot-agents.sh"
echo "========================================"
echo ""

# Test 1: Script exists
echo "Test 1: Script existence"
assert_file_exists "$SCRIPT_PATH" "Script file exists"

# Test 2: Script is executable
echo ""
echo "Test 2: Script permissions"
assert_executable "$SCRIPT_PATH" "Script is executable"

# Test 3: Script has proper shebang and set -euo pipefail
echo ""
echo "Test 3: Script safety features"
if [[ -f "$SCRIPT_PATH" ]]; then
  assert_contains "$SCRIPT_PATH" "#!/usr/bin/env bash" "Has bash shebang"
  assert_contains "$SCRIPT_PATH" "set -euo pipefail" "Has set -euo pipefail"
fi

# Test 4: Run script in dry-run mode (if supported)
echo ""
echo "Test 4: Script execution"
if [[ -f "$SCRIPT_PATH" ]] && [[ -x "$SCRIPT_PATH" ]]; then
  cd "$REPO_ROOT"
  if bash "$SCRIPT_PATH" --help >/dev/null 2>&1 || bash "$SCRIPT_PATH" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} PASS: Script runs without errors"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: Script failed to run"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
fi

# Test 5: Check if output directory exists
echo ""
echo "Test 5: Output directory"
if [[ -d "$REPO_ROOT/copilot-agents" ]]; then
  echo -e "${GREEN}✓${NC} PASS: copilot-agents directory exists"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} FAIL: copilot-agents directory not found"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Check if at least one .agent.md file exists after running script
echo ""
echo "Test 6: Generated files"
if [[ -f "$SCRIPT_PATH" ]] && [[ -x "$SCRIPT_PATH" ]]; then
  cd "$REPO_ROOT"
  bash "$SCRIPT_PATH" >/dev/null 2>&1 || true
  
  if compgen -G "$REPO_ROOT/copilot-agents/*.agent.md" > /dev/null; then
    echo -e "${GREEN}✓${NC} PASS: At least one .agent.md file generated"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: No .agent.md files found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
fi

# Test 7: Verify frontmatter conversion
echo ""
echo "Test 7: Frontmatter conversion"
if compgen -G "$REPO_ROOT/copilot-agents/*.agent.md" > /dev/null; then
  SAMPLE_FILE=$(ls "$REPO_ROOT/copilot-agents"/*.agent.md | head -1)
  assert_contains "$SAMPLE_FILE" "^---$" "Has YAML frontmatter delimiter"
  assert_contains "$SAMPLE_FILE" "^name:" "Has name field"
  assert_contains "$SAMPLE_FILE" "^description:" "Has description field"
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
fi
