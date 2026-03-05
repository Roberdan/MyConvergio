#!/usr/bin/env bash
# Version: 1.1.0
set -euo pipefail

# copilot-sync.sh — Sync Claude Code config with Copilot CLI
# Usage: copilot-sync.sh status|sync

COPILOT_DIR="$HOME/.copilot"
CLAUDE_DIR="$HOME/.claude"
ACTION="${1:-status}"
CURRENT_MODEL_VERSION="${CLAUDE_MODEL_VERSION:-4.6}"
PREVIOUS_MODEL_VERSION="4.5"

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
	if grep -q "Opus ${PREVIOUS_MODEL_VERSION}" "$file" 2>/dev/null; then
		warn "$(basename "$file"): references Opus ${PREVIOUS_MODEL_VERSION} (should be ${CURRENT_MODEL_VERSION})"
	elif grep -q "Opus ${CURRENT_MODEL_VERSION}" "$file" 2>/dev/null; then
		ok "$(basename "$file"): model ref"
	fi
}

status() {
	local DRIFT
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
	echo "Core Agents (orchestration pipeline):"
	for agent in prompt planner execute validate; do
		check_file "$COPILOT_DIR/agents/${agent}.agent.md" "agent: $agent"
	done

	echo ""
	echo "Extended Agents (universal):"
	for agent in strategic-planner code-reviewer tdd-executor compliance-checker; do
		check_file "$COPILOT_DIR/agents/${agent}.agent.md" "agent: $agent"
	done

	echo ""
	echo "Model References:"
	for f in "$COPILOT_DIR"/agents/*.agent.md; do
		[ -f "$f" ] && check_model_ref "$f"
	done

	echo ""
	echo "Model Routing:"
	local instructions="$COPILOT_DIR/copilot-instructions.md"
	if [ -f "$instructions" ] && grep -q "Model Routing Table" "$instructions"; then
		ok "Model routing table present in global instructions"
	else
		warn "Model routing table MISSING from global instructions"
	fi

	echo ""
	echo "Symlink Integrity:"
	for f in copilot-instructions.md hooks.json mcp-config.json; do
		if [ -L "$COPILOT_DIR/$f" ]; then
			local target
			target=$(readlink "$COPILOT_DIR/$f")
			if [ -f "$target" ]; then
				ok "$f → $(basename "$(dirname "$target")")/$(basename "$target")"
			else
				fail "$f symlink broken → $target"
			fi
		elif [ -f "$COPILOT_DIR/$f" ]; then
			warn "$f is a regular file (should be symlink to ~/.claude/copilot-config/)"
		else
			fail "$f missing"
		fi
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

	# --- Config files (source of truth: ~/.claude/copilot-config/) ---
	local cfg="$CLAUDE_DIR/copilot-config"
	if [ -d "$cfg" ]; then
		for f in copilot-instructions.md hooks.json mcp-config.json; do
			if [ -f "$cfg/$f" ]; then
				ln -sf "$cfg/$f" "$COPILOT_DIR/$f"
				ok "Config: $f"
			fi
		done
		# Hooks scripts
		if [ -d "$cfg/hooks" ]; then
			for f in "$cfg/hooks/"*.sh; do
				[ -f "$f" ] || continue
				ln -sf "$f" "$COPILOT_DIR/hooks/$(basename "$f")"
				chmod +x "$f"
				ok "Hook: $(basename "$f")"
			done
		fi
	else
		warn "Config source missing: $cfg"
	fi

	# --- Agents (source of truth: ~/.claude/copilot-agents/) ---
	local src="$CLAUDE_DIR/copilot-agents"
	if [ -d "$src" ]; then
		for f in "$src"/*.agent.md; do
			[ -f "$f" ] || continue
			local name
			name=$(basename "$f")
			ln -sf "$f" "$COPILOT_DIR/agents/$name"
			ok "Agent: ${name%.agent.md}"
		done
	else
		warn "Agent source missing: $src"
	fi

	# --- Fix model references in project agents (any repo) ---
	for repo_dir in "$HOME"/GitHub/*/; do
		local agents_dir="${repo_dir}.github/agents"
		if [ -d "$agents_dir" ]; then
			for f in "$agents_dir"/*.agent.md; do
				if grep -q "Opus ${PREVIOUS_MODEL_VERSION}" "$f" 2>/dev/null; then
					sed -i '' "s/Opus ${PREVIOUS_MODEL_VERSION}/Opus ${CURRENT_MODEL_VERSION}/g" "$f" 2>/dev/null ||
						sed -i "s/Opus ${PREVIOUS_MODEL_VERSION}/Opus ${CURRENT_MODEL_VERSION}/g" "$f"
					ok "Fixed model ref: $(basename "$f") ($(basename "$repo_dir"))"
				fi
			done
		fi
	done

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
