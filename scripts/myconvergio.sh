#!/bin/bash
# MyConvergio CLI v8.1.0 — Agent management for Claude Code
set -euo pipefail

# Resolve symlinks to find repo root
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
	DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
	SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
	[[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$DIR/$SCRIPT_PATH"
done
REPO_ROOT="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"

CLAUDE_HOME="$HOME/.claude"
VERSION_FILE="$REPO_ROOT/VERSION"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

get_version() { grep 'SYSTEM_VERSION=' "$VERSION_FILE" 2>/dev/null | cut -d= -f2 || echo "unknown"; }

cmd_help() {
	cat <<EOF
${BLUE}MyConvergio — Claude Code Agent Suite${NC}

${YELLOW}Usage:${NC}  myconvergio <command> [options]

${YELLOW}Installation:${NC}
  install [--minimal|--standard|--full|--lean]   Install agents to ~/.claude/
  upgrade                                        Update to latest version
  uninstall                                      Remove installed components

${YELLOW}Management:${NC}
  agents              List installed agents with versions
  version             Show version and installation status
  settings            Detect hardware, recommend settings

${YELLOW}Backup & Restore:${NC}
  backup              Create backup of ~/.claude/
  restore <dir>       Restore from backup directory
  list-backups        List available backups

${YELLOW}Options:${NC}
  --minimal   9 core agents (~50KB)
  --standard  20 essential agents (~200KB)
  --full      All 65 agents (~600KB) [default]
  --lean      Optimized agents (~400KB)

${YELLOW}More info:${NC}  https://github.com/roberdan/MyConvergio
EOF
}

cmd_install() {
	local tier="${1:-}"
	case "$tier" in
	--minimal) make -C "$REPO_ROOT" install-tier TIER=minimal --no-print-directory ;;
	--standard) make -C "$REPO_ROOT" install-tier TIER=standard --no-print-directory ;;
	--lean) make -C "$REPO_ROOT" install-tier TIER=lean --no-print-directory ;;
	--full | "") make -C "$REPO_ROOT" install --no-print-directory ;;
	*)
		echo -e "${RED}Unknown option: $tier${NC}"
		cmd_help
		exit 1
		;;
	esac
}

cmd_upgrade() {
	echo -e "${BLUE}Upgrading MyConvergio...${NC}"
	cd "$REPO_ROOT"
	git pull --ff-only origin main 2>/dev/null || git pull origin main
	make upgrade --no-print-directory
	echo -e "\n${GREEN}Upgrade complete! $(get_version)${NC}"
}

cmd_uninstall() {
	make -C "$REPO_ROOT" clean --no-print-directory
	echo -e "${GREEN}Uninstalled. Your ~/.claude/CLAUDE.md was preserved.${NC}"
}

cmd_version() {
	echo -e "${BLUE}MyConvergio v$(get_version)${NC}\n"
	echo -e "${BLUE}Installed Components:${NC}"
	local agents=0 rules=0 skills=0 hooks=0
	[ -d "$CLAUDE_HOME/agents" ] && agents=$(find "$CLAUDE_HOME/agents" -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' -type f 2>/dev/null | wc -l | tr -d ' ')
	[ -d "$CLAUDE_HOME/rules" ] && rules=$(find "$CLAUDE_HOME/rules" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
	[ -d "$CLAUDE_HOME/skills" ] && skills=$(find "$CLAUDE_HOME/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
	[ -d "$CLAUDE_HOME/hooks" ] && hooks=$(find "$CLAUDE_HOME/hooks" -name '*.sh' -type f 2>/dev/null | wc -l | tr -d ' ')
	printf "  Agents: %s\n  Rules:  %s\n  Skills: %s\n  Hooks:  %s\n" \
		"${agents:-0}" "${rules:-0}" "${skills:-0}" "${hooks:-0}"
	echo ""
	echo -e "${BLUE}Source:${NC} $REPO_ROOT"
}

cmd_agents() {
	echo -e "${BLUE}Installed Agents:${NC}\n"
	local agents_dir="$CLAUDE_HOME/agents"
	if [ ! -d "$agents_dir" ]; then
		echo -e "${RED}No agents installed. Run: myconvergio install${NC}"
		return
	fi

	local total=0
	for cat_dir in "$agents_dir"/*/; do
		[ ! -d "$cat_dir" ] && continue
		local cat_name
		cat_name=$(basename "$cat_dir")
		local found=false

		while IFS= read -r agent_file; do
			[ -z "$agent_file" ] && continue
			if [ "$found" = false ]; then
				echo -e "${YELLOW}${cat_name}/${NC}"
				found=true
			fi
			local name
			name=$(basename "$agent_file" .md)
			local ver
			ver=$(grep -m1 '^version:' "$agent_file" 2>/dev/null | sed "s/version:[[:space:]]*[\"']*//;s/[\"']*$//" || echo "?")
			local model
			model=$(grep -m1 '^model:' "$agent_file" 2>/dev/null | sed "s/model:[[:space:]]*[\"']*//;s/[\"']*$//" || echo "haiku")
			printf "  %-45s v%-8s %s\n" "$name" "$ver" "$model"
			((total++))
		done < <(find "$cat_dir" -maxdepth 1 -name '*.md' \
			! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' \
			! -name 'SECURITY_FRAMEWORK_TEMPLATE.md' ! -name 'MICROSOFT_VALUES.md' \
			-type f 2>/dev/null | sort)
	done

	echo -e "\n${GREEN}Total: $total agents${NC}"
}

cmd_settings() {
	local cores mem_gb cpu_model
	cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

	local mem_bytes
	mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
	if [ "$mem_bytes" -gt 0 ] 2>/dev/null; then
		mem_gb=$((mem_bytes / 1073741824))
	else
		mem_gb=$(awk '/MemTotal/ {printf "%d", $2/1048576}' /proc/meminfo 2>/dev/null || echo 8)
	fi

	cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null ||
		grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs ||
		echo "Unknown")

	echo -e "${BLUE}Hardware Detection${NC}\n"
	printf "  CPU:   %s\n  Cores: %s\n  RAM:   %sGB\n\n" "$cpu_model" "$cores" "$mem_gb"

	local profile="mid"
	[ "$mem_gb" -ge 32 ] && [ "$cores" -ge 10 ] && profile="high"
	[ "$mem_gb" -lt 16 ] && profile="low"

	echo -e "${YELLOW}Recommended: ${profile}-spec.json${NC}\n"
	echo "Apply with:"
	echo "  cp $REPO_ROOT/.claude/settings-templates/${profile}-spec.json ~/.claude/settings.json"
	echo ""
	echo "Templates: low-spec (8GB/4c), mid-spec (16GB/8c), high-spec (32GB+/10c+)"
}

cmd_backup() {
	local backup_dir="$HOME/.claude-backup-$(date +%s)"
	local dirs=(agents rules skills hooks reference commands protocols scripts settings-templates templates)
	local has_content=false

	for dir in "${dirs[@]}"; do
		local src="$CLAUDE_HOME/$dir"
		if [ -d "$src" ] && [ "$(ls -A "$src" 2>/dev/null)" ]; then
			has_content=true
			mkdir -p "$backup_dir/$dir"
			cp -r "$src"/* "$backup_dir/$dir/" 2>/dev/null || true
		fi
	done

	if [ "$has_content" = true ]; then
		echo "{\"created\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"version\":\"$(get_version)\"}" >"$backup_dir/MANIFEST.json"
		echo -e "${GREEN}Backup created: $backup_dir${NC}"
	else
		echo -e "${YELLOW}Nothing to backup (empty ~/.claude/)${NC}"
	fi
}

cmd_restore() {
	local backup_dir="${1:-}"
	if [ -z "$backup_dir" ] || [ ! -d "$backup_dir" ]; then
		echo -e "${RED}Usage: myconvergio restore <backup-directory>${NC}"
		echo "  List backups: myconvergio list-backups"
		return 1
	fi
	if [ ! -f "$backup_dir/MANIFEST.json" ]; then
		echo -e "${RED}Invalid backup (MANIFEST.json not found)${NC}"
		return 1
	fi

	echo -e "${BLUE}Creating safety backup first...${NC}"
	cmd_backup

	echo -e "${BLUE}Restoring from: $backup_dir${NC}"
	local dirs=(agents rules skills hooks reference commands protocols scripts settings-templates templates)
	for dir in "${dirs[@]}"; do
		if [ -d "$backup_dir/$dir" ]; then
			mkdir -p "$CLAUDE_HOME/$dir"
			cp -r "$backup_dir/$dir"/* "$CLAUDE_HOME/$dir/" 2>/dev/null || true
		fi
	done
	echo -e "${GREEN}Restore complete!${NC}"
}

cmd_list_backups() {
	local found=false
	for backup in "$HOME"/.claude-backup-*; do
		[ ! -d "$backup" ] && continue
		found=true
		local name ts date_str file_count
		name=$(basename "$backup")
		ts=${name#.claude-backup-}
		date_str=$(date -r "$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null ||
			date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null ||
			echo "unknown")
		file_count=$(find "$backup" -type f | wc -l | tr -d ' ')
		echo -e "${YELLOW}$name${NC}"
		printf "  Date:  %s\n  Files: %s\n  Path:  %s\n\n" "$date_str" "$file_count" "$backup"
	done

	if [ "$found" = false ]; then
		echo -e "${YELLOW}No backups found. Create one: myconvergio backup${NC}"
	fi
}

# Main dispatch
case "${1:-help}" in
install | reinstall)
	shift 2>/dev/null || true
	cmd_install "${1:-}"
	;;
upgrade | update) cmd_upgrade ;;
uninstall | remove) cmd_uninstall ;;
agents | list) cmd_agents ;;
version | -v | --version) cmd_version ;;
settings | hardware) cmd_settings ;;
backup) cmd_backup ;;
restore) cmd_restore "${2:-}" ;;
list-backups | backups) cmd_list_backups ;;
help | -h | --help | *) cmd_help ;;
esac
