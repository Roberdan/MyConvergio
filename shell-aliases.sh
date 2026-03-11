#!/usr/bin/env bash
# Shell aliases for optimal CLI workflow
# Sourced from ~/.zshrc

# Skip shadow aliases in non-interactive shells (Claude Code, scripts)
# Claude Code uses its own Grep/Glob/Read tools, these aliases only
# cause flag incompatibility errors when Bash tool falls back to grep/find
if [[ $- != *i* ]]; then
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
alias bg='buongiorno'

# === Convergio sessions — auto-attach via .zshrc, aliases as shortcuts ===
# With auto-tmux-attach in each node's .zshrc, plain `ssh <node>` already
# lands in the persistent "convergio" tmux session. These aliases are just
# shortcuts for convenience.
alias tl='tmux new-session -A -s convergio'       # local
# tlm: defined as function in .zshrc (tmux + kitty-aware)
# tlx: defined as function in .zshrc (presync + kitty-aware)

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

_buongiorno_mesh_sync() {
	local sync_script="$HOME/.claude/scripts/mesh-sync.sh"

	if [[ ! -x "$sync_script" ]]; then
		echo "    ⚠ mesh-sync.sh non trovato, skip"
		return 1
	fi

	"$sync_script" 2>&1 | tail -5
}

claude_buongiorno() {
	local G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' B='\033[1m' N='\033[0m'
	local start
	start=$(date +%s)
	local -a news=()

	echo ""
	echo -e "${B}☀️  Buongiorno! Aggiorno tutto...${N}"
	echo ""

	echo -e "${C}[1/5]${N} 🤖 Claude Code..."
	if command -v claude >/dev/null 2>&1; then
		local claude_before claude_after
		claude_before=$(claude --version 2>/dev/null)
		if claude update 2>&1 | tail -3; then
			claude_after=$(claude --version 2>/dev/null)
			if [[ "$claude_before" != "$claude_after" ]]; then
				news+=("🤖 Claude Code: ${claude_before} → ${claude_after}")
			else
				echo -e "  ${G}✓${N} già aggiornato (${claude_after})"
			fi
		else
			echo -e "  ${R}✗${N} aggiornamento fallito"
		fi
	else
		echo -e "  ${Y}⚠${N} claude non trovato"
	fi

	echo -e "${C}[2/5]${N} 🐙 GitHub Copilot CLI..."
	if command -v gh >/dev/null 2>&1; then
		local copilot_before copilot_after
		copilot_before=$(gh extension list 2>/dev/null | awk '/copilot/ {print $3; exit}')
		if gh extension upgrade gh-copilot 2>&1 | tail -2; then
			copilot_after=$(gh extension list 2>/dev/null | awk '/copilot/ {print $3; exit}')
			if [[ "$copilot_before" != "$copilot_after" ]]; then
				news+=("🐙 GH Copilot: ${copilot_before} → ${copilot_after}")
			else
				echo -e "  ${G}✓${N} già aggiornato (${copilot_after})"
			fi
		else
			echo -e "  ${R}✗${N} aggiornamento fallito"
		fi
	else
		echo -e "  ${Y}⚠${N} gh non trovato"
	fi

	echo -e "${C}[3/5]${N} 🍺 Homebrew..."
	if command -v brew >/dev/null 2>&1; then
		local outdated
		brew update --quiet 2>/dev/null
		outdated=$(brew outdated 2>/dev/null)
		if [[ -n "$outdated" ]]; then
			local count
			count=$(echo "$outdated" | wc -l | tr -d ' ')
			echo -e "  Aggiorno ${Y}${count}${N} pacchetti..."
			brew upgrade --quiet 2>&1 | tail -5
			news+=("🍺 Homebrew: aggiornati ${count} pacchetti")
		else
			echo -e "  ${G}✓${N} tutto aggiornato"
		fi
		brew cleanup --quiet 2>/dev/null
	else
		echo -e "  ${Y}⚠${N} brew non disponibile su questo host, skip"
	fi

	echo -e "${C}[4/5]${N} 🔧 GitHub CLI & estensioni..."
	if command -v gh >/dev/null 2>&1; then
		gh extension upgrade --all 2>&1 | grep -v "already up to date" | tail -5
		echo -e "  ${G}✓${N} fatto"
	else
		echo -e "  ${Y}⚠${N} gh non trovato"
	fi

	echo -e "${C}[5/5]${N} 🌐 .claude Mesh Sync + aggiornamento peer..."
	_buongiorno_mesh_sync

	if [[ -f "$HOME/.claude/scripts/lib/peers.sh" ]]; then
		# shellcheck source=/dev/null
		source "$HOME/.claude/scripts/lib/peers.sh"
		peers_load 2>/dev/null || true

		local local_peer peer_num peer_total
		local_peer="${CLAUDE_LOCAL_PEER:-$(peers_self 2>/dev/null)}"
		peer_num=0
		peer_total=0

		local _p
		for _p in ${_PEERS_ACTIVE:-}; do
			[[ -n "$local_peer" && "$_p" == "$local_peer" ]] && continue
			peer_total=$((peer_total + 1))
		done

		for _p in ${_PEERS_ACTIVE:-}; do
			[[ -n "$local_peer" && "$_p" == "$local_peer" ]] && continue
			peer_num=$((peer_num + 1))

			local p_route p_user p_dest p_os p_icon
			p_route="$(peers_best_route "$_p" 2>/dev/null || peers_get "$_p" ssh_alias 2>/dev/null)"
			p_user="$(peers_get "$_p" user 2>/dev/null || echo "")"
			p_dest="${p_user:+${p_user}@}${p_route}"
			p_os="$(peers_get "$_p" os 2>/dev/null || echo "linux")"
			p_icon="🐧"
			[[ "$p_os" == "macos" ]] && p_icon="🍎"

			[[ -z "$p_route" ]] && {
				echo -e "  ${C}[${peer_num}/${peer_total}]${N} ${p_icon} ${_p}: ${Y}route mancante, skip${N}"
				continue
			}

			echo -e "  ${C}[${peer_num}/${peer_total}]${N} ${p_icon} ${_p} (${p_os})..."
			if ! ssh -n -o ConnectTimeout=4 -o BatchMode=yes "$p_dest" true 2>/dev/null; then
				echo -e "    ${Y}⚠${N} ${_p} non raggiungibile, skip"
				continue
			fi
			echo -e "    Connesso via ${Y}${p_dest}${N}"

			local RPATH r_claude_ver r_claude_after r_copilot_ver r_copilot_after
			RPATH='export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH";'

			r_claude_ver=$(ssh -n "$p_dest" "${RPATH} claude --version 2>/dev/null" 2>/dev/null)
			if [[ -n "$r_claude_ver" ]]; then
				echo -e "    Claude: ${r_claude_ver}"
				if [[ "$p_os" == "linux" ]]; then
					ssh -n "$p_dest" "${RPATH} command -v npm >/dev/null 2>&1 && sudo npm install -g --force @anthropic-ai/claude-code@latest 2>&1 || echo 'npm missing'" 2>/dev/null | tail -2
				else
					ssh -n "$p_dest" "${RPATH} claude update 2>&1" 2>/dev/null | tail -2
				fi
				r_claude_after=$(ssh -n "$p_dest" "${RPATH} claude --version 2>/dev/null" 2>/dev/null)
				if [[ "$r_claude_ver" != "$r_claude_after" ]]; then
					news+=("${p_icon} Claude ${_p}: ${r_claude_ver} → ${r_claude_after}")
				else
					echo -e "    ${G}✓${N} Claude già aggiornato (${r_claude_after})"
				fi
			fi

			r_copilot_ver=$(ssh -n "$p_dest" "${RPATH} gh extension list 2>/dev/null | awk '/copilot/ {print \\$3; exit}'" 2>/dev/null)
			if [[ -n "$r_copilot_ver" ]]; then
				echo -e "    Copilot: ${r_copilot_ver}"
				ssh -n "$p_dest" "${RPATH} gh extension upgrade gh-copilot 2>&1" 2>/dev/null | tail -2
				r_copilot_after=$(ssh -n "$p_dest" "${RPATH} gh extension list 2>/dev/null | awk '/copilot/ {print \\$3; exit}'" 2>/dev/null)
				if [[ "$r_copilot_ver" != "$r_copilot_after" ]]; then
					news+=("${p_icon} Copilot ${_p}: ${r_copilot_ver} → ${r_copilot_after}")
				else
					echo -e "    ${G}✓${N} Copilot già aggiornato (${r_copilot_after})"
				fi
			fi

			if [[ "$p_os" == "macos" ]]; then
				echo -e "    Homebrew..."
				ssh -n "$p_dest" "${RPATH} command -v brew >/dev/null 2>&1 && brew update --quiet && brew upgrade --quiet && brew cleanup --quiet 2>&1 || echo 'brew missing'" 2>/dev/null | tail -3
				echo -e "    ${G}✓${N} Homebrew aggiornato"
			fi

			news+=("${p_icon} ${_p} allineato")
		done
	fi

	local elapsed
	elapsed=$(( $(date +%s) - start ))
	echo ""
	echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
	if [[ ${#news[@]} -gt 0 ]]; then
		echo -e "${B}📰 Novità di oggi:${N}"
		local item
		for item in "${news[@]}"; do
			echo -e "  • ${item}"
		done
	else
		echo -e "${G}✨ Tutto era già aggiornato!${N}"
	fi
	echo -e "${B}⏱  Completato in ${elapsed}s${N}"
	echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
	echo ""
	echo -e "${G}☕ Buon lavoro, Roberto!${N}"
	echo ""
}

buongiorno() {
	claude_buongiorno "$@"
}
