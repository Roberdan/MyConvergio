#!/bin/bash
# Test: worktree-safety.sh syntax, functions, subcommands, line count
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

REPO_ROOT="$(get_repo_root)"
TARGET="${REPO_ROOT}/scripts/worktree-safety.sh"

echo "=== test-worktree-safety.sh ==="

# T1: File exists and is executable
assert_executable "$TARGET" "file exists and is executable"

# T2: Bash syntax check
assert_bash_syntax "$TARGET" "bash -n"

# T3: Contains pre-check subcommand
assert_grep 'pre-check' "$TARGET" "pre-check subcommand"

# T4: Contains notify-merge subcommand
assert_grep 'notify-merge' "$TARGET" "notify-merge subcommand"

# T5: Contains recover subcommand
assert_grep 'recover' "$TARGET" "recover subcommand"

# T6: Contains audit subcommand
assert_grep 'audit' "$TARGET" "audit subcommand"

# T7: Uses git commands
assert_grep 'git ' "$TARGET" "uses git commands"

# T8: Line count < 250
assert_line_count "$TARGET" 249 "line count"

exit_with_summary "worktree-safety.sh"
