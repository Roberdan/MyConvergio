#!/usr/bin/env bash
# mesh-env-tools.sh — Tool install functions for mesh-env-setup.sh
# Version: 1.0.0
# Sourced by mesh-env-setup.sh — not intended to be run directly
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

# ---- logging -----------------------------------------------------------------
_log() { echo "[mesh-env] $*"; }
_warn() { echo "[mesh-env] WARN: $*" >&2; }
_ok() { echo "[mesh-env] OK: $*"; }
_skip() { echo "[mesh-env] SKIP: $*"; }

# ---- OS detection ------------------------------------------------------------
detect_os() {
	if [[ "$(uname -s)" == "Darwin" ]]; then
		echo "macos"
	elif [[ -f /etc/debian_version ]]; then
		echo "debian"
	elif [[ -f /etc/redhat-release ]]; then
		echo "redhat"
	else
		echo "unknown"
	fi
}

# ---- package install helpers -------------------------------------------------
_brew_install() {
	local pkg="$1"
	if command -v brew &>/dev/null; then
		brew list "$pkg" &>/dev/null 2>&1 || brew install "$pkg"
	else
		_warn "brew not found — install Homebrew first: https://brew.sh"
		return 1
	fi
}

_apt_install() {
	local pkg="$1"
	if command -v apt-get &>/dev/null; then
		dpkg -l "$pkg" &>/dev/null 2>&1 || sudo apt-get install -y "$pkg"
	else
		_warn "apt-get not found"
		return 1
	fi
}

# ---- tool install (idempotent) -----------------------------------------------
# Tools: bat, eza, fd, rg, jq, sqlite3, tmux, delta, git
install_tools() {
	local os
	os=$(detect_os)
	_log "Installing CLI tools on $os..."

	local tools_macos=(bat eza fd ripgrep jq sqlite tmux git-delta git)
	local tools_apt=(bat eza fd-find ripgrep jq sqlite3 tmux git)

	if [[ "$os" == "macos" ]]; then
		for pkg in "${tools_macos[@]}"; do
			if _brew_install "$pkg" 2>/dev/null; then
				_ok "$pkg"
			else
				_warn "$pkg install failed (skipping)"
			fi
		done
		# delta is installed as git-delta on brew
		command -v delta &>/dev/null || brew link git-delta 2>/dev/null || true
	elif [[ "$os" == "debian" ]]; then
		sudo apt-get update -qq 2>/dev/null || true
		for pkg in "${tools_apt[@]}"; do
			if _apt_install "$pkg" 2>/dev/null; then
				_ok "$pkg"
			else
				_warn "$pkg install failed (skipping)"
			fi
		done
		# delta not in apt — install from GitHub releases
		if ! command -v delta &>/dev/null; then
			_warn "delta not in apt — install manually: https://github.com/dandavison/delta/releases"
		fi
		# eza may need cargo or snap on older debian
		if ! command -v eza &>/dev/null; then
			_warn "eza not in apt — try: cargo install eza"
		fi
	else
		_warn "Unsupported OS ($os) — manual tool installation required"
	fi
}

# ---- AI engines (interactive, each skippable) --------------------------------
_prompt_yn() {
	local msg="$1"
	local answer
	read -r -p "$msg [y/N] " answer
	[[ "${answer,,}" == "y" ]]
}

install_ai_engines() {
	_log "AI engine setup (each step skippable)..."

	# Claude Code CLI
	if ! command -v claude &>/dev/null; then
		_prompt_yn "Install Claude Code CLI?" && npm install -g @anthropic-ai/claude-code || _skip "Claude Code CLI"
	else
		_ok "Claude Code already installed ($(claude --version 2>/dev/null || echo '?'))"
	fi

	# GitHub Copilot CLI
	if ! command -v gh &>/dev/null || ! gh extension list 2>/dev/null | grep -q copilot; then
		_prompt_yn "Install GitHub Copilot CLI?" && {
			command -v gh &>/dev/null || {
				_warn "gh CLI required first"
				true
			}
			gh extension install github/gh-copilot 2>/dev/null || _skip "Copilot CLI"
		} || _skip "Copilot CLI"
	else
		_ok "GitHub Copilot CLI already installed"
	fi

	# OpenCode
	if ! command -v opencode &>/dev/null; then
		_prompt_yn "Install OpenCode?" && npm install -g opencode-ai || _skip "OpenCode"
	else
		_ok "OpenCode already installed"
	fi

	# Ollama
	if ! command -v ollama &>/dev/null; then
		_prompt_yn "Install Ollama?" && {
			if [[ "$(detect_os)" == "macos" ]]; then
				brew install ollama || _skip "Ollama"
			else
				curl -fsSL https://ollama.ai/install.sh | sh || _skip "Ollama"
			fi
		} || _skip "Ollama"
	else
		_ok "Ollama already installed"
	fi
}

# ---- Check: version table ----------------------------------------------------
print_check_table() {
	local tools=(bat eza fd rg jq sqlite3 tmux delta git claude gh ollama)
	printf "\n%-15s %-10s %s\n" "TOOL" "STATUS" "VERSION"
	printf "%-15s %-10s %s\n" "----" "------" "-------"
	for t in "${tools[@]}"; do
		if command -v "$t" &>/dev/null; then
			local ver
			ver=$("$t" --version 2>/dev/null | head -1 | awk '{print $NF}') || ver="?"
			printf "%-15s %-10s %s\n" "$t" "installed" "$ver"
		else
			printf "%-15s %-10s %s\n" "$t" "MISSING" "-"
		fi
	done
	echo ""
}
