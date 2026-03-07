#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ALIASES_FILE="$REPO_ROOT/shell-aliases.sh"
AUTO_YES=false
TARGET_SHELL="${SHELL##*/}"
RC_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) AUTO_YES=true ;;
    --shell) TARGET_SHELL="${2:-$TARGET_SHELL}"; shift ;;
    --rc-file) RC_FILE="${2:-}"; shift ;;
    --help|-h)
      echo 'Usage: init-shell.sh [--yes] [--shell bash|zsh] [--rc-file path]'
      exit 0
      ;;
  esac
  shift
done

ask() {
  local prompt="$1" default="${2:-y}" ans=''
  $AUTO_YES && return 0
  printf '%s [%s/%s] ' "$prompt" "${default^^}" "$([ "$default" = y ] && echo n || echo y)"
  read -r ans </dev/tty 2>/dev/null || ans="$default"
  ans="${ans:-$default}"
  [[ "${ans,,}" == y || "${ans,,}" == yes ]]
}

if [[ -z "$RC_FILE" ]]; then
  case "$TARGET_SHELL" in
    zsh) RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *) RC_FILE="$HOME/.profile" ;;
  esac
fi
mkdir -p "$(dirname "$RC_FILE")"
touch "$RC_FILE"

START='# >>> MyConvergio shell init >>>'
END='# <<< MyConvergio shell init <<<'
BLOCK=$(cat <<EOF
$START
export PATH="\$HOME/.local/bin:\$PATH"
if [ -f "$ALIASES_FILE" ]; then
  source "$ALIASES_FILE"
fi
if command -v starship >/dev/null 2>&1; then
  eval "\$(starship init $TARGET_SHELL)"
fi
$END
EOF
)

if grep -qF "$START" "$RC_FILE"; then
  echo "MyConvergio shell block already present in $RC_FILE"
else
  printf '\n%s\n' "$BLOCK" >>"$RC_FILE"
  echo "Updated $RC_FILE"
fi

if ask 'Reload shell config now?' y; then
  echo "Run: source $RC_FILE"
fi
