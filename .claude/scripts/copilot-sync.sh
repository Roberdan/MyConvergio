#!/usr/bin/env bash
set -euo pipefail

# copilot-sync.sh — Sync Claude Code config with Copilot CLI
# Usage: copilot-sync.sh status|sync

COPILOT_DIR="$HOME/.copilot"
CLAUDE_DIR="$HOME/.claude"
ACTION="${1:-status}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "  ${GREEN}OK${NC} $1"; }
warn() {
	echo -e "  ${YELLOW}DRIFT${NC} $1"
	DRIFT=true
}
fail() {
	echo -e "  ${RED}MISSING${NC} $1"
	DRIFT=true
}

check_file() {
	local path="$1" label="$2"
	[ -f "$path" ] && ok "$label" || fail "$label ($path)"
}

check_model_ref() {
	local file="$1"
	if grep -q "Opus 4.5" "$file" 2>/dev/null; then
		warn "$(basename "$file"): references Opus 4.5 (should be 4.6)"
	elif grep -q "Opus 4.6" "$file" 2>/dev/null; then
		ok "$(basename "$file"): model ref"
	fi
}

status() {
	DRIFT=false
	echo "=== Copilot CLI Alignment Status ==="
	echo ""
	echo "Global Config:"
	check_file "$COPILOT_DIR/config.json" "config.json"
	check_file "$COPILOT_DIR/copilot-instructions.md" "global instructions"
	check_file "$COPILOT_DIR/hooks.json" "hooks.json"
	check_file "$COPILOT_DIR/mcp-config.json" "MCP config"

	echo ""
	echo "Hooks:"
	check_file "$COPILOT_DIR/hooks/enforce-standards.sh" "preToolUse: digest enforcement"
	check_file "$COPILOT_DIR/hooks/worktree-guard.sh" "preToolUse: worktree guard"
	check_file "$COPILOT_DIR/hooks/enforce-line-limit.sh" "postToolUse: line limit"
	check_file "$COPILOT_DIR/hooks/session-tokens.sh" "sessionEnd: token tracking"

	echo ""
	echo "Global Agents:"
	for agent in prompt planner execute validate; do
		check_file "$COPILOT_DIR/agents/${agent}.agent.md" "agent: $agent"
	done

	echo ""
	echo "Model References:"
	for f in "$COPILOT_DIR"/agents/*.agent.md; do
		[ -f "$f" ] && check_model_ref "$f"
	done

	# Check hooks.json completeness
	echo ""
	echo "Hook Types:"
	local hooks_file="$COPILOT_DIR/hooks.json"
	if [ -f "$hooks_file" ]; then
		for hook_type in preToolUse postToolUse sessionEnd; do
			if jq -e ".hooks.${hook_type}" "$hooks_file" >/dev/null 2>&1; then
				ok "hooks.json: $hook_type configured"
			else
				warn "hooks.json: $hook_type NOT configured"
			fi
		done
	fi

	echo ""
	if [ "$DRIFT" = true ]; then
		echo -e "${YELLOW}DRIFT DETECTED${NC} — run: copilot-sync.sh sync"
	else
		echo -e "${GREEN}ALIGNED${NC} — Copilot CLI matches Claude Code config"
	fi
}

sync_config() {
	echo "=== Syncing Copilot CLI Config ==="

	# Ensure directories exist
	mkdir -p "$COPILOT_DIR/hooks" "$COPILOT_DIR/agents"

	# Fix model references in project agents
	# Project-specific agent path - configure per project
	if [ -d "$mb_agents" ]; then
		for f in "$mb_agents"/*.agent.md; do
			if grep -q "Opus 4.5" "$f" 2>/dev/null; then
				sed -i '' 's/Opus 4\.5/Opus 4.6/g' "$f"
				ok "Fixed model ref: $(basename "$f")"
			fi
		done
	fi

	# Ensure hooks are executable
	chmod +x "$COPILOT_DIR/hooks/"*.sh 2>/dev/null || true

	# Verify agent symlinks
	local src="$CLAUDE_DIR/copilot-agents"
	if [ -d "$src" ]; then
		for agent in prompt planner execute validate; do
			local target="$COPILOT_DIR/agents/${agent}.agent.md"
			local source="$src/${agent}.agent.md"
			if [ -f "$source" ] && [ ! -L "$target" ]; then
				ln -sf "$source" "$target"
				ok "Symlinked: $agent"
			fi
		done
	fi

	echo ""
	echo "Sync complete. Run 'copilot-sync.sh status' to verify."
}

case "$ACTION" in
status) status ;;
sync) sync_config ;;
*)
	echo "Usage: copilot-sync.sh status|sync"
	exit 1
	;;
esac
