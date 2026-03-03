#!/usr/bin/env bash
# MyConvergio Setup — Interactive installer for the AI agent ecosystem
# Usage: bash scripts/setup.sh [--minimal|--standard|--full]
set -euo pipefail
trap 'echo ""; fail "Setup interrupted"; exit 1' INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${HOME}/.claude"

# Source helper library
if [[ ! -f "$SCRIPT_DIR/lib/setup-lib.sh" ]]; then
  echo "ERROR: lib/setup-lib.sh not found. Run from the MyConvergio repo root." >&2; exit 1
fi
# shellcheck source=lib/setup-lib.sh
source "$SCRIPT_DIR/lib/setup-lib.sh"

# --- Banner ---
show_banner() {
  printf "${CYAN}"
  cat <<'EOF'
  __  __        ____                              _
 |  \/  |_   _ / ___|___  _ ____   _____ _ __ __ _(_) ___
 | |\/| | | | | |   / _ \| '_ \ \ / / _ \ '__/ _` | |/ _ \
 | |  | | |_| | |__| (_) | | | \ V /  __/ | | (_| | | (_) |
 |_|  |_|\__, |\____\___/|_| |_|\_/ \___|_|  \__, |_|\___/
         |___/                                |___/
EOF
  printf "${RESET}\n"
  info "AI Agent Ecosystem Installer"
  echo ""
}

# --- Level selection ---
select_level() {
  local arg="${1:-}"
  case "$arg" in
    --minimal)  LEVEL="minimal"; return ;;
    --standard) LEVEL="standard"; return ;;
    --full)     LEVEL="full"; return ;;
  esac
  printf "${BOLD}Choose installation level:${RESET}\n"
  echo "  1) Minimal  — Claude Code agents, rules, config templates"
  echo "  2) Standard — Agents + scripts + dashboard"
  echo "  3) Full     — Everything + mesh networking, tmux, Tailscale"
  echo ""
  printf "${YELLOW}? ${RESET}Select [1/2/3] (default: 2): "
  read -r choice </dev/tty 2>/dev/null || choice=""
  case "${choice:-2}" in
    1) LEVEL="minimal" ;;
    3) LEVEL="full" ;;
    *) LEVEL="standard" ;;
  esac
  ok "Level: $LEVEL"
  echo ""
}

# --- Dependency installation ---
install_deps() {
  local total=4 current=0
  printf "\n${BOLD}━━━ Dependencies ━━━${RESET}\n"
  step $((++current)) $total "Core tools"
  check_dep git git git
  check_dep ssh openssh-client openssh
  check_dep python3 python3 python@3 "3.9"
  check_dep sqlite3 sqlite3 sqlite

  if [[ "$LEVEL" != "minimal" ]]; then
    step $((++current)) $total "Plan execution"
    check_dep node nodejs node "18.0"
    check_dep npm npm npm
  else step $((++current)) $total "Plan execution (skipped — minimal)"; fi

  if [[ "$LEVEL" == "full" ]]; then
    step $((++current)) $total "Mesh networking"
    check_dep rsync rsync rsync
  else step $((++current)) $total "Mesh networking (skipped)"; fi

  step $((++current)) $total "Optional tools"
  for tool in bat jq yq gh; do
    if command -v "$tool" &>/dev/null; then
      ok "$tool (already installed)"
    elif ask_yn "Install $tool (optional)?"; then
      pkg_install "$tool" "$tool" || warn "Failed to install $tool"
    else info "Skipped $tool"; fi
  done
}

# --- File installation ---
install_files() {
  local total current=0
  case "$LEVEL" in
    minimal)  total=4 ;; standard) total=6 ;; full) total=8 ;; *) total=6 ;;
  esac

  printf "\n${BOLD}━━━ Installing Files ━━━${RESET}\n"

  step $((++current)) $total "Creating directory structure"
  create_dir_structure "$TARGET"

  step $((++current)) $total "Copying agents & rules"
  for dir in agents rules commands; do
    [[ -d "$REPO_ROOT/$dir" ]] && safe_copy "$REPO_ROOT/$dir" "$TARGET/$dir"
  done

  step $((++current)) $total "Copying config templates"
  [[ -d "$REPO_ROOT/config" ]] && safe_copy "$REPO_ROOT/config" "$TARGET/config"
  if [[ -f "$REPO_ROOT/.env.example" ]] && [[ ! -f "$TARGET/.env" ]]; then
    cp "$REPO_ROOT/.env.example" "$TARGET/.env" && ok "Created .env from template"
  fi

  step $((++current)) $total "Setting permissions"
  fix_permissions "$TARGET"

  if [[ "$LEVEL" != "minimal" ]]; then
    step $((++current)) $total "Copying scripts & dashboard"
    [[ -d "$REPO_ROOT/scripts" ]] && safe_copy "$REPO_ROOT/scripts" "$TARGET/scripts"
    [[ -d "$REPO_ROOT/scripts/dashboard_web" ]] && safe_copy "$REPO_ROOT/scripts/dashboard_web" "$TARGET/scripts/dashboard_web"
    fix_permissions "$TARGET/scripts"

    step $((++current)) $total "Peer configuration"
    create_peers_conf "$TARGET"
  fi

  if [[ "$LEVEL" == "full" ]]; then
    step $((++current)) $total "tmux setup"
    setup_tmux

    step $((++current)) $total "Tailscale setup"
    setup_tailscale
  fi
}

# --- Post-install ---
show_next_steps() {
  printf "\n${BOLD}━━━ Next Steps ━━━${RESET}\n"
  info "1. Review config:   ${TARGET}/config/"
  if [[ "$LEVEL" != "minimal" ]]; then
    info "2. Start dashboard:  python3 ${TARGET}/scripts/dashboard_web/server.py"
  fi
  if [[ "$LEVEL" == "full" ]]; then
    info "3. Join mesh:        convergio  (tmux attach)"
    info "4. Connect peers:    tailscale status"
  fi
  info "Docs: ${REPO_ROOT}/docs/"
  echo ""
  ok "Setup complete! 🎉"
}

# --- Main ---
main() {
  show_banner
  detect_platform
  info "Platform: $OS ($ARCH) | Package manager: $PKG_MGR | WSL: $IS_WSL"
  echo ""

  bootstrap_pkg_mgr || { fail "Cannot proceed without a package manager"; exit 1; }

  select_level "${1:-}"
  install_deps
  install_files

  printf "\n${BOLD}━━━ Verification ━━━${RESET}\n"
  verify_install
  show_next_steps
}

main "$@"
