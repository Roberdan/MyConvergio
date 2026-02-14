#!/usr/bin/env bash

# MyConvergio Selective Installation Script
# Allows modular installation with tier, variant, and rules selection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/install-config.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TIER="${TIER:-standard}"
VARIANT="${VARIANT:-full}"
RULES="${RULES:-consolidated}"
TARGET_DIR="${TARGET_DIR:-$HOME/.claude}"
CATEGORIES="${CATEGORIES:-}"
AGENTS="${AGENTS:-}"

# Helper functions
info() { echo -e "${BLUE}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }

usage() {
	cat <<EOF
Usage: $0 [OPTIONS]

Modular installation for MyConvergio agents with context optimization.

OPTIONS:
  -t, --tier TIER           Installation tier: minimal|standard|full (default: standard)
  -v, --variant VARIANT     Agent variant: lean|full (default: full)
  -r, --rules RULES         Rules system: consolidated|detailed|none (default: consolidated)
  -d, --target-dir DIR      Target installation directory (default: ~/.claude)
  -c, --categories CATS     Comma-separated categories to install
  -a, --agents AGENTS       Comma-separated agent names to install
  -l, --list                List available tiers, categories, and agents
  -h, --help                Show this help message

EXAMPLES:
  # Install standard tier with lean agents and consolidated rules
  $0 --tier standard --variant lean --rules consolidated

  # Install only technical development category
  $0 --categories technical_development

  # Install specific agents
  $0 --agents baccio,dario,rex,thor

  # Install minimal tier to custom directory
  $0 --tier minimal --target-dir ./my-claude-agents

  # List all available options
  $0 --list

CONTEXT OPTIMIZATION:
  - Tier minimal:      ~50KB  context (5 agents)
  - Tier standard:     ~200KB context (20 agents)
  - Tier full:         ~600KB context (60 agents)

  - Variant lean:      50% smaller (no Security Framework)
  - Variant full:      Complete documentation

  - Rules consolidated: 93% smaller (3.6KB)
  - Rules detailed:     Full examples (52KB)

For more information: https://github.com/Roberdan/MyConvergio
EOF
	exit 0
}

list_options() {
	info "Available Tiers:"
	jq -r '.tiers | to_entries[] | "  \(.key): \(.value.description)"' "$CONFIG_FILE"

	echo ""
	info "Available Categories:"
	find "$PROJECT_ROOT/.claude/agents" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort

	echo ""
	info "Available Variants:"
	jq -r '.variants | to_entries[] | "  \(.key): \(.value.description)"' "$CONFIG_FILE"

	echo ""
	info "Available Rules:"
	jq -r '.rules | to_entries[] | "  \(.key): \(.value.description)"' "$CONFIG_FILE"

	exit 0
}

get_agents_for_tier() {
	local tier=$1
	jq -r --arg tier "$tier" '.tiers[$tier].agents | if type == "array" then .[] else . end' "$CONFIG_FILE"
}

get_categories_for_tier() {
	local tier=$1
	local cats=$(jq -r --arg tier "$tier" '.tiers[$tier].categories | if type == "array" then .[] else . end' "$CONFIG_FILE")

	if [ "$cats" = "all" ]; then
		find "$PROJECT_ROOT/.claude/agents" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
	else
		echo "$cats"
	fi
}

install_agent() {
	local agent_file=$1
	local target_category=$2

	local agent_name=$(basename "$agent_file" .md | sed 's/\.lean$//')
	local target_path="$TARGET_DIR/agents/$target_category"

	mkdir -p "$target_path"

	if [ "$VARIANT" = "lean" ]; then
		# Check if lean variant exists
		local lean_file="${agent_file%.md}.lean.md"
		if [ -f "$lean_file" ]; then
			cp "$lean_file" "$target_path/$agent_name.md"
			success "Installed $agent_name (lean) → $target_category/"
		else
			warn "Lean variant not found for $agent_name, installing full version"
			cp "$agent_file" "$target_path/$agent_name.md"
			success "Installed $agent_name (full) → $target_category/"
		fi
	else
		cp "$agent_file" "$target_path/$agent_name.md"
		success "Installed $agent_name → $target_category/"
	fi
}

install_category() {
	local category=$1
	local category_path="$PROJECT_ROOT/.claude/agents/$category"

	if [ ! -d "$category_path" ]; then
		error "Category not found: $category"
		return 1
	fi

	info "Installing category: $category"
	local count=0

	for agent_file in "$category_path"/*.md; do
		[ -f "$agent_file" ] || continue
		[[ "$(basename "$agent_file")" =~ \.lean\.md$ ]] && continue

		install_agent "$agent_file" "$category"
		((count++))
	done

	success "Installed $count agents from $category"
}

install_rules() {
	local rules_type=$1

	if [ "$rules_type" = "none" ]; then
		info "Skipping rules installation (none selected)"
		return 0
	fi

	info "Installing rules: $rules_type"
	mkdir -p "$TARGET_DIR/rules"

	local files=$(jq -r --arg type "$rules_type" '.rules[$type].files[]' "$CONFIG_FILE")
	local count=0

	for file in $files; do
		local source_file="$PROJECT_ROOT/.claude/rules/$file"
		if [ -f "$source_file" ]; then
			cp "$source_file" "$TARGET_DIR/rules/$(basename "$file")"
			success "Installed rule: $(basename "$file")"
			((count++))
		else
			warn "Rule file not found: $file"
		fi
	done

	success "Installed $count rule files"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	-t | --tier)
		TIER="$2"
		shift 2
		;;
	-v | --variant)
		VARIANT="$2"
		shift 2
		;;
	-r | --rules)
		RULES="$2"
		shift 2
		;;
	-d | --target-dir)
		TARGET_DIR="$2"
		shift 2
		;;
	-c | --categories)
		CATEGORIES="$2"
		shift 2
		;;
	-a | --agents)
		AGENTS="$2"
		shift 2
		;;
	-l | --list)
		list_options
		;;
	-h | --help)
		usage
		;;
	*)
		error "Unknown option: $1"
		usage
		;;
	esac
done

# Main installation logic
info "MyConvergio Selective Installation"
info "Configuration:"
echo "  Target: $TARGET_DIR"
echo "  Tier: $TIER"
echo "  Variant: $VARIANT"
echo "  Rules: $RULES"

# Validate tier
if ! jq -e --arg tier "$TIER" '.tiers[$tier]' "$CONFIG_FILE" >/dev/null 2>&1; then
	error "Invalid tier: $TIER"
	info "Available tiers: minimal, standard, full"
	exit 1
fi

# Create target directory structure
mkdir -p "$TARGET_DIR/agents"
mkdir -p "$TARGET_DIR/rules"

# Install agents based on selection
if [ -n "$AGENTS" ]; then
	# Install specific agents
	info "Installing specific agents: $AGENTS"
	IFS=',' read -ra AGENT_LIST <<<"$AGENTS"
	for agent_name in "${AGENT_LIST[@]}"; do
		agent_name=$(echo "$agent_name" | xargs) # trim whitespace

		# Find agent file across all categories
		found=false
		for category in "$PROJECT_ROOT/.claude/agents"/*; do
			[ -d "$category" ] || continue
			agent_file="$category/$agent_name.md"
			if [ -f "$agent_file" ]; then
				install_agent "$agent_file" "$(basename "$category")"
				found=true
				break
			fi
		done

		if [ "$found" = false ]; then
			warn "Agent not found: $agent_name"
		fi
	done
elif [ -n "$CATEGORIES" ]; then
	# Install specific categories
	IFS=',' read -ra CAT_LIST <<<"$CATEGORIES"
	for category in "${CAT_LIST[@]}"; do
		category=$(echo "$category" | xargs) # trim whitespace
		install_category "$category"
	done
else
	# Install tier
	info "Installing tier: $TIER"

	tier_cats=$(get_categories_for_tier "$TIER")
	for category in $tier_cats; do
		install_category "$category"
	done
fi

# Install rules
install_rules "$RULES"

# Install hooks (always - token optimization)
if [ -d "$PROJECT_ROOT/hooks" ]; then
	info "Installing hooks..."
	mkdir -p "$TARGET_DIR/hooks/lib"
	cp "$PROJECT_ROOT"/hooks/*.sh "$TARGET_DIR/hooks/" 2>/dev/null || true
	cp "$PROJECT_ROOT"/hooks/lib/*.sh "$TARGET_DIR/hooks/lib/" 2>/dev/null || true
	chmod +x "$TARGET_DIR"/hooks/*.sh "$TARGET_DIR"/hooks/lib/*.sh 2>/dev/null || true
	hooks_count=$(find "$TARGET_DIR/hooks" -name "*.sh" -type f | wc -l | xargs)
	success "Installed $hooks_count hooks"
fi

# Install reference docs (always - on-demand context)
if [ -d "$PROJECT_ROOT/.claude/reference" ]; then
	info "Installing reference docs..."
	mkdir -p "$TARGET_DIR/reference"
	cp -r "$PROJECT_ROOT/.claude/reference/"* "$TARGET_DIR/reference/" 2>/dev/null || true
	success "Installed reference docs"
fi

# Install commands (slash commands)
if [ -d "$PROJECT_ROOT/.claude/commands" ]; then
	info "Installing commands..."
	mkdir -p "$TARGET_DIR/commands"
	cp -r "$PROJECT_ROOT/.claude/commands/"* "$TARGET_DIR/commands/" 2>/dev/null || true
	success "Installed commands"
fi

# Install protocols
if [ -d "$PROJECT_ROOT/.claude/protocols" ]; then
	info "Installing protocols..."
	mkdir -p "$TARGET_DIR/protocols"
	cp -r "$PROJECT_ROOT/.claude/protocols/"* "$TARGET_DIR/protocols/" 2>/dev/null || true
	success "Installed protocols"
fi

# Install settings templates
if [ -d "$PROJECT_ROOT/.claude/settings-templates" ]; then
	info "Installing settings templates..."
	mkdir -p "$TARGET_DIR/settings-templates"
	cp -r "$PROJECT_ROOT/.claude/settings-templates/"* "$TARGET_DIR/settings-templates/" 2>/dev/null || true
	success "Installed settings templates"
fi

success "Installation complete!"
info "Agents installed to: $TARGET_DIR/agents/"
info "Rules installed to: $TARGET_DIR/rules/"

# Show summary
echo ""
info "Installation Summary:"
agent_count=$(find "$TARGET_DIR/agents" -name "*.md" -type f | wc -l | xargs)
rules_count=$(find "$TARGET_DIR/rules" -name "*.md" -type f 2>/dev/null | wc -l | xargs)
echo "  Agents: $agent_count"
echo "  Rules: $rules_count"
echo "  Variant: $VARIANT"

# Estimate context size
context_size="unknown"
case "$TIER" in
minimal)
	context_size="~50KB"
	;;
standard)
	context_size="~200KB"
	;;
full)
	context_size="~600KB"
	;;
esac

if [ "$VARIANT" = "lean" ]; then
	context_size="$context_size (lean: ~50% smaller)"
fi

echo "  Estimated context: $context_size"
