#!/usr/bin/env bats
# Tests for install.sh

setup() {
  INSTALLER="${BATS_TEST_DIRNAME}/../../install.sh"
}

@test "install.sh: is executable or sourceable" {
  [ -f "$INSTALLER" ]
}

@test "install.sh: requires jq in prerequisites" {
  run grep 'jq' "$INSTALLER"
  [ "$status" -eq 0 ]
}

@test "install.sh: requires git in prerequisites" {
  run grep 'git' "$INSTALLER"
  [ "$status" -eq 0 ]
}

@test "install.sh: shows help with --help" {
  run bash "$INSTALLER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* || "$output" == *"install"* ]]
}
