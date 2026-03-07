#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/secret-scanner.sh"

printf '%s' '{"toolName":"bash","toolArgs":{"command":"git commit -m audit"}}' | "$HOOK"
