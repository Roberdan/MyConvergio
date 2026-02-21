# Test Helpers Library

Common utilities for test scripts in the `.claude` ecosystem.

## Usage

```bash
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

# Your tests here
SCRIPT_DIR="$(get_script_dir)"
REPO_ROOT="$(get_repo_root)"

assert_file_exists "$REPO_ROOT/scripts/my-script.sh" "Script exists"
assert_bash_syntax "$REPO_ROOT/scripts/my-script.sh"
assert_line_count "$REPO_ROOT/scripts/my-script.sh" 250

print_test_summary "My Test Suite"
```

## Available Functions

### Colors
- `RED`, `GREEN`, `YELLOW`, `BLUE`, `NC`, `RESET`

### Counters
- `TESTS_RUN`, `TESTS_PASSED`, `TESTS_FAILED`

### Path Helpers
- `get_script_dir` - Directory containing the test script
- `get_repo_root` - Repository root (parent of tests/)

### Pass/Fail
- `pass "description"` - Record passing test
- `fail "description" [expected] [got]` - Record failing test
- `test_pass`, `test_fail` - Aliases for compatibility

### Assertions
- `assert_file_exists file [description]`
- `assert_dir_exists dir [description]`
- `assert_executable file [description]`
- `assert_grep pattern file [description]`
- `assert_line_count file max_lines [description]`
- `assert_bash_syntax file [description]`
- `assert_exit_code actual expected [description]`

### Temp Directories
- `setup_temp_dir` - Create `$TEST_TEMP_DIR`
- `cleanup_temp_dir` - Remove `$TEST_TEMP_DIR`
- `auto_cleanup_temp_dir` - Setup with EXIT trap

### Reporting
- `print_test_summary [suite_name]` - Print results
- `exit_with_summary [suite_name]` - Print and exit

## Example

```bash
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

SCRIPT_DIR="$(get_script_dir)"
REPO_ROOT="$(get_repo_root)"

# Test 1
assert_file_exists "$REPO_ROOT/scripts/worktree-safety.sh"

# Test 2
auto_cleanup_temp_dir
cd "$TEST_TEMP_DIR"
echo "test" > test.txt
assert_grep "test" test.txt

# Results
exit_with_summary "Worktree Safety Tests"
```
