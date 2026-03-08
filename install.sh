#!/bin/bash
# MyConvergio Universal Installer
# Usage: curl -sSL https://raw.githubusercontent.com/Roberdan/MyConvergio/master/install.sh | bash
# Version: 11.0.0
set -euo pipefail

REPO_URL="https://github.com/Roberdan/MyConvergio.git"
INSTALL_DIR="${MYCONVERGIO_HOME:-$HOME/.myconvergio}"
BIN_DIR="$HOME/.local/bin"
TARGET_VERSION="11.0.0"
TIER=""
FORCE_FRESH=false

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { printf "%b%s%b\n" "$BLUE" "$*" "$NC"; }
ok() { printf "%b%s%b\n" "$GREEN" "$*" "$NC"; }
warn() { printf "%b%s%b\n" "$YELLOW" "$*" "$NC"; }
fail() { printf "%b%s%b\n" "$RED" "$*" "$NC" >&2; exit 1; }

require_cmd() {
	local cmd="$1" message="$2"
	command -v "$cmd" >/dev/null 2>&1 || fail "$message"
}

check_prerequisites() {
	require_cmd git "Missing prerequisite: git. Please install git and retry."
	require_cmd make "Missing prerequisite: make. Please install make and retry."
	require_cmd bash "Missing prerequisite: bash. Please install bash and retry."
	require_cmd sqlite3 "Missing prerequisite: sqlite3. Please install sqlite3 and retry."
	require_cmd jq "Missing prerequisite: jq. Please install jq and retry."
	require_cmd gh "GitHub CLI is required for night agent and issue tracking. Install: https://cli.github.com/ then run: gh auth login"
	if ! gh auth status 2>&1 | grep -q "Logged in"; then
		fail "GitHub CLI is required for night agent and issue tracking. Install: https://cli.github.com/ then run: gh auth login"
	fi
}

print_help() {
	echo "Usage: install.sh [--minimal|--standard|--full|--lean] [--force-fresh]"
	echo ""
	echo "  --minimal      9 core agents (~50KB)"
	echo "  --standard     20 essential agents (~200KB)"
	echo "  --full         All 65 agents (~600KB) [default]"
	echo "  --lean         Optimized agents (~400KB)"
	echo "  --force-fresh  Reinstall from scratch for unknown versions"
}

parse_args() {
	for arg in "$@"; do
		case "$arg" in
		--minimal | --standard | --full | --lean) TIER="$arg" ;;
		--force-fresh) FORCE_FRESH=true ;;
		--help | -h)
			print_help
			exit 0
			;;
		*) fail "Unknown option: $arg. Use --help for usage." ;;
		esac
	done
}

extract_version() {
	local version_file="$1" raw
	raw="$(awk 'NF {print; exit}' "$version_file" 2>/dev/null || true)"
	if [[ "$raw" == SYSTEM_VERSION=* ]]; then
		printf "%s" "${raw#SYSTEM_VERSION=}"
	else
		printf "%s" "$raw"
	fi
}

link_cli() {
	mkdir -p "$BIN_DIR"
	ln -sf "$INSTALL_DIR/scripts/myconvergio.sh" "$BIN_DIR/myconvergio"
	chmod +x "$INSTALL_DIR/scripts/myconvergio.sh"
}

run_install_make() {
	if [ -n "$TIER" ]; then
		make install-tier TIER="${TIER#--}" --no-print-directory
	else
		make install --no-print-directory
	fi
}

run_doctor() {
	if [ -x "$INSTALL_DIR/scripts/myconvergio.sh" ]; then
		"$INSTALL_DIR/scripts/myconvergio.sh" doctor
	elif command -v myconvergio >/dev/null 2>&1; then
		myconvergio doctor
	else
		fail "Doctor verification failed: myconvergio command is not available."
	fi
}

show_next_steps() {
	echo ""
	ok "MyConvergio ${TARGET_VERSION} setup completed."
	echo ""
	if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
		warn "Add to your shell profile (~/.zshrc or ~/.bashrc):"
		echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
		echo ""
	fi
	if [ ! -f "$HOME/.claude/settings.json" ]; then
		warn "Next step: activate hooks by copying a settings template:"
		echo "  cp ~/.myconvergio/.claude/settings-templates/low-spec.json  ~/.claude/settings.json   # 8GB RAM"
		echo "  cp ~/.myconvergio/.claude/settings-templates/mid-spec.json  ~/.claude/settings.json   # 16GB RAM"
		echo "  cp ~/.myconvergio/.claude/settings-templates/high-spec.json ~/.claude/settings.json   # 32GB+ RAM"
	else
		info "Existing ~/.claude/settings.json preserved. Review ~/.myconvergio/.claude/settings-templates for updates."
	fi
	echo ""
	echo "Commands:"
	echo "  myconvergio help      Show all commands"
	echo "  myconvergio agents    List installed agents"
	echo "  myconvergio upgrade   Update to latest version"
	echo "  myconvergio doctor    Verify installation health"
}

fresh_install() {
	info "Fresh install detected. Cloning MyConvergio to $INSTALL_DIR..."
	if [ -e "$INSTALL_DIR" ]; then
		fail "Install directory already exists and is not a valid git install: $INSTALL_DIR"
	fi
	git clone "$REPO_URL" "$INSTALL_DIR"
	cd "$INSTALL_DIR"
	run_install_make
	link_cli
	run_doctor
}

upgrade_v11() {
	info "v11.x installation detected in $INSTALL_DIR. Running standard upgrade..."
	cd "$INSTALL_DIR"
	git pull --ff-only origin master 2>/dev/null || git pull origin master
	make upgrade --no-print-directory
	link_cli
	run_doctor
}

migrate_v10() {
	info "v10.x installation detected in $INSTALL_DIR. Starting migration to v11..."
	cd "$INSTALL_DIR"
	info "Pulling latest code (v11) before migration..."
	git fetch origin master
	git checkout master
	git pull --ff-only origin master 2>/dev/null || git pull origin master
	local backup_script="$INSTALL_DIR/scripts/myconvergio-backup.sh"
	local migrate_script="$INSTALL_DIR/scripts/migrate-v10-to-v11.sh"
	[ -x "$backup_script" ] || fail "Mandatory backup script missing or not executable: $backup_script"
	[ -x "$migrate_script" ] || fail "Migration script missing or not executable: $migrate_script"
	"$backup_script"
	"$migrate_script"
	link_cli
	run_doctor
}

handle_unknown_version() {
	local detected="$1"
	warn "Unknown installed version: ${detected:-unknown}."
	if [ "$FORCE_FRESH" = true ]; then
		warn "--force-fresh set. Removing $INSTALL_DIR and proceeding with fresh install."
		rm -rf "$INSTALL_DIR"
		fresh_install
		return
	fi
	fail "Unknown version detected. Run again with --force-fresh to reinstall from scratch."
}

main() {
	check_prerequisites
	parse_args "$@"
	echo ""
	if [ ! -d "$INSTALL_DIR/.git" ]; then
		fresh_install
		show_next_steps
		return
	fi
	local version_file="$INSTALL_DIR/VERSION" detected_version major
	if [ ! -f "$version_file" ]; then
		handle_unknown_version ""
		show_next_steps
		return
	fi
	detected_version="$(extract_version "$version_file")"
	major="${detected_version%%.*}"
	case "$major" in
	10) migrate_v10 ;;
	11) upgrade_v11 ;;
	*) handle_unknown_version "$detected_version" ;;
	esac
	show_next_steps
}

main "$@"
