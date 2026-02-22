#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

missing=0

check_file() {
  local path=$1
  if ! grep -q 'optimize-project' "$path"; then
    echo "Missing optimize-project entry in $path"
    missing=1
  fi
}

check_file "$HOME/.claude/CHANGELOG.md"
check_file "$HOME/GitHub/MyConvergio/CHANGELOG.md"

if [ "$missing" -ne 0 ]; then
  exit 1
fi
