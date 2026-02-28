#!/usr/bin/env bats
# Tests for .claude/scripts/worktree-guard.sh

setup() {
  GUARD="${BATS_TEST_DIRNAME}/../../.claude/scripts/worktree-guard.sh"
}

@test "worktree-guard: fails without arguments" {
  run bash "$GUARD"
  [ "$status" -eq 1 ]
  [[ "$output" == *"WORKTREE_VIOLATION"* ]]
}

@test "worktree-guard: fails with nonexistent path" {
  run bash "$GUARD" "/tmp/nonexistent-worktree-path-$RANDOM"
  [ "$status" -eq 1 ]
}

@test "worktree-guard: fails outside git repo" {
  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"
  run bash "$GUARD" "$TMPDIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"WORKTREE_VIOLATION"* ]]
  rm -rf "$TMPDIR"
}

@test "worktree-guard: detects protected branch" {
  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "x" > x.txt && git add . && git commit -q -m "init"
  # Default branch is likely 'master'
  run bash "$GUARD" "$TMPDIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"protected branch"* ]]
  rm -rf "$TMPDIR"
}
