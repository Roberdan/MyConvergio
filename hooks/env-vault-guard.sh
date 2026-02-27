#!/bin/bash
# env-vault-guard.sh: Pre-commit hook for secrets and env backup checks
# <80 lines, <1s, English only>
set -euo pipefail

PATTERNS='API_KEY=|SECRET=|PASSWORD=|CONNECTION_STRING=|private_key|token'

# Scan staged files for secrets
files=$(git diff --cached --name-only)
for f in $files; do
  [ -f "$f" ] || continue
  if grep -E "$PATTERNS" "$f" >/dev/null; then
    echo "[BLOCKED] Secret pattern found in staged file: $f"
    git diff --cached "$f" | grep -E "$PATTERNS"
    exit 1
  fi
done

# Check .env in .gitignore
if ! grep -q '^.env$' .gitignore; then
  echo "[WARNING] .env not in .gitignore"
fi

# Check env_vault_log backup staleness
if [ -f env_vault_log ]; then
  last=$(tail -1 env_vault_log | awk '{print $1}')
  now=$(date +%s)
  diff=$((now - last))
  if [ "$diff" -gt $((7*24*3600)) ]; then
    echo "[WARNING] env_vault_log backup is stale (>7d)"
  fi
fi

exit 0
