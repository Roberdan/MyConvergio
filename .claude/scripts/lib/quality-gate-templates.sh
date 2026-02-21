#!/bin/bash
# quality-gate-templates.sh: reusable gates for orchestrator
# Each gate returns JSON: {pass, findings[]}
# Configurable per-project via orchestrator.yaml

set -euo pipefail

# gate_pre_deploy_deps: checks for required dependencies before deploy
gate_pre_deploy_deps() {
  local findings=()
  local pass=1
  # Example: check for jq, git, curl
  for dep in jq git curl; do
    if ! command -v "$dep" >/dev/null; then
      findings+=("Missing dependency: $dep")
      pass=0
    fi
  done
  echo "{\"pass\":$pass,\"findings\":[${findings[@]/#/\"}${findings[@]/%/\"}]}"
}

# gate_env_var_audit: checks for required env vars and audits for secrets
# Reads config from orchestrator.yaml if present
gate_env_var_audit() {
  local findings=()
  local pass=1
  # Example: check for ENV vars (can be extended)
  for var in API_KEY DB_URL; do
    if [ -z "${!var:-}" ]; then
      findings+=("Missing env var: $var")
      pass=0
    fi
  done
  # Audit for secrets in env
  for var in $(env | grep -E 'SECRET|TOKEN|KEY' | cut -d= -f1); do
    findings+=("Secret env var detected: $var")
    pass=0
  done
  echo "{\"pass\":$pass,\"findings\":[${findings[@]/#/\"}${findings[@]/%/\"}]}"
}

# gate_security_checklist: basic security checks (can be extended)
gate_security_checklist() {
  local findings=()
  local pass=1
  # Example: check for .env file permissions
  if [ -f .env ] && [ $(stat -c %a .env) -gt 600 ]; then
    findings+=(".env file permissions too open")
    pass=0
  fi
  echo "{\"pass\":$pass,\"findings\":[${findings[@]/#/\"}${findings[@]/%/\"}]}"
}

# gate_doc_sync: checks if docs are up to date (dummy placeholder)
gate_doc_sync() {
  local findings=()
  local pass=1
  # Example: check for README.md
  if [ ! -f README.md ]; then
    findings+=("Missing README.md")
    pass=0
  fi
  echo "{\"pass\":$pass,\"findings\":[${findings[@]/#/\"}${findings[@]/%/\"}]}"
}

# gate_e2e_stability: checks for e2e test results (dummy placeholder)
gate_e2e_stability() {
  local findings=()
  local pass=1
  # Example: check for e2e-results.json
  if [ ! -f e2e-results.json ]; then
    findings+=("Missing e2e-results.json")
    pass=0
  fi
  echo "{\"pass\":$pass,\"findings\":[${findings[@]/#/\"}${findings[@]/%/\"}]}"
}
