#!/bin/bash
# tests/test-agent-protocol.sh
# RED phase: 10+ test cases for agent-protocol.sh
set -euo pipefail

# Source the protocol library
. scripts/lib/agent-protocol.sh || exit 1

@test "envelope-valid-json" {
  local env
  env=$(build_task_envelope "TST-01" "Test project" "wave1" "context1" "worktree1" "rules1")
  echo "$env" | jq . >/dev/null || exit 1
}

@test "envelope-includes-worktree" {
  local env
  env=$(build_task_envelope "TST-02" "Test project" "wave2" "context2" "worktree2" "rules2")
  [[ "$env" == *"worktree2"* ]] || exit 1
}

@test "envelope-includes-context" {
  local env
  env=$(build_task_envelope "TST-03" "Test project" "wave3" "context3" "worktree3" "rules3")
  [[ "$env" == *"context3"* ]] || exit 1
}

@test "parse-success" {
  local result
  result=$(parse_worker_result '{"status":"success","output":"ok"}')
  [[ "$result" == "ok" ]] || exit 1
}

@test "parse-failure" {
  local result
  result=$(parse_worker_result '{"status":"failure","output":"fail"}')
  [[ "$result" == "fail" ]] || exit 1
}

@test "parse-timeout" {
  local result
  result=$(parse_worker_result '{"status":"timeout","output":"timeout"}')
  [[ "$result" == "timeout" ]] || exit 1
}

@test "thor-format-compact" {
  local thor
  thor=$(format_thor_input "TST-04" "compact" "file1.txt" "file2.txt")
  [[ "$thor" == *"compact"* ]] || exit 1
}

@test "thor-includes-files" {
  local thor
  thor=$(format_thor_input "TST-05" "full" "fileA.txt" "fileB.txt")
  [[ "$thor" == *"fileA.txt"* && "$thor" == *"fileB.txt"* ]] || exit 1
}

@test "round-trip" {
  local env result
  env=$(build_task_envelope "TST-06" "Proj" "wave6" "ctx6" "wt6" "rules6")
  result=$(parse_worker_result "$env")
  [[ -n "$result" ]] || exit 1
}

@test "envelope-large-context" {
  local ctx env
  ctx=$(head -c 2000 < /dev/urandom | base64)
  env=$(build_task_envelope "TST-07" "Proj" "wave7" "$ctx" "wt7" "rules7")
  [[ "$env" == *"wave7"* ]] || exit 1
}

# 10+ tests, RED phase
exit 1
