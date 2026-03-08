#!/usr/bin/env bash
# mesh-preflight.sh — Verify a peer has all required tools before dispatching work
# Usage: mesh-preflight.sh <peer_name> [--fix]
# Exit 0 = ready, Exit 1 = missing tools (lists them)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/peers.sh"

PEER="${1:-}"
FIX=false
[[ "${2:-}" == "--fix" ]] && FIX=true

[[ -z "$PEER" ]] && { echo "Usage: mesh-preflight.sh <peer_name> [--fix]" >&2; exit 2; }

peers_load 2>/dev/null || true
DEST="$(peers_get "$PEER" ssh_alias 2>/dev/null || echo "$PEER")"
SSH="ssh -o ConnectTimeout=5 -o BatchMode=yes"

REQUIRED_TOOLS="git node npm sqlite3"
OPTIONAL_TOOLS="pnpm ruff"

# Remote check + optional auto-fix
REMOTE_SCRIPT='
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
missing=""
for cmd in '"$REQUIRED_TOOLS"'; do
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done
opt_missing=""
for cmd in '"$OPTIONAL_TOOLS"'; do
  command -v "$cmd" >/dev/null 2>&1 || opt_missing="$opt_missing $cmd"
done
echo "MISSING:${missing}"
echo "OPTIONAL:${opt_missing}"
'

FIX_SCRIPT='
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
fixed=""
if ! command -v pnpm >/dev/null 2>&1; then
  npm install -g pnpm >/dev/null 2>&1 && fixed="$fixed pnpm"
fi
if ! command -v ruff >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/ruff/install.sh 2>/dev/null | sh >/dev/null 2>&1 && fixed="$fixed ruff"
fi
echo "FIXED:${fixed}"
'

OUTPUT=$($SSH "$DEST" "$REMOTE_SCRIPT" 2>/dev/null) || { echo "FAIL: cannot reach $PEER" >&2; exit 1; }

MISSING=$(echo "$OUTPUT" | grep "^MISSING:" | sed 's/MISSING://')
OPT_MISSING=$(echo "$OUTPUT" | grep "^OPTIONAL:" | sed 's/OPTIONAL://')

if [[ -n "${MISSING// /}" ]]; then
  echo "FAIL: $PEER missing required:$MISSING" >&2
  exit 1
fi

if [[ -n "${OPT_MISSING// /}" ]]; then
  if $FIX; then
    FIX_OUT=$($SSH "$DEST" "$FIX_SCRIPT" 2>/dev/null) || true
    FIXED=$(echo "$FIX_OUT" | grep "^FIXED:" | sed 's/FIXED://')
    echo "OK: $PEER ready (auto-installed:${FIXED:-none})"
  else
    echo "WARN: $PEER missing optional:$OPT_MISSING (use --fix)" >&2
    exit 0  # non-fatal
  fi
else
  echo "OK: $PEER ready"
fi
