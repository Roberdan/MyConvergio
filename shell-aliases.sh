#!/bin/bash
# Shell aliases for optimal CLI workflow
# Sourced from ~/.zshrc

# Skip shadow aliases in non-interactive shells (Claude Code, scripts)
# Claude Code uses its own Grep/Glob/Read tools, these aliases only
# cause flag incompatibility errors when Bash tool falls back to grep/find
if [[ ! -o interactive ]]; then
	return 0 2>/dev/null || exit 0
fi

# === Modern tool replacements ===
# These silently use modern tools (no echo messages)
command -v fd &>/dev/null && alias find='fd'
command -v rg &>/dev/null && alias grep='rg'
command -v bat &>/dev/null && alias catp='bat'
command -v dust &>/dev/null && alias du='dust'
command -v delta &>/dev/null && alias diff='delta'
command -v btop &>/dev/null && alias top='btop' && alias htop='btop'

# eza for ls (with icons)
if command -v eza &>/dev/null; then
	alias ls='eza --icons --group-directories-first'
	alias ll='eza -la --icons --group-directories-first --git'
	alias lt='eza --icons --tree --level=2'
	alias la='eza -la --icons'
	alias tree='eza --icons --tree'
fi

# === Claude Code shortcuts ===
alias cc='claude'
alias ccc='claude --continue'
alias ccr='claude --resume'
alias ccw='claude --dangerously-skip-permissions'

# === Quick search functions ===
# fd + fzf for interactive file finding
ff() {
	fd --type f --hidden --exclude .git | fzf --preview 'bat --color=always {}'
}

# rg + fzf for interactive grep
rgi() {
	rg --color=always --line-number --no-heading "$@" |
		fzf --ansi --delimiter ':' --preview 'bat --color=always {1} --highlight-line {2}'
}

# === Code analysis ===
alias loc='tokei'
alias lines='tokei'
alias bench='hyperfine'

# === Claude dashboard shortcuts ===
alias piani='~/.claude/scripts/dashboard-mini.sh'
alias dashboard='~/.claude/scripts/dashboard-mini.sh'

# === Repo info (for Claude context) ===
# Quick repo summary
repo-info() {
	echo "=== $(basename $(pwd)) ==="
	command -v onefetch &>/dev/null && onefetch --no-art 2>/dev/null
	echo ""
	tokei --compact 2>/dev/null || echo "Run: brew install tokei"
}

# Generate .claude-context for Claude's knowledge
repo-index() {
	local out=".claude-context"
	echo "# Repository Context" >"$out"
	echo "Generated: $(date)" >>"$out"
	echo "" >>"$out"
	echo "## Structure" >>"$out"
	eza --tree --level=3 --icons=never >>"$out" 2>/dev/null
	echo "" >>"$out"
	echo "## Languages" >>"$out"
	tokei --compact >>"$out" 2>/dev/null
	echo "" >>"$out"
	echo "## Recent Changes" >>"$out"
	git log --oneline -10 >>"$out" 2>/dev/null
	echo "Created: $out"
}

# === External services (MCP alternatives - saves 21.4k tokens) ===
alias grafana='~/.claude/scripts/grafana-helper.sh'
alias supabase-wrap='~/.claude/scripts/supabase-helper.sh'
alias vercel-wrap='~/.claude/scripts/vercel-helper.sh'

# === Claude config sync (Mac ↔ Linux) ===
alias csync='~/.claude/scripts/sync-claude-config.sh'
