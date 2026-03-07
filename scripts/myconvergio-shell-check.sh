#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_SHELL="${SHELL##*/}"
RC_FILE="$HOME/.profile"
case "$TARGET_SHELL" in
  zsh) RC_FILE="$HOME/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
esac

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "${BLUE}ℹ${NC} $*"; }

missing=0
info "Shell audit (${TARGET_SHELL})"
[ -f "$RC_FILE" ] && ok "RC file: $RC_FILE" || { warn "RC file missing: $RC_FILE"; missing=$((missing + 1)); }

echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin" && ok 'PATH contains ~/.local/bin' || { warn 'PATH missing ~/.local/bin'; missing=$((missing + 1)); }

if [ -f "$RC_FILE" ] && grep -q 'MyConvergio shell init' "$RC_FILE"; then
  ok 'Shell init block present'
else
  warn 'Shell init block missing (run: myconvergio init-shell)'
  missing=$((missing + 1))
fi

[ -f "$REPO_ROOT/shell-aliases.sh" ] && ok 'shell-aliases.sh available' || { fail 'shell-aliases.sh missing'; missing=$((missing + 1)); }
for tool in git python3 sqlite3 claude; do
  command -v "$tool" >/dev/null 2>&1 && ok "$tool installed" || { warn "$tool missing"; missing=$((missing + 1)); }
done
for tool in gh rg fd fzf bat eza delta jq yq starship tmux; do
  command -v "$tool" >/dev/null 2>&1 && ok "$tool installed" || info "$tool optional / not installed"
done

if [ -f "$HOME/.claude/settings.json" ]; then ok '~/.claude/settings.json present'; else warn '~/.claude/settings.json missing'; fi
if [ -f "$HOME/.claude/hooks/enforce-execution-preflight.sh" ]; then ok 'execution preflight hook installed'; else warn 'execution preflight hook missing'; fi

if [ "$missing" -gt 0 ]; then
  echo
  warn "Audit found $missing items to fix"
  exit 1
fi

echo
ok 'Environment looks ready'
