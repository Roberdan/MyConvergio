#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/setup-lib.sh
source "$SCRIPT_DIR/lib/setup-lib.sh"

detect_platform
bootstrap_pkg_mgr
PROFILE='standard'
AUTO_YES=false
WITH_WARP=false
WITH_PROMPT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:-$PROFILE}"; shift ;;
    --yes) AUTO_YES=true ;;
    --with-warp) WITH_WARP=true ;;
    --with-prompt) WITH_PROMPT=true ;;
    --help|-h)
      echo 'Usage: install-cli-tools.sh [--profile minimal|standard|full] [--with-warp] [--with-prompt] [--yes]'
      exit 0
      ;;
  esac
  shift
done
$AUTO_YES && export SETUP_ASSUME_YES=1

pkg_for() {
  case "$1:$PKG_MGR" in
    bat:apt) echo 'bat' ;;
    fd:apt) echo 'fd-find' ;;
    rg:apt) echo 'ripgrep' ;;
    eza:apt) echo 'eza' ;;
    delta:apt) echo 'git-delta' ;;
    yq:apt) echo 'yq' ;;
    gh:apt) echo 'gh' ;;
    starship:apt) echo 'starship' ;;
    zoxide:apt) echo 'zoxide' ;;
    tokei:apt) echo 'tokei' ;;
    hyperfine:apt) echo 'hyperfine' ;;
    *) echo "$1" ;;
  esac
}

install_one() {
  local cmd="$1" brew_name="${2:-$1}"
  if command -v "$cmd" >/dev/null 2>&1; then ok "$cmd already installed"; return 0; fi
  ask_yn "Install $cmd?" y || { info "Skipped $cmd"; return 0; }
  pkg_install "$(pkg_for "$cmd")" "$brew_name" && ok "$cmd installed" || warn "Failed to install $cmd"
}

printf '\n%s\n' '━━━ MyConvergio CLI Tools ━━━'
for tool in rg fd fzf jq yq gh; do install_one "$tool"; done
[ "$PROFILE" != 'minimal' ] && for tool in bat eza delta zoxide; do install_one "$tool"; done
[ "$PROFILE" = 'full' ] && for tool in tokei hyperfine tmux; do install_one "$tool"; done
if $WITH_PROMPT || ask_yn 'Install starship prompt (optional)?' n; then install_one starship; fi
if $WITH_WARP && [[ "$OS" == 'macos' && "$PKG_MGR" == 'brew' ]]; then brew install --cask warp && ok 'warp installed' || warn 'warp install failed'; fi
