#!/usr/bin/env bats
# Tests for hooks — all hooks must be valid bash and pass shellcheck

setup() {
  HOOKS_DIR="${BATS_TEST_DIRNAME}/../../hooks"
}

@test "hooks: directory exists" {
  [ -d "$HOOKS_DIR" ]
}

@test "hooks: all .sh files parse cleanly" {
  local failed=0
  for hook in "$HOOKS_DIR"/*.sh; do
    [ -f "$hook" ] || continue
    if ! bash -n "$hook" 2>/dev/null; then
      echo "FAIL: $hook" >&2
      failed=$((failed + 1))
    fi
  done
  [ "$failed" -eq 0 ]
}

@test "hooks: all .sh files have shebang" {
  local failed=0
  for hook in "$HOOKS_DIR"/*.sh; do
    [ -f "$hook" ] || continue
    local first_line
    first_line="$(head -1 "$hook")"
    if [[ ! "$first_line" =~ ^#! ]]; then
      echo "MISSING SHEBANG: $hook" >&2
      failed=$((failed + 1))
    fi
  done
  [ "$failed" -eq 0 ]
}

@test "hooks: enforce-line-limit.sh exists" {
  [ -f "$HOOKS_DIR/enforce-line-limit.sh" ]
}

@test "hooks: secret-scanner.sh exists" {
  [ -f "$HOOKS_DIR/secret-scanner.sh" ]
}

@test "hooks: worktree-guard.sh exists" {
  [ -f "$HOOKS_DIR/worktree-guard.sh" ] || [ -f "${BATS_TEST_DIRNAME}/../../.claude/scripts/worktree-guard.sh" ]
}

@test "hooks: enforce-standards.sh exists" {
  [ -f "$HOOKS_DIR/enforce-standards.sh" ]
}

@test "hooks: shellcheck passes on key hooks" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
  local failed=0
  for hook in "$HOOKS_DIR/enforce-line-limit.sh" "$HOOKS_DIR/secret-scanner.sh" "$HOOKS_DIR/enforce-standards.sh"; do
    [ -f "$hook" ] || continue
    if ! shellcheck -S warning "$hook" 2>/dev/null; then
      echo "SHELLCHECK FAIL: $hook" >&2
      failed=$((failed + 1))
    fi
  done
  [ "$failed" -eq 0 ]
}
