#!/usr/bin/env bats
# Tests for hooks/secret-scanner.sh

setup() {
  TEST_DIR="$(mktemp -d)"
  export GIT_DIR="$TEST_DIR/.git"
  cd "$TEST_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  # Create initial commit so diff works
  echo "init" > init.txt
  git add init.txt
  git commit -q -m "init"
  SCANNER="${BATS_TEST_DIRNAME}/../../hooks/secret-scanner.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "secret-scanner: exits 0 with no staged files" {
  run bash "$SCANNER"
  [ "$status" -eq 0 ]
}

@test "secret-scanner: detects AWS access key" {
  echo 'aws_key = "AKIAIOSFODNN7EXAMPLE"' > secret.txt
  git add secret.txt
  run bash "$SCANNER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "secret-scanner: detects GitHub token" {
  echo 'const token = "ghp_ABCDEFGHIJKLMNOPqrstuvwx"' > ghtoken.js
  git add ghtoken.js
  run bash "$SCANNER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "secret-scanner: allows clean file" {
  echo 'const greeting = "hello world";' > clean.js
  git add clean.js
  run bash "$SCANNER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No secrets detected"* ]]
}

@test "secret-scanner: skips lock files" {
  echo 'token = "sk-proj-ABCDEFGHIJKLMNOP"' > package-lock.json
  git add package-lock.json
  run bash "$SCANNER"
  [ "$status" -eq 0 ]
}

@test "secret-scanner: detects JWT token" {
  echo 'const t = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"' > jwt.js
  git add jwt.js
  run bash "$SCANNER"
  [ "$status" -eq 1 ]
}
