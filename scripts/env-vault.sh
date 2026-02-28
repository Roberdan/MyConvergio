#!/bin/bash
set -euo pipefail
# env-vault.sh: universal .env backup/restore tool
# Subcommands: backup, restore, diff, audit, list
# Config from orchestrator.yaml vault section
# Multiple .env files per project. NEVER log values. Log metadata to env_vault_log table.
set -euo pipefail

VAULT_CONFIG="config/orchestrator.yaml"
LOG_TABLE="env_vault_log"
DB_FILE="${ENV_VAULT_DB:-plan-db.sqlite}"
SECRET_POLICY="${ENV_VAULT_SECRET_POLICY:-warn}"

usage() {
  echo "Usage: $0 {backup|restore|diff|audit|list} [options]"
  echo "Env: ENV_VAULT_SECRET_POLICY=warn|block|allow (default: warn)"
  exit 1
}

log_metadata() {
  local action="$1"
  local file="${2:-}"
  local project="${3:-}"
  local timestamp
  timestamp=$(date +%s)
  sqlite3 "$DB_FILE" \
    "INSERT INTO ${LOG_TABLE} (action, file, project, timestamp) VALUES (:action, :file, :project, :ts);" \
    -cmd ".param set :action '$action'" \
    -cmd ".param set :file '$file'" \
    -cmd ".param set :project '$project'" \
    -cmd ".param set :ts $timestamp"
}

check_secret_policy() {
  local operation="$1"
  case "$SECRET_POLICY" in
    block)
      echo "[ERROR] Secret ${operation} blocked by policy (ENV_VAULT_SECRET_POLICY=block)" >&2
      return 1 ;;
    warn)
      echo "[WARN] Secret ${operation} — ensure credentials are rotated after use" >&2 ;;
    allow) ;;
    *)
      echo "[ERROR] Unknown secret policy: $SECRET_POLICY" >&2
      return 1 ;;
  esac
}

run_or_fail() {
  local context="$1"; shift
  if ! "$@" 2>/dev/null; then
    echo "[ERROR] ${context} failed (exit $?)" >&2
    return 1
  fi
}

backup() {
  local env_file="$1"
  local project="$2"
  local name
  name="$(basename "$env_file")"
  check_secret_policy "backup:gh:${name}" || return 1
  run_or_fail "gh secret set ${name}" gh secret set "$name" -b "$(cat "$env_file")"
  check_secret_policy "backup:az:${name}" || return 1
  run_or_fail "az keyvault set ${name}" az keyvault secret set \
    --vault-name "$VAULT_NAME" --name "$name" --value "$(cat "$env_file")"
  log_metadata "backup" "$env_file" "$project"
}

restore() {
  local env_file="$1"
  local project="$2"
  local source="$3"
  local name
  name="$(basename "$env_file")"
  if [[ "$source" == "gh" || "$source" == "both" ]]; then
    check_secret_policy "restore:gh:${name}" || return 1
    run_or_fail "gh secret view ${name}" gh secret view "$name" > "$env_file"
  fi
  if [[ "$source" == "az" || "$source" == "both" ]]; then
    check_secret_policy "restore:az:${name}" || return 1
    run_or_fail "az keyvault show ${name}" az keyvault secret show \
      --vault-name "$VAULT_NAME" --name "$name" --query value -o tsv > "$env_file"
  fi
  log_metadata "restore" "$env_file" "$project"
}

diff_env() {
  local env_file="$1"
  local project="$2"
  local name
  name="$(basename "$env_file")"
  echo "Diff for $env_file ($project):"
  echo "GH Secret:"
  check_secret_policy "diff:gh:${name}" || return 1
  run_or_fail "gh secret view ${name}" gh secret view "$name"
  echo "Azure KV:"
  check_secret_policy "diff:az:${name}" || return 1
  run_or_fail "az keyvault show ${name}" az keyvault secret show \
    --vault-name "$VAULT_NAME" --name "$name" --query value -o tsv
  log_metadata "diff" "$env_file" "$project"
}

audit() {
  echo "Audit: projects with .env changes in last 7 days"
  sqlite3 "$DB_FILE" "SELECT * FROM ${LOG_TABLE} WHERE timestamp > strftime('%s','now','-7 days');"
  log_metadata "audit" "" ""
}

list_env() {
  echo "Tracked .env files:"
  sqlite3 "$DB_FILE" "SELECT DISTINCT file FROM ${LOG_TABLE};"
  log_metadata "list" "" ""
}

main() {
  if [ $# -lt 1 ]; then usage; fi
  local subcmd="$1"; shift
  case "$subcmd" in
    backup) backup "$@" ;;
    restore) restore "$@" ;;
    diff) diff_env "$@" ;;
    audit) audit ;;
    list) list_env ;;
    *) usage ;;
  esac
}

main "$@"
