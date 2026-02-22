#!/bin/bash
# Test: version-check.sh must check copilot-cli, opencode, gemini
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

REPO_ROOT="$(get_repo_root)"
TARGET="${REPO_ROOT}/hooks/version-check.sh"

# Test 1: copilot check
assert_grep 'copilot' "$TARGET" "copilot check present"

# Test 2: opencode check
assert_grep 'opencode' "$TARGET" "opencode check present"

# Test 3: gemini check
assert_grep 'gemini' "$TARGET" "gemini check present"

# Test 4: .cli-versions.json output
assert_grep 'cli-versions' "$TARGET" "cli-versions output present"

# Test 5: <80 lines
assert_line_count "$TARGET" 79 "line count"

exit_with_summary "version-check.sh"
