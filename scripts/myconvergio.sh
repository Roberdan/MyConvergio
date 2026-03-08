#!/bin/bash
# MyConvergio CLI v9.19.0 — Agent management for Claude Code
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
  doctor              Diagnose installation and environment health
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

${YELLOW}More info:${NC}  https://github.com/Roberdan/MyConvergio
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
	git pull --ff-only origin master 2>/dev/null || git pull origin master
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

cmd_doctor() {
	local pass=0 warn=0 fail=0
	pass_msg() { printf "[PASS] %s\n" "$1"; pass=$((pass + 1)); }
	warn_msg() { printf "[WARN] %s\n" "$1"; warn=$((warn + 1)); }
	fail_msg() { printf "[FAIL] %s\n" "$1"; fail=$((fail + 1)); }

	get_tool_version() {
		local tool="$1" out
		case "$tool" in
		git) out="$(git --version 2>/dev/null)" ;;
		make) out="$(make --version 2>/dev/null)" ;;
		bash) out="$(bash --version 2>/dev/null)" ;;
		sqlite3) out="$(sqlite3 --version 2>/dev/null)" ;;
		jq) out="$(jq --version 2>/dev/null)" ;;
		*) out="" ;;
		esac
		printf "%s" "${out%%$'\n'*}"
	}

	check_tool() {
		local tool="$1" optional="${2:-false}" version
		if command -v "$tool" >/dev/null 2>&1; then
			version="$(get_tool_version "$tool")"
			if [ -n "$version" ]; then
				pass_msg "$version"
			else
				pass_msg "$tool installed"
			fi
		elif [ "$optional" = "true" ]; then
			warn_msg "$tool not found — install for full functionality"
		else
			fail_msg "$tool not found"
		fi
	}

	echo "MyConvergio Doctor v$(get_version)"
	echo "─────────────────────────"
	check_tool git
	check_tool make
	check_tool bash
	check_tool sqlite3
	check_tool jq true

	if command -v gh >/dev/null 2>&1; then
		local gh_status gh_user
		gh_status="$(gh auth status 2>&1 || true)"
		if gh auth status >/dev/null 2>&1; then
			gh_user="$(printf "%s\n" "$gh_status" | awk '/Logged in to github.com account/{u=$7} /Active account: true/{print u; exit}')"
			if [ -n "$gh_user" ]; then
				pass_msg "gh authenticated as $gh_user"
			else
				pass_msg "gh authenticated"
			fi
		else
			fail_msg "gh installed but not authenticated"
		fi
	else
		fail_msg "gh not found"
	fi

	local myconv_dir="$HOME/.myconvergio" claude_dir="$CLAUDE_HOME" hooks_dir="$CLAUDE_HOME/hooks" rules_dir="$CLAUDE_HOME/rules"
	if [ -d "$myconv_dir" ]; then
		local scripts_count
		scripts_count="$(find "$myconv_dir" -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
		pass_msg "$HOME/.myconvergio exists (${scripts_count:-0} scripts)"
	else
		fail_msg "$HOME/.myconvergio missing"
	fi
	if [ -d "$claude_dir" ]; then
		pass_msg ".claude exists"
	else
		fail_msg ".claude missing"
	fi
	if [ -d "$hooks_dir" ]; then
		pass_msg "hooks exists"
	else
		fail_msg "hooks missing"
	fi
	if [ -d "$rules_dir" ]; then
		pass_msg "rules exists"
	else
		fail_msg "rules missing"
	fi

	if command -v sqlite3 >/dev/null 2>&1; then
		local db_found=false dbfile integrity db_label
		while IFS= read -r dbfile; do
			[ -z "$dbfile" ] && continue
			db_found=true
			db_label="$dbfile"
			db_label="${db_label#"$myconv_dir"/}"
			db_label="${db_label#"$CLAUDE_HOME"/}"
			integrity="$(sqlite3 "$dbfile" "PRAGMA integrity_check;" 2>/dev/null || true)"
			if [ "$integrity" = "ok" ]; then
				pass_msg "$db_label integrity OK"
			else
				fail_msg "$db_label integrity FAILED"
			fi
		done < <(find "$myconv_dir" "$CLAUDE_HOME" -type f -name '*.db' 2>/dev/null | sort -u)
		[ "$db_found" = false ] && warn_msg "No .db files found for integrity checks"
	else
		warn_msg "Skipping DB integrity checks (sqlite3 unavailable)"
	fi

	if [ -d "$hooks_dir" ]; then
		local hook_total=0 bad_hook=false hookfile
		while IFS= read -r hookfile; do
			[ -z "$hookfile" ] && continue
			hook_total=$((hook_total + 1))
			if [ ! -x "$hookfile" ]; then
				fail_msg "hooks/$(basename "$hookfile") not executable"
				bad_hook=true
			fi
		done < <(find "$hooks_dir" -type f -name '*.sh' 2>/dev/null | sort)
		[ "$hook_total" -eq 0 ] && warn_msg "No hook scripts found in hooks/" || [ "$bad_hook" = false ] && pass_msg "All hook scripts executable ($hook_total)"
	fi

	if [ -f "$VERSION_FILE" ]; then
		if grep -Eq '^SYSTEM_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' "$VERSION_FILE"; then
			pass_msg "VERSION format valid ($(get_version))"
		else
			fail_msg "VERSION format invalid (expected SYSTEM_VERSION=x.y.z)"
		fi
	else
		fail_msg "VERSION file missing"
	fi

	local agents_count=0 copilot_agents_count=0 total_agents
	[ -d "$REPO_ROOT/agents" ] && agents_count="$(find "$REPO_ROOT/agents" -type f 2>/dev/null | wc -l | tr -d ' ')"
	[ -d "$REPO_ROOT/copilot-agents" ] && copilot_agents_count="$(find "$REPO_ROOT/copilot-agents" -type f 2>/dev/null | wc -l | tr -d ' ')"
	total_agents=$((agents_count + copilot_agents_count))
	pass_msg "agents/: ${agents_count:-0}, copilot-agents/: ${copilot_agents_count:-0}, total: $total_agents"

	local install_size
	install_size="$(du -sh "$REPO_ROOT" 2>/dev/null)"
	install_size="${install_size%%$'\t'*}"
	pass_msg "Installation size: $install_size"

	echo "─────────────────────────"
	echo "Result: $pass PASS, $warn WARN, $fail FAIL"
	[ "$fail" -eq 0 ]
}

cmd_backup() {
	local backup_dir
	backup_dir="$HOME/.claude-backup-$(date +%s)"
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
doctor | health) cmd_doctor ;;
settings | hardware) cmd_settings ;;
backup) cmd_backup ;;
restore) cmd_restore "${2:-}" ;;
list-backups | backups) cmd_list_backups ;;
help | -h | --help | *) cmd_help ;;
esac
