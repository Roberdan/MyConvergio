#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REFERENCE_DIR="$HOME/.claude/reference/operational"
PREF_FILE="$REFERENCE_DIR/tool-preferences.md"
DIGEST_FILE="$REFERENCE_DIR/digest-scripts.md"

for file in "$PREF_FILE" "$DIGEST_FILE"; do
  if ! grep -q 'project-audit' "$file"; then
    echo "Missing project-audit entry in $file"
    exit 1
  fi
done
