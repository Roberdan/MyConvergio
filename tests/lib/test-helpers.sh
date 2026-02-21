#!/usr/bin/env bash
# test-helpers.sh: Common test utilities and assertions
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

# Colors
export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
export BLUE='\033[0;34m' NC='\033[0m' RESET='\033[0m'

# Test counters
export TESTS_RUN=0 TESTS_PASSED=0 TESTS_FAILED=0

# Get script directory
get_script_dir() { cd "$(dirname "${BASH_SOURCE[1]}")" && pwd; }

# Get repository root (parent of tests/)
get_repo_root() { cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd; }

# Pass/fail functions
pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1)); TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "${GREEN}✓ PASS${NC}: $1"
}

fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1)); TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "${RED}✗ FAIL${NC}: $1"
  [ $# -ge 2 ] && echo "  Expected: $2"
  [ $# -ge 3 ] && echo "  Got: $3"
}

test_pass() { pass "$@"; }
test_fail() { fail "$@"; }

# Assertion helpers
assert_file_exists() {
  local file="$1" description="${2:-File $file should exist}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -f "$file" ]; then
    echo -e "${GREEN}✓${NC} $description"; TESTS_PASSED=$((TESTS_PASSED + 1)); return 0
  else
    echo -e "${RED}✗${NC} $description"; echo "  File not found: $file"
    TESTS_FAILED=$((TESTS_FAILED + 1)); return 1
  fi
}

assert_dir_exists() {
  local dir="$1" description="${2:-Directory $dir should exist}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -d "$dir" ]; then
    echo -e "${GREEN}✓${NC} $description"; TESTS_PASSED=$((TESTS_PASSED + 1)); return 0
  else
    echo -e "${RED}✗${NC} $description"; echo "  Directory not found: $dir"
    TESTS_FAILED=$((TESTS_FAILED + 1)); return 1
  fi
}

assert_executable() {
  local file="$1" description="${2:-$file should be executable}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -x "$file" ]; then
    echo -e "${GREEN}✓${NC} $description"; TESTS_PASSED=$((TESTS_PASSED + 1)); return 0
  else
    echo -e "${RED}✗${NC} $description"; TESTS_FAILED=$((TESTS_FAILED + 1)); return 1
  fi
}

assert_grep() {
  local pattern="$1" file="$2" description="${3:-Pattern '$pattern' in $file}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} $description"; TESTS_PASSED=$((TESTS_PASSED + 1)); return 0
  else
    echo -e "${RED}✗${NC} $description"; TESTS_FAILED=$((TESTS_FAILED + 1)); return 1
  fi
}

assert_line_count() {
  local file="$1" max_lines="$2" description="${3:-$file ≤$max_lines lines}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ ! -f "$file" ]; then
    echo -e "${RED}✗${NC} $description (file not found)"
    TESTS_FAILED=$((TESTS_FAILED + 1)); return 1
  fi
  local line_count=$(wc -l < "$file" | tr -d ' ')
  if [ "$line_count" -le "$max_lines" ]; then
    echo -e "${GREEN}✓${NC} $description ($line_count lines)"
    TESTS_PASSED=$((TESTS_PASSED + 1)); return 0
  else
    echo -e "${RED}✗${NC} $description ($line_count lines)"
    TESTS_FAILED=$((TESTS_FAILED + 1)); return 1
  fi
}

assert_bash_syntax() {
  local file="$1" description="${2:-$file has valid bash syntax}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if bash -n "$file" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} $description"; TESTS_PASSED=$((TESTS_PASSED + 1)); return 0
  else
    echo -e "${RED}✗${NC} $description"; TESTS_FAILED=$((TESTS_FAILED + 1)); return 1
  fi
}

assert_exit_code() {
  local actual="$1" expected="$2" description="${3:-Exit code should be $expected}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$actual" -eq "$expected" ]; then
    echo -e "${GREEN}✓${NC} $description"; TESTS_PASSED=$((TESTS_PASSED + 1)); return 0
  else
    echo -e "${RED}✗${NC} $description"; echo "  Expected: $expected"; echo "  Got: $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1)); return 1
  fi
}

# Temp directory management
export TEST_TEMP_DIR=""

setup_temp_dir() { TEST_TEMP_DIR=$(mktemp -d); export TEST_TEMP_DIR; }
cleanup_temp_dir() { [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ] && rm -rf "$TEST_TEMP_DIR"; }
auto_cleanup_temp_dir() { setup_temp_dir; trap cleanup_temp_dir EXIT; }

# Summary reporter
print_test_summary() {
  local suite_name="${1:-Test Suite}"
  echo ""; echo "========================================="
  echo "$suite_name Summary"; echo "========================================="
  echo -e "Total:  $TESTS_RUN"; echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"; echo "========================================="
  if [ "$TESTS_FAILED" -eq 0 ] && [ "$TESTS_RUN" -gt 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"; return 0
  elif [ "$TESTS_RUN" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No tests were run${NC}"; return 1
  else
    echo -e "${RED}✗ Some tests failed${NC}"; return 1
  fi
}

exit_with_summary() { print_test_summary "$@"; exit $?; }
