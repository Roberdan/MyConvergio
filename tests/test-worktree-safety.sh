#!/bin/bash
# tests/test-worktree-safety.sh
# Worktree safety tests for scripts/worktree-safety.sh
# Each test uses a temp git repo and covers:
# pre-check-fresh, pre-check-auto-rebase, pre-check-block-stale, pre-check-stash-uncommitted,
# notify-no-overlap, notify-with-overlap, recover-uncommitted, recover-clean, audit-abandoned, audit-orphaned

set -euo pipefail

TEST_DIR=$(mktemp -d)
export TEST_DIR

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

@test_pre_check_fresh() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  scripts/worktree-safety.sh pre-check "$repo" > out.txt || fail "pre-check-fresh"
  grep 'SAFE: fresh worktree' out.txt && pass "pre-check-fresh"
}

@test_pre_check_auto_rebase() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  touch file.txt && git add file.txt && git commit -m 'init'
  git checkout -b feature
  echo 'change' > file.txt
  git add file.txt && git commit -m 'feature change'
  scripts/worktree-safety.sh pre-check "$repo" > out.txt || fail "pre-check-auto-rebase"
  grep 'AUTO-REBASE' out.txt && pass "pre-check-auto-rebase"
}

@test_pre_check_block_stale() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  touch file.txt && git add file.txt && git commit -m 'init'
  git checkout -b feature
  echo 'stale' > file.txt
  git add file.txt && git commit -m 'stale change'
  git checkout main
  echo 'conflict' > file.txt
  git add file.txt && git commit -m 'main conflict'
  git checkout feature
  scripts/worktree-safety.sh pre-check "$repo" > out.txt || fail "pre-check-block-stale"
  grep 'BLOCKED: stale' out.txt && pass "pre-check-block-stale"
}

@test_pre_check_stash_uncommitted() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  touch file.txt && git add file.txt && git commit -m 'init'
  git checkout -b feature
  echo 'uncommitted' > file.txt
  scripts/worktree-safety.sh pre-check "$repo" > out.txt || fail "pre-check-stash-uncommitted"
  grep 'STASH: uncommitted' out.txt && pass "pre-check-stash-uncommitted"
}

@test_notify_no_overlap() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  scripts/worktree-safety.sh notify-merge "$repo" > out.txt || fail "notify-no-overlap"
  grep 'NO OVERLAP' out.txt && pass "notify-no-overlap"
}

@test_notify_with_overlap() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  touch file.txt && git add file.txt && git commit -m 'init'
  git checkout -b feature
  echo 'change' > file.txt
  git add file.txt && git commit -m 'feature change'
  git checkout main
  echo 'conflict' > file.txt
  git add file.txt && git commit -m 'main conflict'
  scripts/worktree-safety.sh notify-merge "$repo" > out.txt || fail "notify-with-overlap"
  grep 'OVERLAP' out.txt && pass "notify-with-overlap"
}

@test_recover_uncommitted() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  touch file.txt && git add file.txt && git commit -m 'init'
  git checkout -b feature
  echo 'uncommitted' > file.txt
  scripts/worktree-safety.sh recover "$repo" > out.txt || fail "recover-uncommitted"
  grep 'RECOVERED: uncommitted' out.txt && pass "recover-uncommitted"
}

@test_recover_clean() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  touch file.txt && git add file.txt && git commit -m 'init'
  scripts/worktree-safety.sh recover "$repo" > out.txt || fail "recover-clean"
  grep 'RECOVERED: clean' out.txt && pass "recover-clean"
}

@test_audit_abandoned() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  touch file.txt && git add file.txt && git commit -m 'init'
  scripts/worktree-safety.sh audit "$repo" > out.txt || fail "audit-abandoned"
  grep 'ABANDONED' out.txt && pass "audit-abandoned"
}

@test_audit_orphaned() {
  local repo
  repo=$(mktemp -d)
  cd "$repo"
  git init .
  touch file.txt && git add file.txt && git commit -m 'init'
  git branch -D main
  scripts/worktree-safety.sh audit "$repo" > out.txt || fail "audit-orphaned"
  grep 'ORPHANED' out.txt && pass "audit-orphaned"
}

main() {
  @test_pre_check_fresh
  @test_pre_check_auto_rebase
  @test_pre_check_block_stale
  @test_pre_check_stash_uncommitted
  @test_notify_no_overlap
  @test_notify_with_overlap
  @test_recover_uncommitted
  @test_recover_clean
  @test_audit_abandoned
  @test_audit_orphaned
}

main "$@"
