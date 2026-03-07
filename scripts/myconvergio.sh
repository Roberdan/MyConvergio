#!/bin/bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
  DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$DIR/$SCRIPT_PATH"
done
REPO_ROOT="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"
CLAUDE_HOME="$HOME/.claude"
VERSION_FILE="$REPO_ROOT/VERSION"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
get_version() { grep 'SYSTEM_VERSION=' "$VERSION_FILE" 2>/dev/null | cut -d= -f2 || echo 'unknown'; }
info() { echo -e "${BLUE}$*${NC}"; }
fail() { echo -e "${RED}$*${NC}" >&2; exit 1; }

cmd_help() {
  cat <<EOF
${BLUE}MyConvergio v$(get_version)${NC}

${YELLOW}Usage:${NC} myconvergio <command> [options]

${YELLOW}Install & bootstrap:${NC}
  install [tier] [setup flags]       Install agents into ~/.claude/
  setup [tier] [flags]               Guided workstation + MyConvergio setup
  doctor                             Verify CLI, shell, hooks, and dashboard prerequisites
  ecosystem-sync [mode] [flags]      Align upstream ~/.claude and repo mirrors

${YELLOW}Environment:${NC}
  shell-check                        Audit shell integration and PATH
  init-shell [--yes]                 Add PATH + aliases + optional prompt init to your shell RC
  install-tools [flags]              Install optional CLI/dev tools
  settings                           Detect hardware and recommend settings profile

${YELLOW}Management:${NC}
  agents                             List installed agents
  version                            Show version and installation status
  upgrade                            Update repo + reinstall
  uninstall                          Remove installed components from ~/.claude/

${YELLOW}Backup & restore:${NC}
  backup | restore <dir> | list-backups

${YELLOW}Examples:${NC}
  myconvergio install --standard
  myconvergio setup --full --with-workstation
  myconvergio setup --minimal --with-shell --with-devtools
  myconvergio install-tools --profile full --with-warp
EOF
}

cmd_install() {
  local args=("$@")
  local tier="--full"
  local extra=()
  for arg in "${args[@]}"; do
    case "$arg" in
      --minimal|--standard|--full|--lean) tier="$arg" ;;
      *) extra+=("$arg") ;;
    esac
  done
  case "$tier" in
    --minimal) make -C "$REPO_ROOT" install-tier TIER=minimal --no-print-directory ;;
    --standard) make -C "$REPO_ROOT" install-tier TIER=standard --no-print-directory ;;
    --lean) make -C "$REPO_ROOT" install-tier TIER=lean --no-print-directory ;;
    --full) make -C "$REPO_ROOT" install --no-print-directory ;;
    *) fail "Unknown install tier: $tier" ;;
  esac
  if [ ${#extra[@]} -gt 0 ]; then
    "$REPO_ROOT/scripts/setup.sh" "$tier" "${extra[@]}"
  fi
}

cmd_setup() {
  exec "$REPO_ROOT/scripts/setup.sh" "$@"
}

cmd_install_tools() {
  exec "$REPO_ROOT/scripts/install-cli-tools.sh" "$@"
}

cmd_ecosystem_sync() {
  exec "$REPO_ROOT/scripts/ecosystem-sync.sh" "$@"
}

cmd_shell_check() {
  exec "$REPO_ROOT/scripts/myconvergio-shell-check.sh" "$@"
}

cmd_init_shell() {
  exec "$REPO_ROOT/scripts/init-shell.sh" "$@"
}

cmd_doctor() {
  info "MyConvergio doctor — $(get_version)"
  echo
  "$REPO_ROOT/scripts/myconvergio-shell-check.sh"
  echo
  if [ -x "$REPO_ROOT/.claude/scripts/project-audit.sh" ]; then
    info "Project audit"
    "$REPO_ROOT/.claude/scripts/project-audit.sh" --project-root "$REPO_ROOT" || true
  fi
}

cmd_upgrade() {
  info 'Upgrading MyConvergio...'
  git -C "$REPO_ROOT" pull --ff-only origin master 2>/dev/null || git -C "$REPO_ROOT" pull origin master
  make -C "$REPO_ROOT" upgrade --no-print-directory
  echo -e "\n${GREEN}Upgrade complete! $(get_version)${NC}"
}

cmd_uninstall() {
  make -C "$REPO_ROOT" clean --no-print-directory
  echo -e "${GREEN}Uninstalled. ~/.claude/CLAUDE.md was preserved.${NC}"
}

cmd_version() {
  echo -e "${BLUE}MyConvergio v$(get_version)${NC}\n"
  echo -e "${BLUE}Installed Components:${NC}"
  local agents=0 rules=0 skills=0 hooks=0
  [ -d "$CLAUDE_HOME/agents" ] && agents=$(find "$CLAUDE_HOME/agents" -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' -type f 2>/dev/null | wc -l | tr -d ' ')
  [ -d "$CLAUDE_HOME/rules" ] && rules=$(find "$CLAUDE_HOME/rules" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
  [ -d "$CLAUDE_HOME/skills" ] && skills=$(find "$CLAUDE_HOME/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  [ -d "$CLAUDE_HOME/hooks" ] && hooks=$(find "$CLAUDE_HOME/hooks" -name '*.sh' -type f 2>/dev/null | wc -l | tr -d ' ')
  printf '  Agents: %s\n  Rules:  %s\n  Skills: %s\n  Hooks:  %s\n\n' "${agents:-0}" "${rules:-0}" "${skills:-0}" "${hooks:-0}"
  echo -e "${BLUE}Source:${NC} $REPO_ROOT"
}

cmd_agents() {
  echo -e "${BLUE}Installed Agents:${NC}\n"
  local agents_dir="$CLAUDE_HOME/agents"
  [ -d "$agents_dir" ] || fail 'No agents installed. Run: myconvergio install'
  local total=0
  for cat_dir in "$agents_dir"/*/; do
    [ ! -d "$cat_dir" ] && continue
    local cat_name found=false
    cat_name=$(basename "$cat_dir")
    while IFS= read -r agent_file; do
      [ -z "$agent_file" ] && continue
      [ "$found" = false ] && echo -e "${YELLOW}${cat_name}/${NC}" && found=true
      local name ver model
      name=$(basename "$agent_file" .md)
      ver=$(grep -m1 '^version:' "$agent_file" 2>/dev/null | sed "s/version:[[:space:]]*[\"']*//;s/[\"']*$//" || echo '?')
      model=$(grep -m1 '^model:' "$agent_file" 2>/dev/null | sed "s/model:[[:space:]]*[\"']*//;s/[\"']*$//" || echo 'haiku')
      printf '  %-45s v%-8s %s\n' "$name" "$ver" "$model"
      total=$((total + 1))
    done < <(find "$cat_dir" -maxdepth 1 -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' ! -name 'SECURITY_FRAMEWORK_TEMPLATE.md' ! -name 'MICROSOFT_VALUES.md' -type f 2>/dev/null | sort)
  done
  echo -e "\n${GREEN}Total: $total agents${NC}"
}

cmd_settings() {
  local cores mem_gb cpu_model mem_bytes profile='mid'
  cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
  mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  if [ "$mem_bytes" -gt 0 ] 2>/dev/null; then mem_gb=$((mem_bytes / 1073741824)); else mem_gb=$(awk '/MemTotal/ {printf "%d", $2/1048576}' /proc/meminfo 2>/dev/null || echo 8); fi
  cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo 'Unknown')
  [ "$mem_gb" -ge 32 ] && [ "$cores" -ge 10 ] && profile='high'
  [ "$mem_gb" -lt 16 ] && profile='low'
  echo -e "${BLUE}Hardware Detection${NC}\n"
  printf '  CPU:   %s\n  Cores: %s\n  RAM:   %sGB\n\n' "$cpu_model" "$cores" "$mem_gb"
  echo -e "${YELLOW}Recommended:${NC} ${profile}-spec.json"
  echo "  cp $REPO_ROOT/.claude/settings-templates/${profile}-spec.json ~/.claude/settings.json"
}

cmd_backup() {
  local backup_dir="$HOME/.claude-backup-$(date +%s)" dirs=(agents rules skills hooks reference commands protocols scripts settings-templates templates)
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
  [ -n "$backup_dir" ] && [ -d "$backup_dir" ] || fail 'Usage: myconvergio restore <backup-directory>'
  [ -f "$backup_dir/MANIFEST.json" ] || fail 'Invalid backup (MANIFEST.json not found)'
  cmd_backup
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
    date_str=$(date -r "$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')
    file_count=$(find "$backup" -type f | wc -l | tr -d ' ')
    echo -e "${YELLOW}$name${NC}"
    printf '  Date:  %s\n  Files: %s\n  Path:  %s\n\n' "$date_str" "$file_count" "$backup"
  done
  [ "$found" = false ] && echo -e "${YELLOW}No backups found. Create one: myconvergio backup${NC}"
}

case "${1:-help}" in
  install|reinstall) shift; cmd_install "$@" ;;
  setup) shift; cmd_setup "$@" ;;
  doctor) shift; cmd_doctor "$@" ;;
  ecosystem-sync) shift; cmd_ecosystem_sync "$@" ;;
  shell-check) shift; cmd_shell_check "$@" ;;
  init-shell) shift; cmd_init_shell "$@" ;;
  install-tools) shift; cmd_install_tools "$@" ;;
  upgrade|update) shift; cmd_upgrade "$@" ;;
  uninstall|remove) shift; cmd_uninstall "$@" ;;
  agents|list) shift; cmd_agents "$@" ;;
  version|-v|--version) shift; cmd_version "$@" ;;
  settings|hardware) shift; cmd_settings "$@" ;;
  backup) shift; cmd_backup "$@" ;;
  restore) shift; cmd_restore "${1:-}" ;;
  list-backups|backups) shift; cmd_list_backups "$@" ;;
  help|-h|--help|*) cmd_help ;;
esac
