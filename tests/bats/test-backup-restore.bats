#!/usr/bin/env bats
# Tests for scripts/myconvergio-backup.sh and myconvergio-restore.sh

setup() {
  BACKUP_SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/myconvergio-backup.sh"
  RESTORE_SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/myconvergio-restore.sh"
}

@test "backup: script exists and is executable" {
  [ -f "$BACKUP_SCRIPT" ]
  [ -x "$BACKUP_SCRIPT" ] || bash -n "$BACKUP_SCRIPT"
}

@test "backup: shows usage with --help" {
  run bash "$BACKUP_SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* || "$output" == *"Usage"* ]]
}

@test "backup: dry-run exits cleanly" {
  run bash "$BACKUP_SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY"* || "$output" == *"dry"* || "$output" == *"INFO"* ]]
}

@test "backup: rejects unknown options" {
  run bash "$BACKUP_SCRIPT" --invalid-flag
  [ "$status" -ne 0 ]
}

@test "restore: script exists" {
  [ -f "$RESTORE_SCRIPT" ]
}

@test "restore: shows usage with --help" {
  run bash "$RESTORE_SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* || "$output" == *"full"* || "$output" == *"db-only"* ]]
}

@test "restore: fails without backup path" {
  run bash "$RESTORE_SCRIPT" /tmp/nonexistent-backup-dir-$$
  [ "$status" -ne 0 ]
}
