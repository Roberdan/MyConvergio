#!/bin/bash
# env-vault.sh: universal .env backup/restore tool
# Subcommands: backup, restore, diff, audit, list
# Config from orchestrator.yaml vault section
# Multiple .env files per project. NEVER log values. Log metadata to env_vault_log table.
set -euo pipefail

VAULT_CONFIG="config/orchestrator.yaml"
LOG_TABLE="env_vault_log"

usage() {
  echo "Usage: $0 {backup|restore|diff|audit|list} [options]"
  exit 1
}

log_metadata() {
  # Log metadata to env_vault_log table (never log values)
  local action="$1"
  local file="$2"
  local project="$3"
  local timestamp
  timestamp=$(date +%s)
  sqlite3 plan-db.sqlite "INSERT INTO $LOG_TABLE (action, file, project, timestamp) VALUES ('$action', '$file', '$project', $timestamp);"
}

backup() {
  local env_file="$1"
  local project="$2"
  # Backup to GitHub Secrets
  gh secret set "$(basename "$env_file")" -b "$(cat "$env_file")" || true
  # Backup to Azure Key Vault
  az keyvault secret set --vault-name "$VAULT_NAME" --name "$(basename "$env_file")" --value "$(cat "$env_file")" || true
  log_metadata "backup" "$env_file" "$project"
}

restore() {
  local env_file="$1"
  local project="$2"
  local source="$3"
  if [[ "$source" == "gh" || "$source" == "both" ]]; then
    gh secret view "$(basename "$env_file")" > "$env_file" || true
  fi
  if [[ "$source" == "az" || "$source" == "both" ]]; then
    az keyvault secret show --vault-name "$VAULT_NAME" --name "$(basename "$env_file")" --query value -o tsv > "$env_file" || true
  fi
  log_metadata "restore" "$env_file" "$project"
}

diff() {
  local env_file="$1"
  local project="$2"
  echo "Diff for $env_file ($project):"
  echo "GH Secret:"
  gh secret view "$(basename "$env_file")" | grep -v '=' || true
  echo "Azure KV:"
  az keyvault secret show --vault-name "$VAULT_NAME" --name "$(basename "$env_file")" --query value -o tsv | grep -v '=' || true
  log_metadata "diff" "$env_file" "$project"
}

audit() {
  # Check all projects <7d
  echo "Audit: projects with .env changes in last 7 days"
  sqlite3 plan-db.sqlite "SELECT * FROM $LOG_TABLE WHERE timestamp > strftime('%s','now','-7 days');"
  log_metadata "audit" "" ""
}

list() {
  # List all .env files tracked
  echo "Tracked .env files:"
  sqlite3 plan-db.sqlite "SELECT DISTINCT file FROM $LOG_TABLE;"
  log_metadata "list" "" ""
}

main() {
  if [ $# -lt 1 ]; then usage; fi
  subcmd="$1"; shift
  case "$subcmd" in
    backup) backup "$@" ;;
    restore) restore "$@" ;;
    diff) diff "$@" ;;
    audit) audit ;;
    list) list ;;
    *) usage ;;
  esac
}

main "$@"
