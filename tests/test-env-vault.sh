#!/usr/bin/env bats
# bats tests for env-vault.sh
# All code and comments in English

setup() {
  TMPDIR=$(mktemp -d)
  export TMPDIR
  export ENV_FILE="$TMPDIR/.env"
  export LOG_FILE="$TMPDIR/vault.log"
  export VAULT_FILE="$TMPDIR/vault.json"
  export GH_MOCK="$TMPDIR/gh-mock"
  export AZ_MOCK="$TMPDIR/az-mock"
  echo "SECRET=topsecret" > "$ENV_FILE"
  echo "{}" > "$VAULT_FILE"
  touch "$LOG_FILE"
  PATH="$TMPDIR:$PATH"
}

teardown() {
  rm -rf "$TMPDIR"
}

# Mock gh and az commands
@test "backup-calls-gh-secret (mocked)" {
  echo '#!/bin/bash
echo "gh secret called"' > "$GH_MOCK"
  chmod +x "$GH_MOCK"
  ln -sf "$GH_MOCK" "$TMPDIR/gh"
  run bash scripts/env-vault.sh backup "$ENV_FILE" "$VAULT_FILE" "$LOG_FILE"
  [[ "$output" =~ "gh secret called" ]]
}

@test "backup-calls-az-keyvault (mocked)" {
  echo '#!/bin/bash
echo "az keyvault called"' > "$AZ_MOCK"
  chmod +x "$AZ_MOCK"
  ln -sf "$AZ_MOCK" "$TMPDIR/az"
  run bash scripts/env-vault.sh backup "$ENV_FILE" "$VAULT_FILE" "$LOG_FILE"
  [[ "$output" =~ "az keyvault called" ]]
}

@test "backup-creates-log-entry" {
  run bash scripts/env-vault.sh backup "$ENV_FILE" "$VAULT_FILE" "$LOG_FILE"
  grep -q "Backup completed" "$LOG_FILE"
}

@test "restore-recreates-env-file" {
  rm "$ENV_FILE"
  run bash scripts/env-vault.sh restore "$VAULT_FILE" "$ENV_FILE" "$LOG_FILE"
  [ -f "$ENV_FILE" ]
  grep -q "SECRET=topsecret" "$ENV_FILE"
}

@test "diff-no-secrets-in-output" {
  run bash scripts/env-vault.sh diff "$ENV_FILE" "$VAULT_FILE"
  [[ ! "$output" =~ "SECRET" ]]
}

@test "audit-fresh-pass" {
  run bash scripts/env-vault.sh audit "$ENV_FILE" "$VAULT_FILE"
  [[ "$output" =~ "Audit passed" ]]
}

@test "audit-stale-warn" {
  echo '"stale": true' > "$VAULT_FILE"
  run bash scripts/env-vault.sh audit "$ENV_FILE" "$VAULT_FILE"
  [[ "$output" =~ "Audit warning" ]]
}

@test "guard-blocks-secret-in-staged" {
  echo "SECRET=topsecret" > "$TMPDIR/staged.env"
  run bash scripts/env-vault.sh guard "$TMPDIR/staged.env"
  [[ "$output" =~ "Blocked: secret detected" ]]
}

@test "guard-allows-clean-commit" {
  echo "SAFE=ok" > "$TMPDIR/clean.env"
  run bash scripts/env-vault.sh guard "$TMPDIR/clean.env"
  [[ "$output" =~ "Allowed: clean" ]]
}
