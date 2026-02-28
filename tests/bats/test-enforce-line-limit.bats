#!/usr/bin/env bats
# Tests for hooks/enforce-line-limit.sh

setup() {
  ENFORCER="${BATS_TEST_DIRNAME}/../../hooks/enforce-line-limit.sh"
  TEST_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "enforce-line-limit: exits 0 when no file path in input" {
  run bash -c 'echo "{\"tool_input\":{}}" | bash "$1"' _ "$ENFORCER"
  [ "$status" -eq 0 ]
}

@test "enforce-line-limit: exits 0 for nonexistent file" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/tmp/nonexistent_file_$$\"}}" | bash "$1"' _ "$ENFORCER"
  [ "$status" -eq 0 ]
}

@test "enforce-line-limit: allows file under 250 lines" {
  FILE="$TEST_DIR/small.sh"
  seq 1 100 > "$FILE"
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"$1\"}}" | bash "$2"' _ "$FILE" "$ENFORCER"
  [ "$status" -eq 0 ]
}

@test "enforce-line-limit: blocks file over 250 lines" {
  FILE="$TEST_DIR/large.sh"
  seq 1 300 > "$FILE"
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"$1\"}}" | bash "$2"' _ "$FILE" "$ENFORCER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "enforce-line-limit: skips lock files" {
  FILE="$TEST_DIR/deps.lock"
  seq 1 500 > "$FILE"
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"$1\"}}" | bash "$2"' _ "$FILE" "$ENFORCER"
  [ "$status" -eq 0 ]
}

@test "enforce-line-limit: skips .db files" {
  FILE="$TEST_DIR/data.db"
  seq 1 500 > "$FILE"
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"$1\"}}" | bash "$2"' _ "$FILE" "$ENFORCER"
  [ "$status" -eq 0 ]
}

@test "enforce-line-limit: allows exactly 250 lines" {
  FILE="$TEST_DIR/exact.sh"
  seq 1 250 > "$FILE"
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"$1\"}}" | bash "$2"' _ "$FILE" "$ENFORCER"
  [ "$status" -eq 0 ]
}
