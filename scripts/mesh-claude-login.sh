#!/usr/bin/env bash
# mesh-claude-login.sh — Remote Claude auth via setup-token
# Version: 2.0.0
# Usage: mesh-claude-login.sh <peer_name|--all> [--token TOKEN]
# Deploys Claude OAuth token to remote peers via SSH.
# Step 1: Run `claude setup-token` locally (interactive, one-time).
# Step 2: This script pushes the token + config to remote peers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
source "$SCRIPT_DIR/lib/peers.sh"

C='\033[0;36m' G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' N='\033[0m'
REMOTE_PATH='export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"'

usage() {
	echo "Usage: $(basename "$0") <peer_name|--all> [--token TOKEN]"
	echo ""
	echo "Deploys Claude Code OAuth token to remote mesh peers."
	echo ""
	echo "Prerequisites:"
	echo "  1. Run 'claude setup-token' locally to generate a long-lived token"
	echo "  2. Copy the token (sk-ant-oat01-...)"
	echo "  3. Run this script with --token or set CLAUDE_CODE_OAUTH_TOKEN env var"
	echo ""
	echo "Options:"
	echo "  --token TOKEN  OAuth token to deploy (or set CLAUDE_CODE_OAUTH_TOKEN)"
	echo "  --all          Deploy to all active peers"
	echo "  --status       Check auth status on all peers"
	echo "  -h, --help     Show this help"
	exit 0
}

check_peer_auth() {
	local name="$1" dest="$2"
	local status
	status="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$dest" \
		"${REMOTE_PATH}; claude auth status 2>&1" 2>/dev/null || echo '{"error":"unreachable"}')"

	local logged_in="no" method="unknown"
	if echo "$status" | python3 -c "import json,sys; d=json.load(sys.stdin); print('yes' if d.get('loggedIn') else 'no')" 2>/dev/null | grep -q "yes"; then
		logged_in="yes"
		method="$(echo "$status" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('authMethod','?'))" 2>/dev/null || echo "?")"
	fi
	printf "%-20s auth=%-4s method=%s\n" "$name" "$logged_in" "$method"
}

deploy_token() {
	local name="$1" token="$2"
	peers_load 2>/dev/null || true

	local target user dest
	target="$(peers_best_route "$name")" || {
		echo -e "${R}No route for $name${N}"
		return 1
	}
	user="$(peers_get "$name" "user" 2>/dev/null || echo "")"
	dest="${user:+${user}@}${target}"

	# Check connectivity
	if ! ssh -n -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
		-o LogLevel=quiet "$dest" true &>/dev/null; then
		echo -e "${R}[$name]${N} Unreachable"
		return 1
	fi

	# Check if Claude CLI exists
	local has_claude
	has_claude="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$dest" \
		"${REMOTE_PATH}; command -v claude &>/dev/null && echo yes || echo no" 2>/dev/null)"
	if [[ "$has_claude" != "yes" ]]; then
		echo -e "${R}[$name]${N} Claude CLI not installed"
		return 1
	fi

	# Check if already authenticated via OAuth (not API key)
	local status
	status="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$dest" \
		"${REMOTE_PATH}; claude auth status 2>&1" 2>/dev/null || echo "{}")"
	local auth_method
	auth_method="$(echo "$status" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('authMethod','none'))" 2>/dev/null || echo "none")"
	if [[ "$auth_method" == "claude.ai" ]]; then
		echo -e "${G}[$name]${N} Already authenticated via OAuth"
		return 0
	fi

	echo -e "${C}[$name]${N} Deploying OAuth token..."

	# Remove any ANTHROPIC_API_KEY from remote env
	ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$dest" \
		'sed -i.bak "/ANTHROPIC_API_KEY/d" ~/.zshrc ~/.zshenv ~/.zprofile ~/.bashrc ~/.bash_profile 2>/dev/null; rm -f ~/.zshrc.bak ~/.zshenv.bak ~/.zprofile.bak ~/.bashrc.bak ~/.bash_profile.bak 2>/dev/null; true' 2>/dev/null || true

	# Deploy token as env var in a dedicated file
	ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$dest" \
		"mkdir -p ~/.claude/config && cat > ~/.claude/config/oauth-token.env && chmod 600 ~/.claude/config/oauth-token.env" \
		<<<"export CLAUDE_CODE_OAUTH_TOKEN=\"${token}\""

	# Source it from shell profile if not already
	ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$dest" \
		'PROFILE="$HOME/.zshenv"; grep -q "oauth-token.env" "$PROFILE" 2>/dev/null || echo "[ -f ~/.claude/config/oauth-token.env ] && source ~/.claude/config/oauth-token.env" >> "$PROFILE"' 2>/dev/null || true

	# Deploy ~/.claude.json for onboarding bypass
	local claude_json="$HOME/.claude.json"
	if [[ -f "$claude_json" ]]; then
		# Create minimal config for remote (skip onboarding)
		python3 -c "
import json, sys
with open('$claude_json') as f:
    d = json.load(f)
minimal = {
    'numStartups': 1,
    'installMethod': d.get('installMethod', 'npm'),
    'autoUpdates': d.get('autoUpdates', False),
    'userID': d.get('userID', ''),
    'lastReleaseNotesSeen': d.get('lastReleaseNotesSeen', ''),
    'projects': {}
}
json.dump(minimal, sys.stdout, indent=2)
" | ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$dest" \
			'cat > ~/.claude.json.tmp && [ -f ~/.claude.json ] || mv ~/.claude.json.tmp ~/.claude.json; rm -f ~/.claude.json.tmp' 2>/dev/null
	fi

	# Verify
	local verify
	verify="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$dest" \
		"${REMOTE_PATH}; source ~/.claude/config/oauth-token.env 2>/dev/null; claude auth status 2>&1" 2>/dev/null || echo "{}")"
	local verify_method
	verify_method="$(echo "$verify" | python3 -c "import json,sys; d=json.load(sys.stdin); m=d.get('authMethod','none'); print(m)" 2>/dev/null || echo "none")"

	if [[ "$verify_method" != "none" ]] && echo "$verify" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('loggedIn') else 1)" 2>/dev/null; then
		echo -e "${G}[$name]${N} Token deployed successfully (method: $verify_method)"
	else
		echo -e "${Y}[$name]${N} Token deployed but verification unclear. Remote status:"
		echo "$verify"
	fi
}

# Parse args
TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}"
TARGET=""
MODE="deploy"

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help) usage ;;
	--status)
		MODE="status"
		shift
		;;
	--token)
		TOKEN="${2:-}"
		shift 2
		;;
	--all)
		TARGET="__all__"
		shift
		;;
	*)
		TARGET="$1"
		shift
		;;
	esac
done

peers_load 2>/dev/null || true

if [[ "$MODE" == "status" ]]; then
	printf "%-20s %-12s %s\n" "PEER" "AUTH" "METHOD"
	printf '%s\n' "$(printf '%.0s-' {1..45})"
	while IFS= read -r name; do
		local_target="$(peers_best_route "$name" 2>/dev/null || echo "")"
		local_user="$(peers_get "$name" "user" 2>/dev/null || echo "")"
		local_dest="${local_user:+${local_user}@}${local_target}"
		check_peer_auth "$name" "$local_dest"
	done < <(peers_others)
	exit 0
fi

if [[ -z "$TARGET" ]]; then
	echo -e "${R}Error: specify peer name or --all${N}"
	usage
fi

if [[ -z "$TOKEN" ]]; then
	echo -e "${Y}No OAuth token provided.${N}"
	echo ""
	echo "To generate a token:"
	echo "  1. Open a NEW terminal (not inside Claude Code)"
	echo "  2. Run: claude setup-token"
	echo "  3. Complete browser auth, copy the token (sk-ant-oat01-...)"
	echo "  4. Re-run: $(basename "$0") $TARGET --token <YOUR_TOKEN>"
	echo ""
	echo "Or set: export CLAUDE_CODE_OAUTH_TOKEN=<token>"
	exit 1
fi

if [[ "$TARGET" == "__all__" ]]; then
	while IFS= read -r name; do
		deploy_token "$name" "$TOKEN"
		echo ""
	done < <(peers_others)
else
	deploy_token "$TARGET" "$TOKEN"
fi
