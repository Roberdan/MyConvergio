#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/Roberdan/MyConvergio.git"
INSTALL_DIR="${MYCONVERGIO_HOME:-$HOME/.myconvergio}"
BIN_DIR="$HOME/.local/bin"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${BLUE}$*${NC}"; }
ok() { echo -e "${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
fail() { echo -e "${RED}$*${NC}" >&2; exit 1; }

for cmd in git make bash; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required dependency missing: $cmd"
done

TIER=""
SETUP_ARGS=()
RUN_SETUP=false
for arg in "$@"; do
  case "$arg" in
    --minimal|--standard|--full|--lean) TIER="$arg" ;;
    --setup|--with-shell|--with-devtools|--with-workstation|--yes) RUN_SETUP=true; SETUP_ARGS+=("$arg") ;;
    --help|-h)
      cat <<EOF
Usage: install.sh [tier] [setup flags]

Tiers:
  --minimal | --standard | --full | --lean

Setup flags:
  --setup               Run guided bootstrap after install
  --with-shell          Configure PATH + aliases in shell RC
  --with-devtools       Install recommended CLI tools
  --with-workstation    Full optional workstation bootstrap
  --yes                 Auto-accept recommended choices
EOF
      exit 0
      ;;
  esac
done
[ -n "$TIER" ] && SETUP_ARGS=("$TIER" "${SETUP_ARGS[@]}")

if [ -d "$INSTALL_DIR/.git" ]; then
  info "Upgrading MyConvergio in $INSTALL_DIR..."
  git -C "$INSTALL_DIR" pull --ff-only origin master 2>/dev/null || git -C "$INSTALL_DIR" pull origin master
  if [ -n "$TIER" ]; then
    make -C "$INSTALL_DIR" install-tier TIER="${TIER#--}" --no-print-directory
  else
    make -C "$INSTALL_DIR" upgrade --no-print-directory
  fi
else
  info "Cloning MyConvergio to $INSTALL_DIR..."
  git clone "$REPO_URL" "$INSTALL_DIR"
  if [ -n "$TIER" ]; then
    make -C "$INSTALL_DIR" install-tier TIER="${TIER#--}" --no-print-directory
  else
    make -C "$INSTALL_DIR" install --no-print-directory
  fi
fi

mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/scripts/myconvergio.sh" "$BIN_DIR/myconvergio"
chmod +x "$INSTALL_DIR/scripts/myconvergio.sh"

echo
ok 'MyConvergio installed successfully!'
echo
if ! echo "$PATH" | tr ':' '\n' | grep -q "^${BIN_DIR}$"; then
  warn 'Add to your shell profile (~/.zshrc or ~/.bashrc):'
  echo '  export PATH="$HOME/.local/bin:$PATH"'
  echo
fi

if [ ! -f "$HOME/.claude/settings.json" ]; then
  warn 'Next step: activate hooks by copying a settings template:'
  echo '  cp ~/.myconvergio/.claude/settings-templates/mid-spec.json ~/.claude/settings.json'
  echo
fi

echo 'Commands:'
echo '  myconvergio help'
echo '  myconvergio setup --full --with-workstation'
echo '  myconvergio doctor'
echo

if [ "$RUN_SETUP" = true ]; then
  info 'Running guided setup...'
  "$INSTALL_DIR/scripts/setup.sh" "${SETUP_ARGS[@]}"
fi
