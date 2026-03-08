#!/usr/bin/env bats
# Tests for scripts/myconvergio-claude-sync-agent.sh

setup() {
  SYNC_SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/myconvergio-claude-sync-agent.sh"
}

@test "sync-agent: script exists" {
  [ -f "$SYNC_SCRIPT" ]
}

@test "sync-agent: parses cleanly" {
  run bash -n "$SYNC_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "sync-agent: shows usage with --help" {
  run bash "$SYNC_SCRIPT" --help 2>&1
  [[ "$output" == *"Usage"* || "$output" == *"interactive"* || "$output" == *"dry-run"* || "$output" == *"report"* ]]
}

@test "sync-agent: has dry-run mode" {
  run grep '\-\-dry-run' "$SYNC_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "sync-agent: has report-only mode" {
  run grep '\-\-report-only' "$SYNC_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "sync-agent: requires jq" {
  run grep -E 'jq' "$SYNC_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "sync-agent: references baseline file" {
  run grep 'BASELINE' "$SYNC_SCRIPT"
  [ "$status" -eq 0 ]
}
