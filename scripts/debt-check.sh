#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"

if rg -n 'TODO|FIXME|@ts-ignore' "$ROOT_DIR" \
  --glob '!node_modules/**' --glob '!.git/**' --glob '!dist/**' --glob '!coverage/**'; then
  exit 1
fi
