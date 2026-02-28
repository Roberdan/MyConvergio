#!/bin/bash
# MyConvergio Universal Installer
# Usage: curl -sSL https://raw.githubusercontent.com/roberdan/MyConvergio/main/install.sh | bash
# Version: 1.0.0
set -euo pipefail

REPO_URL="https://github.com/roberdan/MyConvergio.git"
INSTALL_DIR="${MYCONVERGIO_HOME:-$HOME/.myconvergio}"
BIN_DIR="$HOME/.local/bin"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}$*${NC}"; }
ok() { echo -e "${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
fail() {
	echo -e "${RED}$*${NC}" >&2
	exit 1
}

# Check dependencies
for cmd in git make bash jq; do
	command -v "$cmd" &>/dev/null || fail "Required: '$cmd' not found. Please install it first."
done

# Parse arguments
TIER=""
for arg in "$@"; do
	case "$arg" in
	--minimal | --standard | --full | --lean) TIER="$arg" ;;
	--help | -h)
		echo "Usage: install.sh [--minimal|--standard|--full|--lean]"
		echo ""
		echo "  --minimal   9 core agents (~50KB)"
		echo "  --standard  20 essential agents (~200KB)"
		echo "  --full      All 65 agents (~600KB) [default]"
		echo "  --lean      Optimized agents (~400KB)"
		exit 0
		;;
	esac
done

echo ""

# Upgrade or fresh install
if [ -d "$INSTALL_DIR/.git" ]; then
	info "Upgrading MyConvergio from $INSTALL_DIR..."
	cd "$INSTALL_DIR"
	git pull --ff-only origin main 2>/dev/null || git pull origin main
	make upgrade --no-print-directory
else
	info "Cloning MyConvergio to $INSTALL_DIR..."
	git clone "$REPO_URL" "$INSTALL_DIR"
	cd "$INSTALL_DIR"

	if [ -n "$TIER" ]; then
		make install-tier TIER="${TIER#--}" --no-print-directory
	else
		make install --no-print-directory
	fi
fi

# Install CLI
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/scripts/myconvergio.sh" "$BIN_DIR/myconvergio"
chmod +x "$INSTALL_DIR/scripts/myconvergio.sh"

echo ""
ok "MyConvergio installed successfully!"
echo ""

# Check if BIN_DIR is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "^${BIN_DIR}$"; then
	warn "Add to your shell profile (~/.zshrc or ~/.bashrc):"
	echo '  export PATH="$HOME/.local/bin:$PATH"'
	echo ""
fi

echo "Commands:"
echo "  myconvergio help      Show all commands"
echo "  myconvergio agents    List installed agents"
echo "  myconvergio upgrade   Update to latest version"
echo ""
