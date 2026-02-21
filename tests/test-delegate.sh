#!/usr/bin/env bats

# tests/test-delegate.sh: bats unit tests for scripts/delegate.sh
# Covers: route-to-copilot, route-to-opencode, route-to-gemini, privacy-block-sensitive-free, privacy-allow-sensitive-paid, budget-warning, budget-block, unknown-executor, missing-cli, worktree-pre-check-integration, model-from-db, yaml-config-read, fallback-chain, delegation-log-created, concurrent-delegation

load '../scripts/lib/delegate-utils.sh'
load '../scripts/lib/agent-protocol.sh'

@test "route-to-copilot" {
  run ../scripts/delegate.sh --executor copilot --task-id 1001
  [ "$status" -eq 0 ]
  [[ "$output" == *"copilot-worker"* ]]
}

@test "route-to-opencode" {
  run ../scripts/delegate.sh --executor opencode --task-id 1002
  [ "$status" -eq 0 ]
  [[ "$output" == *"opencode-worker"* ]]
}

@test "route-to-gemini" {
  run ../scripts/delegate.sh --executor gemini --task-id 1003
  [ "$status" -eq 0 ]
  [[ "$output" == *"gemini-worker"* ]]
}

@test "privacy-block-sensitive-free" {
  run ../scripts/delegate.sh --executor copilot --task-id 2001 --privacy sensitive --budget free
  [ "$status" -ne 0 ]
  [[ "$output" == *"privacy block"* ]]
}

@test "privacy-allow-sensitive-paid" {
  run ../scripts/delegate.sh --executor copilot --task-id 2002 --privacy sensitive --budget paid
  [ "$status" -eq 0 ]
  [[ "$output" == *"copilot-worker"* ]]
}

@test "budget-warning" {
  run ../scripts/delegate.sh --executor copilot --task-id 3001 --budget warning
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget warning"* ]]
}

@test "budget-block" {
  run ../scripts/delegate.sh --executor copilot --task-id 3002 --budget block
  [ "$status" -ne 0 ]
  [[ "$output" == *"budget block"* ]]
}

@test "unknown-executor" {
  run ../scripts/delegate.sh --executor unknown --task-id 4001
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown executor"* ]]
}

@test "missing-cli" {
  run ../scripts/delegate.sh --executor copilot --task-id 4002 --missing-cli
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing CLI"* ]]
}

@test "worktree-pre-check-integration" {
  run ../scripts/delegate.sh --executor copilot --task-id 5001 --worktree-pre-check
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktree pre-check"* ]]
}

@test "model-from-db" {
  run ../scripts/delegate.sh --executor copilot --task-id 6001 --model-db gpt-4.1
  [ "$status" -eq 0 ]
  [[ "$output" == *"gpt-4.1"* ]]
}

@test "yaml-config-read" {
  run ../scripts/delegate.sh --executor copilot --task-id 7001 --config-read
  [ "$status" -eq 0 ]
  [[ "$output" == *"orchestrator.yaml"* ]]
}

@test "fallback-chain" {
  run ../scripts/delegate.sh --executor copilot --task-id 8001 --fallback-chain
  [ "$status" -eq 0 ]
  [[ "$output" == *"fallback chain"* ]]
}

@test "delegation-log-created" {
  run ../scripts/delegate.sh --executor copilot --task-id 9001 --delegation-log
  [ "$status" -eq 0 ]
  [[ "$output" == *"delegation log"* ]]
}

@test "concurrent-delegation" {
  run ../scripts/delegate.sh --executor copilot --task-id 10001 --concurrent
  [ "$status" -eq 0 ]
  [[ "$output" == *"concurrent delegation"* ]]
}
