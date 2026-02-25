#!/usr/bin/env bash
# Test script for scripts/linting/validate-frontmatter.sh
# Tests the YAML frontmatter validation against JSON schemas

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_PATH="$REPO_ROOT/scripts/linting/validate-frontmatter.sh"

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

# Main tests
echo "========================================"
echo "Testing validate-frontmatter.sh"
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

# Test 4: Check dependencies (python3 and jsonschema)
echo ""
echo "Test 4: Dependencies"
if command -v python3 &>/dev/null; then
  echo -e "${GREEN}✓${NC} PASS: python3 is installed"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} FAIL: python3 not found"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if python3 -c "import jsonschema" 2>/dev/null; then
  echo -e "${GREEN}✓${NC} PASS: jsonschema Python package is installed"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} FAIL: jsonschema Python package not installed"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Schema mapping file exists
echo ""
echo "Test 5: Schema configuration"
SCHEMA_MAPPING="$REPO_ROOT/scripts/linting/schemas/schema-mapping.json"
assert_file_exists "$SCHEMA_MAPPING" "schema-mapping.json exists"

# Test 6: Run script and check exit code
echo ""
echo "Test 6: Script execution"
if [[ -f "$SCRIPT_PATH" ]] && [[ -x "$SCRIPT_PATH" ]]; then
  cd "$REPO_ROOT"
  if bash "$SCRIPT_PATH" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} PASS: Script runs and exits with code 0"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    EXIT_CODE=$?
    echo -e "${RED}✗${NC} FAIL: Script exited with code $EXIT_CODE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
fi

# Test 7: Help flag works
echo ""
echo "Test 7: Help output"
if [[ -f "$SCRIPT_PATH" ]] && [[ -x "$SCRIPT_PATH" ]]; then
  if bash "$SCRIPT_PATH" --help >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} PASS: --help flag works"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: --help flag failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
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
