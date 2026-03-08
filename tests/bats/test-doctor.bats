#!/usr/bin/env bats
# Tests for scripts/myconvergio-doctor.sh

setup() {
  DOCTOR_SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/myconvergio-doctor.sh"
}

@test "doctor: script exists" {
  [ -f "$DOCTOR_SCRIPT" ]
}

@test "doctor: parses cleanly" {
  run bash -n "$DOCTOR_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "doctor: uses set -euo pipefail" {
  run grep 'set -euo pipefail' "$DOCTOR_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "doctor: runs and produces output" {
  run bash "$DOCTOR_SCRIPT" 2>&1
  # Doctor should always produce output even if some checks fail
  [ -n "$output" ]
  [[ "$output" == *"Health Check"* || "$output" == *"✓"* || "$output" == *"Prerequisites"* ]]
}

@test "doctor: checks prerequisites" {
  run grep -E 'bash|git|make' "$DOCTOR_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "doctor: checks installation directories" {
  run grep -E '\.claude|agents|rules|hooks' "$DOCTOR_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "doctor: reports pass/warn/fail counts" {
  run grep -E 'PASS|WARN|FAIL' "$DOCTOR_SCRIPT"
  [ "$status" -eq 0 ]
}
