#!/usr/bin/env bash
# mesh-auth-sync.sh — Credential sync from master to mesh peers
# Version: 1.0.0
# Usage: mesh-auth-sync.sh [push|status] [--peer NAME | --all]
# SECURITY DISCLAIMER: Tokens grant full access — only sync to machines you own and control.
# Credentials: Claude (.credentials.json), Copilot (gh auth token pipe), OpenCode, Ollama.
# All transfers via SSH encrypted channel. No plaintext temp files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
source "$SCRIPT_DIR/lib/peers.sh"

C='\033[0;36m' G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' N='\033[0m'
info() { echo -e "${C}[auth-sync]${N} $*"; }
ok() { echo -e "${G}[auth-sync]${N} $*"; }
warn() { echo -e "${Y}[auth-sync]${N} $*" >&2; }
err() { echo -e "${R}[auth-sync]${N} $*" >&2; }

peer_dest() {
	local name="$1"
	local target user
	target="$(peers_best_route "$name")" || {
		err "No route for peer: $name"
		return 1
	}
	user="$(peers_get "$name" "user" 2>/dev/null || echo "")"
	echo "${user:+${user}@}${target}"
}

sync_claude() {
	local dest="$1" peer="$2"
	# Claude uses OAuth via Max subscription — login must be done interactively on each machine.
	# Run `claude login` on the remote peer to authenticate.
	# NEVER sync API keys (ANTHROPIC_API_KEY) — Max subscription only.
	local has_auth
	has_auth="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$dest" \
		'[ -f ~/.claude/.credentials.json ] && echo yes || echo no' 2>/dev/null)"
	if [[ "$has_auth" == "yes" ]]; then
		ok "[$peer] Claude: OAuth credentials present"
	else
		warn "[$peer] Claude: not logged in — run 'claude login' on this machine"
	fi
}

sync_copilot() {
	local dest="$1" peer="$2"
	if ! command -v gh &>/dev/null; then
		warn "[$peer] gh CLI not found, skipping Copilot"
		return 0
	fi
	local token
	token="$(gh auth token 2>/dev/null)" || {
		warn "[$peer] gh auth token failed (not logged in?), skipping"
		return 0
	}
	if [[ -z "$token" ]]; then
		warn "[$peer] Empty Copilot token, skipping"
		return 0
	fi
	info "[$peer] Syncing Copilot token..."
	ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$dest" \
		"export PATH=\"\$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH\"; echo '${token}' | gh auth login --with-token" &&
		ok "[$peer] Copilot token synced" ||
		{
			err "[$peer] Copilot sync failed"
			return 1
		}
}

sync_opencode() {
	local dest="$1" peer="$2"
	local src="$HOME/.config/opencode/config.json"
	if [[ ! -f "$src" ]]; then
		warn "[$peer] OpenCode config not found, skipping"
		return 0
	fi
	info "[$peer] Syncing OpenCode config..."
	ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$dest" "mkdir -p ~/.config/opencode"
	scp -q "$src" "${dest}:~/.config/opencode/config.json" &&
		ok "[$peer] OpenCode config synced" ||
		{
			err "[$peer] OpenCode sync failed"
			return 1
		}
}

sync_ollama() {
	local dest="$1" peer="$2"
	if [[ -z "${OLLAMA_API_KEY:-}" ]]; then
		warn "[$peer] OLLAMA_API_KEY not set, skipping"
		return 0
	fi
	info "[$peer] Syncing Ollama API key..."
	printf 'OLLAMA_API_KEY=%s\n' "$OLLAMA_API_KEY" |
		ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$dest" \
			"mkdir -p ~/.claude/config && cat > ~/.claude/config/ollama.env && chmod 600 ~/.claude/config/ollama.env" &&
		ok "[$peer] Ollama API key synced" ||
		{
			err "[$peer] Ollama sync failed"
			return 1
		}
}

push_peer() {
	local name="$1"
	local dest
	dest="$(peer_dest "$name")" || return 1

	if ! ssh -n -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
		-o LogLevel=quiet "$dest" true &>/dev/null; then
		err "[$name] Peer unreachable"
		return 1
	fi

	info "[$name] Pushing credentials to $dest..."
	sync_claude "$dest" "$name" || true
	sync_copilot "$dest" "$name" || true
	sync_opencode "$dest" "$name" || true
	sync_ollama "$dest" "$name" || true
	ok "[$name] Done."
}

cmd_push() {
	local target_peer="${PEER_FILTER:-}"

	peers_load || return 1

	if [[ -n "$target_peer" ]]; then
		push_peer "$target_peer"
		return
	fi

	local pushed=0 failed=0
	set +e
	while IFS= read -r name; do
		if push_peer "$name"; then
			pushed=$((pushed + 1))
		else
			failed=$((failed + 1))
		fi
	done < <(peers_others)
	set -e

	echo ""
	ok "Push complete: $pushed succeeded, $failed failed"
	[[ "$failed" -eq 0 ]] || return 1
}

status_peer() {
	local name="$1"
	local dest
	dest="$(peer_dest "$name")" || {
		printf "%-20s UNREACHABLE\n" "$name"
		return
	}

	if ! ssh -n -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
		-o LogLevel=quiet "$dest" true &>/dev/null; then
		printf "%-20s OFFLINE\n" "$name"
		return
	fi

	local claude copilot opencode ollama
	claude="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$dest" \
		'[ -f ~/.claude/.credentials.json ] && echo yes || echo no' 2>/dev/null)"
	copilot="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$dest" \
		'export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"; command -v gh &>/dev/null && gh auth status &>/dev/null && echo yes || echo no' 2>/dev/null)"
	opencode="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$dest" \
		'[ -f ~/.config/opencode/config.json ] && echo yes || echo no' 2>/dev/null)"
	ollama="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$dest" \
		'[ -f ~/.claude/config/ollama.env ] && echo yes || echo no' 2>/dev/null)"

	printf "%-20s claude=%-4s copilot=%-4s opencode=%-4s ollama=%s\n" \
		"$name" "${claude:-?}" "${copilot:-?}" "${opencode:-?}" "${ollama:-?}"
}

cmd_status() {
	local target_peer="${PEER_FILTER:-}"

	peers_load || return 1

	printf "%-20s %-12s %-13s %-14s %s\n" "PEER" "CLAUDE" "COPILOT" "OPENCODE" "OLLAMA"
	printf '%s\n' "$(printf '%.0s-' {1..65})"

	if [[ -n "$target_peer" ]]; then
		status_peer "$target_peer"
		return
	fi

	while IFS= read -r name; do
		status_peer "$name"
	done < <(peers_others)
}

SUBCOMMAND="${1:-status}"
shift || true
PEER_FILTER=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--peer)
		PEER_FILTER="${2:-}"
		shift 2
		;;
	--all)
		PEER_FILTER=""
		shift
		;;
	-h | --help)
		echo "Usage: $(basename "$0") [push|status] [--peer NAME|--all]"
		echo "  push   — sync credentials to peer(s)"
		echo "  status — show credential presence table"
		exit 0
		;;
	*)
		err "Unknown option: $1"
		exit 1
		;;
	esac
done

export PEER_FILTER

case "$SUBCOMMAND" in
push) cmd_push ;;
status) cmd_status ;;
*)
	err "Unknown subcommand: $SUBCOMMAND. Use push|status"
	exit 1
	;;
esac
