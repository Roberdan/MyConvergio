#!/bin/bash
# Dashboard sync operations and remote git functions
# Version: 2.0.0

# Quick sync: non-blocking. All SSH work runs in background.
# Dashboard renders instantly from local DB + cached remote data.
REMOTE_ONLINE=0
REMOTE_HOST_RESOLVED=""
_BG_SYNC_PID=""

quick_sync() {
	REMOTE_ONLINE=0
	[ ! -x "$SYNC_SCRIPT" ] && return 0
	# Source config to properly expand bash variables (e.g. ${REMOTE_HOST:-omarchy-ts})
	if [ -f "$HOME/.claude/config/sync-db.conf" ]; then
		source "$HOME/.claude/config/sync-db.conf"
	fi
	REMOTE_HOST_RESOLVED="${REMOTE_HOST:-omarchy-ts}"
	local marker="$HOME/.claude/data/last-quick-sync"
	# Check if we have a recent successful sync (marker exists and is fresh)
	if [ -f "$marker" ]; then
		local last now diff
		if [[ "$(uname)" == "Darwin" ]]; then
			last=$(stat -f '%m' "$marker" 2>/dev/null || echo 0)
		else
			last=$(stat -c '%Y' "$marker" 2>/dev/null || echo 0)
		fi
		now=$(date +%s)
		diff=$((now - last))
		if [ "$diff" -lt 120 ]; then
			# Recent sync exists — remote was online
			REMOTE_ONLINE=1
			return 0
		fi
	fi
	# No recent sync: launch background sync (non-blocking)
	# Kill any previous bg sync still running
	if [ -n "$_BG_SYNC_PID" ] && kill -0 "$_BG_SYNC_PID" 2>/dev/null; then
		return 0 # Previous sync still running, skip
	fi
	_bg_sync &
	_BG_SYNC_PID=$!
	disown "$_BG_SYNC_PID" 2>/dev/null || true
	# Use cached data: if marker exists at all, remote was online at some point
	[ -f "$marker" ] && REMOTE_ONLINE=1
}

# Background sync: all SSH work happens here, never blocks the UI.
# With SSH ControlMaster, the first call opens a persistent socket;
# subsequent calls reuse it (~50ms instead of ~1-3s each).
_bg_sync() {
	local marker="$HOME/.claude/data/last-quick-sync"
	# Skip the separate "ssh echo ok" test — just try the sync directly.
	# If SSH fails, the sync script fails silently and we remove the marker.
	if "$SYNC_SCRIPT" incremental &>/dev/null; then
		touch "$marker"
		git -C "$HOME/.claude" push linux main --quiet 2>/dev/null || true
		_fetch_remote_git_status
	else
		rm -f "$marker" 2>/dev/null || true
	fi
}

# Fetch git status from remote for active projects, cache as JSON
_fetch_remote_git_status() {
	[ -z "$REMOTE_HOST_RESOLVED" ] && return 0
	local projects
	projects=$(dbq "SELECT DISTINCT p.project_id FROM plans p WHERE p.status='doing' AND p.execution_host IS NOT NULL AND p.execution_host != ''" 2>/dev/null)
	[ -z "$projects" ] && return 0
	# Build a bash script to run remotely — produces valid JSON per project
	local proj_list="" proj
	while IFS= read -r proj; do
		[ -z "$proj" ] && continue
		proj_list+="$proj "
	done <<<"$projects"
	# Single SSH call, inline script on remote
	# shellcheck disable=SC2086
	local safe_proj_list=""
	for _p in $proj_list; do
		safe_proj_list+="$(printf '%q ' "$_p")"
	done
	ssh -o ConnectTimeout=3 -o BatchMode=yes "$REMOTE_HOST_RESOLVED" bash -s -- $safe_proj_list <<'REMOTE_SCRIPT' >"$REMOTE_GIT_CACHE" 2>/dev/null || true
printf '{'
first=1
for proj in "$@"; do
  [ "$first" -eq 1 ] && first=0 || printf ','
  printf '"%s":' "$proj"
  # Case-insensitive directory match (project_id may differ in case)
  dir=$(find "$HOME/GitHub" -maxdepth 1 -iname "$proj" -type d 2>/dev/null | head -1)
  if [ -n "$dir" ] && { [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; }; then
    cd "$dir"
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
    dirty=$(git status --porcelain 2>/dev/null | head -1)
    clean="true"; [ -n "$dirty" ] && clean="false"
    sha=$(git rev-parse --short HEAD 2>/dev/null || echo "")
    printf '{"branch":"%s","ahead":%s,"behind":%s,"clean":%s,"sha":"%s"}' \
      "$branch" "${ahead:-0}" "${behind:-0}" "$clean" "$sha"
  else
    printf '{}'
  fi
done
printf '}'
REMOTE_SCRIPT
}

# Read cached git field for a project: _get_remote_git <project> <field>
_get_remote_git() {
	local proj="$1" field="$2"
	[ ! -f "$REMOTE_GIT_CACHE" ] && echo "" && return
	jq -r ".[\"$proj\"].$field // empty" "$REMOTE_GIT_CACHE" 2>/dev/null
}

# Get GitHub owner/repo from project directory
_get_owner_repo() {
	local dir="$1"
	local url
	url=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
	[ -z "$url" ] && return
	echo "$url" | sed -E 's|.*github\.com[:/]||; s|\.git$||'
}

# Resolve remote project directory (case-insensitive)
_resolve_remote_dir() {
	ssh -o ConnectTimeout=3 "$REMOTE_HOST_RESOLVED" \
		"find ~/GitHub -maxdepth 1 -iname '$1' -type d 2>/dev/null | head -1" 2>/dev/null
}

# Interactive: push from remote
_remote_push() {
	local proj="$1"
	[ -z "$REMOTE_HOST_RESOLVED" ] && echo -e "${RED}Remote host not configured${NC}" && return 1
	local rdir
	rdir=$(_resolve_remote_dir "$proj")
	[ -z "$rdir" ] && echo -e "${RED}Directory $proj non trovata su Linux${NC}" && return 1
	echo -e "${CYAN}Pushing $proj from Linux ($rdir)...${NC}"
	ssh -o ConnectTimeout=5 "$REMOTE_HOST_RESOLVED" "cd $rdir && git push 2>&1" 2>&1
	echo -e "${GREEN}Done.${NC}"
}

# Interactive: show full remote git status
_remote_git_detail() {
	local proj="$1"
	[ -z "$REMOTE_HOST_RESOLVED" ] && echo -e "${RED}Remote host not configured${NC}" && return 1
	local rdir
	rdir=$(_resolve_remote_dir "$proj")
	[ -z "$rdir" ] && echo -e "${RED}Directory $proj non trovata su Linux${NC}" && return 1
	echo -e "${CYAN}Git status for $proj on Linux ($rdir):${NC}"
	ssh -o ConnectTimeout=5 "$REMOTE_HOST_RESOLVED" "cd $rdir && ~/.claude/scripts/git-digest.sh --full 2>&1" 2>&1
}

# Interactive handler: list remote projects, let user pick, execute action
_handle_remote_action() {
	local action="$1" # "push" or "status"
	if [ "$REMOTE_ONLINE" -eq 0 ]; then
		echo -e "${RED}Linux non raggiungibile${NC}"
		return 1
	fi
	# Get unique remote projects from active plans
	local projects
	projects=$(dbq "SELECT DISTINCT p.project_id FROM plans p WHERE p.status='doing' AND p.execution_host IS NOT NULL AND p.execution_host != ''" 2>/dev/null)
	if [ -z "$projects" ]; then
		echo -e "${YELLOW}Nessun piano remoto attivo${NC}"
		return 0
	fi
	# Build numbered list
	local i=1 proj_array=()
	echo -e "${BOLD}${WHITE}Progetti remoti:${NC}"
	while IFS= read -r proj; do
		[ -z "$proj" ] && continue
		local ahead
		ahead=$(_get_remote_git "$proj" "ahead")
		local indicator=""
		[ "${ahead:-0}" -gt 0 ] && indicator=" ${YELLOW}(↑${ahead} unpushed)${NC}"
		echo -e "  ${CYAN}${i})${NC} ${WHITE}${proj}${NC}${indicator}"
		proj_array+=("$proj")
		((i++))
	done <<<"$projects"
	# Auto-select if only one project
	local choice
	if [ "${#proj_array[@]}" -eq 1 ]; then
		choice=1
	else
		echo -ne "\n${GRAY}Scegli progetto (1-${#proj_array[@]}): ${NC}"
		read -r choice
	fi
	# Validate
	if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#proj_array[@]}" ]; then
		echo -e "${RED}Scelta non valida${NC}"
		return 1
	fi
	local selected="${proj_array[$((choice - 1))]}"
	echo ""
	if [ "$action" = "push" ]; then
		_remote_push "$selected"
	else
		_remote_git_detail "$selected"
	fi
}
