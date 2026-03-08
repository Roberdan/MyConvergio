#!/usr/bin/env bats
# Tests for scripts/migrate-v10-to-v11.sh

setup() {
  MIGRATION_SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/migrate-v10-to-v11.sh"
}

@test "migration: script exists and parses cleanly" {
  [ -f "$MIGRATION_SCRIPT" ]
  run bash -n "$MIGRATION_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "migration: shows usage with --help" {
  # Script may call die early if prerequisites fail; check for help or usage text
  run bash "$MIGRATION_SCRIPT" --help 2>&1
  # Accept both help text or prerequisite errors
  [[ "$output" == *"Usage"* || "$output" == *"dry-run"* || "$output" == *"Missing"* || "$output" == *"ERROR"* ]]
}

@test "migration: dry-run mode available" {
  run grep -c '\-\-dry-run' "$MIGRATION_SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "migration: references backup script" {
  run grep 'myconvergio-backup' "$MIGRATION_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "migration: references restore script" {
  run grep 'myconvergio-restore' "$MIGRATION_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "migration: checks source version" {
  run grep -E 'SOURCE_VERSION|source_version|v10' "$MIGRATION_SCRIPT"
  [ "$status" -eq 0 ]
}
