#!/usr/bin/env bash
set -euo pipefail
trap 'echo; fail "Setup interrupted"; exit 1' INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${HOME}/.claude"
# shellcheck source=lib/setup-lib.sh
source "$SCRIPT_DIR/lib/setup-lib.sh"

LEVEL=''
AUTO_YES=false
WITH_SHELL=false
WITH_DEVTOOLS=false
WITH_WORKSTATION=false

for arg in "$@"; do
  case "$arg" in
    --minimal|--standard|--full) LEVEL="${arg#--}" ;;
    --lean) LEVEL='standard' ;;
    --yes) AUTO_YES=true ;;
    --with-shell) WITH_SHELL=true ;;
    --with-devtools) WITH_DEVTOOLS=true ;;
    --with-workstation) WITH_WORKSTATION=true ; WITH_SHELL=true ; WITH_DEVTOOLS=true ;;
  esac
done
$AUTO_YES && export SETUP_ASSUME_YES=1

show_banner() {
  printf '%b\n' "$CYAN"
  cat <<'EOF'
  __  __        ____                              _
 |  \/  |_   _ / ___|___  _ ____   _____ _ __ __ _(_) ___
 | |\/| | | | | |   / _ \| '_ \ \ / / _ \ '__/ _` | |/ _ \
 | |  | | |_| | |__| (_) | | | \ V /  __/ | | (_| | | (_) |
 |_|  |_|\__, |\____\___/|_| |_|\_/ \___|_|  \__, |_|\___/
         |___/                                |___/
EOF
  printf '%b\n\n' "$RESET"
}

select_level() {
  [ -n "$LEVEL" ] && return 0
  printf '%s\n' 'Choose installation level:'
  echo '  1) Minimal  — core agents + rules + hooks'
  echo '  2) Standard — agents + scripts + dashboard'
  echo '  3) Full     — standard + mesh + workstation extras'
  printf 'Select [1/2/3] (default: 2): '
  read -r choice </dev/tty 2>/dev/null || choice='2'
  case "${choice:-2}" in 1) LEVEL='minimal' ;; 3) LEVEL='full' ;; *) LEVEL='standard' ;; esac
}

install_deps() {
  printf '\n%s\n' '━━━ Dependencies ━━━'
  check_dep git git git
  check_dep ssh openssh-client openssh
  check_dep python3 python3 python@3 '3.9'
  check_dep sqlite3 sqlite3 sqlite
  if [[ "$LEVEL" != 'minimal' ]]; then
    check_dep node nodejs node '18.0'
    check_dep npm npm npm
  fi
}

install_files() {
  printf '\n%s\n' '━━━ Installing Files ━━━'
  create_dir_structure "$TARGET"
  for dir in agents rules commands; do [[ -d "$REPO_ROOT/$dir" ]] && safe_copy "$REPO_ROOT/$dir" "$TARGET/$dir"; done
  [[ -d "$REPO_ROOT/config" ]] && safe_copy "$REPO_ROOT/config" "$TARGET/config"
  [[ -d "$REPO_ROOT/.claude/scripts" ]] && safe_copy "$REPO_ROOT/.claude/scripts" "$TARGET/scripts"
  [[ -d "$REPO_ROOT/hooks" ]] && safe_copy "$REPO_ROOT/hooks" "$TARGET/hooks"
  [[ -d "$REPO_ROOT/.claude/reference" ]] && safe_copy "$REPO_ROOT/.claude/reference" "$TARGET/reference"
  [[ -d "$REPO_ROOT/.claude/settings-templates" ]] && safe_copy "$REPO_ROOT/.claude/settings-templates" "$TARGET/settings-templates"
  [[ -f "$REPO_ROOT/hooks.json" ]] && cp "$REPO_ROOT/hooks.json" "$TARGET/hooks.json"
  fix_permissions "$TARGET"
  [[ -f "$REPO_ROOT/.env.example" && ! -f "$TARGET/.env" ]] && cp "$REPO_ROOT/.env.example" "$TARGET/.env"
  if [[ "$LEVEL" != 'minimal' ]]; then create_peers_conf "$TARGET"; fi
  if [[ "$LEVEL" == 'full' ]]; then setup_tmux; fi
}

configure_environment() {
  printf '\n%s\n' '━━━ Optional Environment Bootstrap ━━━'
  if $WITH_DEVTOOLS || ask_yn 'Install recommended CLI/dev tools?' n; then
    "$SCRIPT_DIR/install-cli-tools.sh" --profile "$LEVEL" $($AUTO_YES && printf '%s' '--yes') $($WITH_WORKSTATION && printf '%s' '--with-warp')
  fi
  if $WITH_SHELL || ask_yn 'Configure shell PATH + aliases?' y; then
    "$SCRIPT_DIR/init-shell.sh" $($AUTO_YES && printf '%s' '--yes')
  fi
  if $WITH_WORKSTATION && [[ "$OS" != 'windows' ]]; then
    ask_yn 'Install Tailscale for mesh-ready workstation?' n && setup_tailscale || true
  fi
}

show_next_steps() {
  printf '\n%s\n' '━━━ Next Steps ━━━'
  info "Run: myconvergio doctor"
  info "Start dashboard: python3 $TARGET/scripts/dashboard_web/server.py"
  info "Run guided setup again: myconvergio setup --$LEVEL"
  info "Docs: $REPO_ROOT/docs/"
}

main() {
  show_banner
  detect_platform
  bootstrap_pkg_mgr
  select_level
  info "Platform: $OS ($ARCH) | Package manager: $PKG_MGR"
  info "Install level: $LEVEL"
  install_deps
  install_files
  configure_environment
  printf '\n%s\n' '━━━ Verification ━━━'
  verify_install
  "$SCRIPT_DIR/myconvergio-shell-check.sh" || true
  show_next_steps
}

main "$@"
