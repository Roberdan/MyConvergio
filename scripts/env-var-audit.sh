#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"

rg -n '(process\.env|os\.getenv|System\.getenv|\$\{[A-Z0-9_]+)' "$ROOT_DIR" \
  --glob '!node_modules/**' --glob '!.git/**' --glob '!dist/**' --glob '!coverage/**' || true
