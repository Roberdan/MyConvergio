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

# === Copilot CLI shortcuts ===
alias cop='copilot'
alias cpy='copilot --yolo'
alias copr='copilot --resume'
cplanner() { ~/.claude/scripts/copilot-planner.sh "$@"; }
cplannerp() { ~/.claude/scripts/copilot-planner.sh --print "$@"; }

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
unalias piani 2>/dev/null; unalias dashboard 2>/dev/null
piani() {
  if ! lsof -i :8420 -sTCP:LISTEN &>/dev/null; then
    nohup ~/.claude/rust/claude-core/target/release/claude-core serve --bind 0.0.0.0:8420 &>/dev/null &
    sleep 1
  fi
  open http://localhost:8420
}
alias dashboard='piani'
alias pianits='~/.claude/scripts/pianits'

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

# === Peer sync shortcuts ===
alias psync='~/.claude/scripts/peer-sync.sh'
alias csync='~/.claude/scripts/sync-claude-config.sh'
alias dbsync='~/.claude/scripts/sync-dashboard-db.sh'

# === Convergio sessions — auto-attach via .zshrc, aliases as shortcuts ===
# With auto-tmux-attach in each node's .zshrc, plain `ssh <node>` already
# lands in the persistent "convergio" tmux session. These aliases are just
# shortcuts for convenience.
alias tl='tmux new-session -A -s convergio'       # local
alias tlm='ssh mac-dev-ts'                         # m1mario
alias tlx='ssh omarchy'                            # omarchy

# === GitHub account switch ===
# Usage: ghs           → toggle between accounts
#        ghs ms        → switch to roberdan_microsoft
#        ghs personal  → switch to Roberdan
GH_ACCT_MS="roberdan_microsoft"
GH_ACCT_PERSONAL="Roberdan"

ghs() {
	local target="$1"
	local current
	current=$(gh auth status 2>&1 | grep "Active account: true" -B3 | grep "account " | awk '{print $NF}' | tr -d '()')

	if [[ -z "$target" ]]; then
		# Toggle: if ms → personal, if personal → ms
		if [[ "$current" == "$GH_ACCT_MS" ]]; then
			target="$GH_ACCT_PERSONAL"
		else
			target="$GH_ACCT_MS"
		fi
	elif [[ "$target" == "ms" || "$target" == "work" ]]; then
		target="$GH_ACCT_MS"
	elif [[ "$target" == "personal" || "$target" == "rob" ]]; then
		target="$GH_ACCT_PERSONAL"
	fi

	if [[ "$current" == "$target" ]]; then
		echo "Already on $target"
		return 0
	fi

	gh auth switch -u "$target" 2>&1
	echo "Switched: $current -> $target"
}

# Show current active GH account
ghw() {
	gh auth status 2>&1 | grep "Active account: true" -B3 | grep "account "
}
