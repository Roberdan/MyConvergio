#!/usr/bin/env bash
# MyConvergio setup library — helper functions for setup.sh
# shellcheck disable=SC2034

# --- Colors (safe for bash 3.2+) ---
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

# --- Output helpers ---
info()  { printf "${CYAN}ℹ ${RESET}%s\n" "$*"; }
ok()    { printf "${GREEN}✓ ${RESET}%s\n" "$*"; }
warn()  { printf "${YELLOW}⚠ ${RESET}%s\n" "$*"; }
fail()  { printf "${RED}✗ ${RESET}%s\n" "$*"; }
step()  { printf "${BOLD}[%s/%s]${RESET} %s\n" "$1" "$2" "$3"; }
ask_yn() {
  local prompt="$1" default="${2:-y}"
  if [[ "${SETUP_ASSUME_YES:-0}" == "1" ]]; then
    [[ "$default" == "y" ]]
    return
  fi
  if [[ "$default" == "y" ]]; then prompt="$prompt [Y/n]"; else prompt="$prompt [y/N]"; fi
  printf "${YELLOW}? ${RESET}%s " "$prompt"
  read -r answer </dev/tty 2>/dev/null || answer=""
  answer="${answer:-$default}"
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

# --- Platform detection ---
detect_platform() {
  OS="unknown"; ARCH="$(uname -m)"; PKG_MGR="none"; IS_WSL=false
  case "$(uname -s)" in
    Darwin)  OS="macos" ;;
    Linux)
      OS="linux"
      if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then IS_WSL=true; fi
      ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
  esac
  case "$ARCH" in
    aarch64|arm64) ARCH="arm64" ;;
    x86_64|amd64)  ARCH="x86_64" ;;
  esac
  # Detect package manager
  if command -v brew &>/dev/null; then PKG_MGR="brew"
  elif command -v apt-get &>/dev/null; then PKG_MGR="apt"
  elif command -v dnf &>/dev/null; then PKG_MGR="dnf"
  elif command -v yum &>/dev/null; then PKG_MGR="yum"
  elif command -v pacman &>/dev/null; then PKG_MGR="pacman"
  elif command -v apk &>/dev/null; then PKG_MGR="apk"
  elif command -v winget &>/dev/null; then PKG_MGR="winget"
  elif command -v choco &>/dev/null; then PKG_MGR="choco"
  elif command -v scoop &>/dev/null; then PKG_MGR="scoop"
  fi
}

# --- Package manager bootstrap ---
bootstrap_pkg_mgr() {
  if [[ "$PKG_MGR" != "none" ]]; then ok "Package manager: $PKG_MGR"; return 0; fi
  if [[ "$OS" == "macos" ]]; then
    if ask_yn "Homebrew not found. Install it?"; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { fail "Homebrew install failed"; return 1; }
      PKG_MGR="brew"; ok "Homebrew installed"
    else warn "No package manager — manual installs required"; fi
  elif [[ "$OS" == "windows" ]] && ! $IS_WSL; then
    warn "No package manager (winget/choco/scoop). Consider installing WSL:"
    info "  wsl --install"
    return 1
  else
    fail "No package manager found (apt/dnf/yum/pacman/apk)"
    return 1
  fi
}

# --- Install a package via detected pkg manager ---
pkg_install() {
  local pkg="$1" brew_name="${2:-$1}"
  case "$PKG_MGR" in
    brew)   brew install "$brew_name" 2>/dev/null ;;
    apt)    sudo apt-get install -y "$pkg" 2>/dev/null ;;
    dnf)    sudo dnf install -y "$pkg" 2>/dev/null ;;
    yum)    sudo yum install -y "$pkg" 2>/dev/null ;;
    pacman) sudo pacman -S --noconfirm "$pkg" 2>/dev/null ;;
    apk)    sudo apk add "$pkg" 2>/dev/null ;;
    winget) winget install --accept-source-agreements "$pkg" 2>/dev/null ;;
    choco)  choco install -y "$pkg" 2>/dev/null ;;
    scoop)  scoop install "$pkg" 2>/dev/null ;;
    *) fail "Cannot install $pkg — no package manager"; return 1 ;;
  esac
}

# --- Check a dependency, optionally install ---
check_dep() {
  local cmd="$1" pkg="${2:-$1}" brew_name="${3:-$2}" min_ver="${4:-}"
  if command -v "$cmd" &>/dev/null; then
    local ver
    ver="$("$cmd" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)" || ver="?"
    if [[ -n "$min_ver" ]] && [[ -n "$ver" ]] && [[ "$ver" != "?" ]]; then
      if ! version_gte "$ver" "$min_ver"; then
        warn "$cmd $ver found, need ≥$min_ver"
        if ask_yn "Upgrade $cmd?"; then pkg_install "$pkg" "$brew_name"; fi
        return 0
      fi
    fi
    ok "$cmd ($ver)"; return 0
  fi
  if ask_yn "$cmd not found. Install?"; then
    pkg_install "$pkg" "$brew_name" && ok "$cmd installed" || { fail "Failed to install $cmd"; return 1; }
  else warn "Skipped $cmd"; return 1; fi
}

# --- Version comparison (a.b >= c.d) ---
version_gte() {
  local a_maj a_min b_maj b_min
  a_maj="${1%%.*}"; a_min="${1#*.}"; a_min="${a_min%%.*}"
  b_maj="${2%%.*}"; b_min="${2#*.}"; b_min="${b_min%%.*}"
  (( a_maj > b_maj )) && return 0
  (( a_maj == b_maj && a_min >= b_min )) && return 0
  return 1
}

# --- Create directory structure ---
create_dir_structure() {
  local base="$1"
  local dirs=(agents rules config scripts scripts/lib data logs)
  for d in "${dirs[@]}"; do
    mkdir -p "$base/$d" && ok "Created $base/$d" || fail "Cannot create $base/$d"
  done
}

# --- Copy files with overwrite protection ---
safe_copy() {
  local src="$1" dst="$2"
  if [[ ! -e "$src" ]]; then warn "Source not found: $src"; return 1; fi
  if [[ -e "$dst" ]] && ! ask_yn "  Overwrite $dst?"; then
    info "  Kept existing $dst"; return 0
  fi
  if [[ -d "$src" ]]; then
    cp -R "$src" "$dst" 2>/dev/null && ok "Copied $src → $dst"
  else
    cp "$src" "$dst" 2>/dev/null && ok "Copied $src → $dst"
  fi
}

# --- Set executable on all .sh files ---
fix_permissions() {
  local dir="$1"
  find "$dir" -name '*.sh' -exec chmod +x {} + 2>/dev/null
  ok "Set +x on all .sh files in $dir"
}

# --- tmux setup ---
setup_tmux() {
  if ! command -v tmux &>/dev/null; then
    if ask_yn "tmux not found. Install?"; then
      pkg_install tmux tmux || { fail "tmux install failed"; return 1; }
    else warn "Skipped tmux"; return 1; fi
  fi
  ok "tmux $(tmux -V 2>/dev/null | grep -oE '[0-9.]+' || echo '?')"
  if [[ ! -f "$HOME/.tmux.conf" ]]; then
    cat > "$HOME/.tmux.conf" <<'TMUXCONF'
set -g default-terminal "screen-256color"
set -g mouse on
set -g history-limit 10000
set -g base-index 1
set -g status-style "bg=colour235,fg=colour136"
set -g status-left "#[fg=green]#S "
set -g status-right "#[fg=cyan]%H:%M"
TMUXCONF
    ok "Created ~/.tmux.conf"
  else info "~/.tmux.conf already exists"; fi
  if ! tmux has-session -t Convergio 2>/dev/null; then
    tmux new-session -d -s Convergio 2>/dev/null && ok "Created tmux session 'Convergio'"
  else info "tmux session 'Convergio' already exists"; fi
  add_shell_alias "alias convergio='tmux attach -t Convergio'"
}

# --- Add alias to shell RC if not present ---
add_shell_alias() {
  local alias_line="$1" rc
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]] && ! grep -qF "$alias_line" "$rc"; then
      echo "$alias_line" >> "$rc"
      ok "Added alias to $rc"
    fi
  done
}

# --- Tailscale setup ---
setup_tailscale() {
  if ! command -v tailscale &>/dev/null; then
    if ask_yn "Tailscale not found. Install?"; then
      if [[ "$OS" == "macos" ]]; then
        brew install --cask tailscale 2>/dev/null || { fail "Tailscale install failed"; return 1; }
      else
        pkg_install tailscale tailscale || { fail "Tailscale install failed"; return 1; }
      fi
    else warn "Skipped Tailscale"; return 1; fi
  fi
  ok "Tailscale installed"
  if ! tailscale status &>/dev/null; then
    info "Tailscale not connected. Run: tailscale up"
    if ask_yn "Run 'tailscale up' now?"; then
      sudo tailscale up 2>/dev/null || tailscale up 2>/dev/null || warn "tailscale up failed — run manually"
    fi
  else
    ok "Tailscale connected"
    info "Discovered peers:"
    tailscale status 2>/dev/null | grep -v '^#' | head -10 || true
  fi
}

# --- Create peers.conf from template ---
create_peers_conf() {
  local conf="$1/config/peers.conf"
  if [[ -f "$conf" ]]; then info "peers.conf exists"; return 0; fi
  printf "${YELLOW}? ${RESET}Node name: "; read -r node_name </dev/tty 2>/dev/null || node_name="node-$(hostname -s)"
  printf "${YELLOW}? ${RESET}Role (coordinator/worker/hybrid) [hybrid]: "; read -r role </dev/tty 2>/dev/null || role=""
  role="${role:-hybrid}"
  cat > "$conf" <<EOF
# MyConvergio peer configuration
NODE_NAME="${node_name}"
NODE_ROLE="${role}"
MESH_PORT=9473
SYNC_INTERVAL=30
EOF
  ok "Created peers.conf (node=$node_name, role=$role)"
}

# --- Final verification ---
verify_install() {
  local all_ok=true
  printf "\n${BOLD}━━━ Installation Summary ━━━${RESET}\n"
  for cmd in git ssh python3 sqlite3; do
    if command -v "$cmd" &>/dev/null; then ok "$cmd"; else fail "$cmd"; all_ok=false; fi
  done
  for cmd in node npm rsync tmux tailscale bat jq yq gh; do
    if command -v "$cmd" &>/dev/null; then ok "$cmd (optional)"; else info "$cmd (not installed)"; fi
  done
  printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
  if $all_ok; then ok "All required dependencies met!"; else warn "Some dependencies missing"; fi
}
