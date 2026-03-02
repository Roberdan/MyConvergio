#!/usr/bin/env bash
# mesh-sync-all.sh v1.1.0
# Unified mesh sync: dotclaude (git+SCP) + project repos (git+non-git files) + verify.
# Usage: mesh-sync-all.sh [--dry-run] [--peer NAME] [--phase PHASE] [--force]
#   Phases: all (default), config, repos, verify
#   --force: git reset --hard instead of pull --ff-only (destructive)
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/peers.sh
source "$SCRIPT_DIR/lib/peers.sh"
peers_load 2>/dev/null || true

REPOS_CONF="$CLAUDE_HOME/config/repos.conf"
DRY_RUN=false
TARGET_PEER=""
PHASE="all"
FORCE=false

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--peer)
		TARGET_PEER="${2:-}"
		shift 2
		;;
	--phase)
		PHASE="${2:-all}"
		shift 2
		;;
	--force)
		FORCE=true
		shift
		;;
	-h | --help)
		echo "Usage: mesh-sync-all.sh [--dry-run] [--peer NAME] [--phase all|config|repos|verify] [--force]"
		exit 0
		;;
	*)
		echo "Unknown: $1" >&2
		exit 1
		;;
	esac
done

G='\033[0;32m' R='\033[0;31m' Y='\033[1;33m' C='\033[0;36m' B='\033[1m' N='\033[0m'

SELF_PEER="$(peers_self 2>/dev/null || true)"
if [[ -z "$SELF_PEER" ]]; then
	for _p in $(peers_list); do
		[[ "$(peers_get "$_p" role 2>/dev/null)" == "coordinator" ]] && {
			SELF_PEER="$_p"
			break
		}
	done
fi

# Parse repos.conf → name|path|branch|gh_account|sync_files
parse_repos() {
	[[ ! -f "$REPOS_CONF" ]] && return
	local name="" path="" branch="main" gh_account="" sync_files=""
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%%#*}"
		[[ -z "${line// /}" ]] && continue
		if [[ "$line" =~ ^\[(.+)\]$ ]]; then
			[[ -n "$name" && -n "$path" ]] && echo "$name|$path|$branch|$gh_account|$sync_files"
			name="${BASH_REMATCH[1]}"
			path=""
			branch="main"
			gh_account=""
			sync_files=""
		elif [[ "$line" =~ ^[[:space:]]*path=(.+)$ ]]; then
			path="${BASH_REMATCH[1]}"
		elif [[ "$line" =~ ^[[:space:]]*branch=(.+)$ ]]; then
			branch="${BASH_REMATCH[1]}"
		elif [[ "$line" =~ ^[[:space:]]*gh_account=(.+)$ ]]; then
			gh_account="${BASH_REMATCH[1]}"
		elif [[ "$line" =~ ^[[:space:]]*sync_files=(.+)$ ]]; then
			sync_files="${BASH_REMATCH[1]}"
		fi
	done <"$REPOS_CONF"
	[[ -n "$name" && -n "$path" ]] && echo "$name|$path|$branch|$gh_account|$sync_files"
}

get_targets() {
	for peer in $(peers_list); do
		[[ "$peer" == "$SELF_PEER" ]] && continue
		[[ -n "$TARGET_PEER" && "$peer" != "$TARGET_PEER" ]] && continue
		echo "$peer"
	done
}

peer_dest() {
	local user route
	user="$(peers_get "$1" user 2>/dev/null || true)"
	route="$(peers_best_route "$1" 2>/dev/null || true)"
	[[ -z "$route" ]] && return 1
	echo "${user:+${user}@}${route}"
}

# Phase 1: Push dotclaude config (git bundle + SCP non-git) + dashboard DB
phase_config() {
	echo -e "${B}=== PHASE 1: Config + DB ===${N}"
	if git -C "$CLAUDE_HOME" status --porcelain 2>/dev/null | grep -q .; then
		echo -e "  ${Y}WARN${N}: uncommitted changes in ~/.claude (git bundle won't include them)"
		echo -e "  ${C}INFO${N}: mesh-sync-config.sh will SCP key config files separately"
	fi
	if $DRY_RUN; then
		echo "  (dry-run) Would run: peer-sync.sh push + mesh-sync-config.sh"
	else
		# Git bundle + DB sync (may partially fail — non-fatal)
		"$SCRIPT_DIR/peer-sync.sh" push 2>&1 | sed 's/^/  /' || true
		# SCP non-git config files (models.yaml, peers.conf, scripts)
		echo -e "  ${C}SCP config files...${N}"
		"$SCRIPT_DIR/mesh-sync-config.sh" ${TARGET_PEER:+--peer "$TARGET_PEER"} 2>&1 | sed 's/^/  /' || true
	fi
	echo ""
}

# Phase 2: Pull repos + SCP non-git files (sync_files from repos.conf)
phase_repos() {
	echo -e "${B}=== PHASE 2: Repo Sync ===${N}"
	local repos
	repos="$(parse_repos)"
	if [[ -z "$repos" ]]; then
		echo "  No repos in $REPOS_CONF"
		echo ""
		return
	fi

	local synced=0 failed=0 offline=0

	while IFS= read -r peer <&3 || [[ -n "$peer" ]]; do
		[[ -z "$peer" ]] && continue
		local dest
		dest="$(peer_dest "$peer" 2>/dev/null)" || {
			echo "  $peer: no route"
			continue
		}

		echo -e "  ${C}--- $peer ---${N}"
		if ! ssh -n -o ConnectTimeout=5 -o BatchMode=yes "$dest" true 2>/dev/null; then
			echo -e "    ${R}OFFLINE${N}"
			((offline++)) || true
			continue
		fi

		local peer_ok=true
		while IFS='|' read -r rname rpath rbranch raccount rsyncfiles <&4 || [[ -n "$rname" ]]; do
			[[ -z "$rname" ]] && continue

			# Step A: Git pull
			if $DRY_RUN; then
				echo "    WOULD: $rname → pull origin $rbranch"
				[[ -n "$rsyncfiles" ]] && echo "    WOULD: SCP $rsyncfiles"
				continue
			fi
			local cmd=""
			[[ -n "$raccount" ]] && cmd="gh auth switch --user $raccount 2>&1; "
			if $FORCE; then
				cmd+="cd $rpath && git fetch origin $rbranch 2>&1 && git reset --hard origin/$rbranch 2>&1"
			else
				cmd+="cd $rpath && git pull --ff-only origin $rbranch 2>&1"
			fi
			cmd+=" && echo 'SYNC_OK:'\$(git log --oneline -1)"

			local result
			result=$(ssh -n -o ConnectTimeout=30 "$dest" "$cmd" 2>/dev/null) || true
			if echo "$result" | grep -q '^SYNC_OK:'; then
				echo -e "    ${G}OK${N}: $rname → $(echo "$result" | grep '^SYNC_OK:' | sed 's/^SYNC_OK://')"
			else
				echo -e "    ${R}FAIL${N}: $rname (git)"
				echo "$result" | tail -2 | sed 's/^/      /'
				peer_ok=false
			fi

			# Step B: SCP non-git files (sync_files from repos.conf)
			if [[ -n "$rsyncfiles" ]] && ! $DRY_RUN; then
				local local_repo="${rpath/#\~/$HOME}"
				IFS=',' read -ra files <<<"$rsyncfiles"
				for sf in "${files[@]}"; do
					sf="${sf// /}"
					if [[ -f "$local_repo/$sf" ]]; then
						if scp -o ConnectTimeout=5 "$local_repo/$sf" "$dest:$rpath/$sf" 2>/dev/null; then
							echo -e "    ${G}SCP${N}: $sf"
						else
							echo -e "    ${R}SCP FAIL${N}: $sf"
						fi
					else
						echo -e "    ${Y}SKIP${N}: $sf (not found locally)"
					fi
				done
			fi
		done 4< <(echo "$repos")

		if $peer_ok; then ((synced++)) || true; else ((failed++)) || true; fi
	done 3< <(get_targets)

	echo -e "\n  Summary: ${G}$synced synced${N} | ${R}$failed failed${N} | ${Y}$offline offline${N}\n"
}

# Phase 3: Verify alignment
phase_verify() {
	echo -e "${B}=== VERIFICATION ===${N}"
	local repos repo_names=("dotclaude") repo_local=("$CLAUDE_HOME") repo_remote=("~/.claude")
	repos="$(parse_repos)"

	while IFS='|' read -r rn rp _ _ _ || [[ -n "$rn" ]]; do
		[[ -z "$rn" ]] && continue
		repo_names+=("$rn")
		repo_local+=("${rp/#\~/$HOME}")
		repo_remote+=("$rp")
	done <<<"$repos"

	printf "\n  ${B}%-12s${N}" "PEER"
	for rn in "${repo_names[@]}"; do printf "  %-14s" "$rn"; done
	echo ""
	printf "  %-12s" "────"
	for _ in "${repo_names[@]}"; do printf "  %-14s" "──────────"; done
	echo ""

	local -a local_shas=()
	for lp in "${repo_local[@]}"; do
		local sha
		sha=$(git -C "$lp" log --oneline -1 2>/dev/null | cut -c1-7) || sha="???"
		local_shas+=("$sha")
	done
	printf "  %-12s" "$SELF_PEER"
	for sha in "${local_shas[@]}"; do printf "  ${G}%-14s${N}" "$sha"; done
	echo ""

	while IFS= read -r peer <&3 || [[ -n "$peer" ]]; do
		[[ -z "$peer" ]] && continue
		local dest
		dest="$(peer_dest "$peer" 2>/dev/null)" || continue
		printf "  %-12s" "$peer"
		if ! ssh -n -o ConnectTimeout=5 -o BatchMode=yes "$dest" true 2>/dev/null; then
			for _ in "${repo_names[@]}"; do printf "  ${Y}%-14s${N}" "OFFLINE"; done
			echo ""
			continue
		fi
		local cmd=""
		for rp in "${repo_remote[@]}"; do
			[[ -n "$cmd" ]] && cmd+="; "
			cmd+="git -C $rp log --oneline -1 2>/dev/null | cut -c1-7 || echo '???'"
		done
		local result i=0
		result=$(ssh -n -o ConnectTimeout=10 "$dest" "$cmd" 2>/dev/null) || true
		while IFS= read -r sha; do
			[[ -z "$sha" ]] && sha="???"
			if [[ "${local_shas[$i]:-}" == "$sha" ]]; then
				printf "  ${G}%-14s${N}" "$sha"
			else
				printf "  ${R}%-14s${N}" "$sha"
			fi
			((i++)) || true
		done <<<"$result"
		echo ""
	done 3< <(get_targets)
	echo ""
}

case "$PHASE" in
all)
	phase_config
	phase_repos
	phase_verify
	;;
config | repos | verify) "phase_$PHASE" ;;
*)
	echo "Unknown phase: $PHASE" >&2
	exit 1
	;;
esac
if $DRY_RUN; then echo "(dry-run — no changes made)"; fi
