#!/usr/bin/env bash
# mesh-sync-all.sh v2.0.0
# Unified mesh sync: dotclaude (git+SCP) + project repos (git+non-git files) + verify.
# v2.0: Bidirectional sync — finds newest commit per repo, pulls from ahead peer, pushes to all.
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

# PATH prefix for SSH non-login shells (Homebrew on macOS not in default PATH)
REMOTE_PATH_PREFIX='export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; '

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

# Phase 1: Bidirectional dotclaude sync (git bundle + SCP non-git) + dashboard DB
phase_config() {
	echo -e "${B}=== PHASE 1: Config + DB (bidirectional) ===${N}"
	if git -C "$CLAUDE_HOME" status --porcelain 2>/dev/null | grep -q .; then
		echo -e "  ${Y}WARN${N}: uncommitted changes — auto-committing..."
		git -C "$CLAUDE_HOME" add -A 2>/dev/null
		git -C "$CLAUDE_HOME" commit -m "chore: auto-commit before mesh sync" --no-verify 2>&1 | sed 's/^/  /' || true
	fi
	if $DRY_RUN; then
		echo "  (dry-run) Would run: bidirectional peer-sync + mesh-sync-config"
		return
	fi

	# Check if any peer is ahead for dotclaude
	local local_ts
	local_ts=$(_local_commit_ts "$CLAUDE_HOME")
	local newest_ts="$local_ts" newest_src="local" newest_dest=""

	while IFS= read -r peer <&3 || [[ -n "$peer" ]]; do
		[[ -z "$peer" ]] && continue
		local dest
		dest="$(peer_dest "$peer" 2>/dev/null)" || continue
		if ! ssh -n -o ConnectTimeout=5 -o BatchMode=yes "$dest" true 2>/dev/null; then
			continue
		fi
		local rts
		rts=$(_remote_commit_ts "$dest" "~/.claude")
		if [[ "$rts" -gt "$newest_ts" ]]; then
			newest_ts="$rts"
			newest_src="$peer"
			newest_dest="$dest"
		fi
	done 3< <(get_targets)

	if [[ "$newest_src" != "local" && -n "$newest_dest" ]]; then
		echo -e "  ${Y}⟵ Pulling dotclaude from $newest_src (ahead)${N}"
		local bundle_file="/tmp/mesh-sync-dotclaude-$$.bundle"
		local remote_bundle="/tmp/mesh-sync-dotclaude-$$.bundle"
		ssh -n -o ConnectTimeout=15 "$newest_dest" \
			"${REMOTE_PATH_PREFIX}cd ~/.claude && git bundle create $remote_bundle HEAD 2>/dev/null && echo BUNDLE_OK" 2>/dev/null | grep -q 'BUNDLE_OK' && \
		scp -o ConnectTimeout=15 "$newest_dest:$remote_bundle" "$bundle_file" 2>/dev/null && {
			if git -C "$CLAUDE_HOME" fetch "$bundle_file" HEAD 2>/dev/null; then
				if $FORCE; then
					git -C "$CLAUDE_HOME" reset --hard FETCH_HEAD 2>/dev/null
				else
					git -C "$CLAUDE_HOME" merge --ff-only FETCH_HEAD 2>/dev/null || \
					echo -e "  ${Y}WARN${N}: ff-only merge failed, use --force to override"
				fi
				echo -e "  ${G}OK${N}: pulled dotclaude from $newest_src"
			fi
		}
		ssh -n "$newest_dest" "rm -f $remote_bundle" 2>/dev/null || true
		rm -f "$bundle_file" 2>/dev/null || true
	else
		echo -e "  ${G}✓ dotclaude: local is newest${N}"
	fi

	# Push to all peers
	"$SCRIPT_DIR/peer-sync.sh" push 2>&1 | sed 's/^/  /' || true
	echo -e "  ${C}SCP config files...${N}"
	"$SCRIPT_DIR/mesh-sync-config.sh" ${TARGET_PEER:+--peer "$TARGET_PEER"} 2>&1 | sed 's/^/  /' || true
	echo ""
}

# Get commit timestamp (unix epoch) for a local repo
_local_commit_ts() {
	git -C "$1" log -1 --format='%ct' 2>/dev/null || echo "0"
}

# Get commit timestamp from a remote peer via SSH
_remote_commit_ts() {
	local dest="$1" rpath="$2"
	ssh -n -o ConnectTimeout=10 -o BatchMode=yes "$dest" \
		"${REMOTE_PATH_PREFIX}git -C $rpath log -1 --format='%ct' 2>/dev/null || echo 0" 2>/dev/null || echo "0"
}

# Phase 2: Bidirectional repo sync — find newest, pull if behind, push to all
phase_repos() {
	echo -e "${B}=== PHASE 2: Repo Sync (bidirectional) ===${N}"
	local repos
	repos="$(parse_repos)"
	if [[ -z "$repos" ]]; then
		echo "  No repos in $REPOS_CONF"
		echo ""
		return
	fi

	# Build list of online peers with their SSH destinations
	local -a online_peers=() online_dests=()
	local offline=0
	while IFS= read -r peer <&3 || [[ -n "$peer" ]]; do
		[[ -z "$peer" ]] && continue
		local dest
		dest="$(peer_dest "$peer" 2>/dev/null)" || {
			echo -e "  ${Y}$peer${N}: no route"
			continue
		}
		if ssh -n -o ConnectTimeout=5 -o BatchMode=yes "$dest" true 2>/dev/null; then
			online_peers+=("$peer")
			online_dests+=("$dest")
		else
			echo -e "  ${Y}$peer${N}: OFFLINE"
			((offline++)) || true
		fi
	done 3< <(get_targets)

	if [[ ${#online_peers[@]} -eq 0 ]]; then
		echo -e "  ${Y}No online peers — nothing to sync${N}\n"
		return
	fi

	local synced=0 failed=0 pulled=0

	# For each repo: find newest commit, pull if behind, push to all
	while IFS='|' read -r rname rpath rbranch raccount rsyncfiles <&4 || [[ -n "$rname" ]]; do
		[[ -z "$rname" ]] && continue
		local local_repo="${rpath/#\~/$HOME}"

		echo -e "\n  ${C}▸ $rname${N} ($rpath @ $rbranch)"

		if $DRY_RUN; then
			echo "    WOULD: compare timestamps and sync bidirectionally"
			continue
		fi

		# Collect HEAD timestamps: local + all online peers
		local local_ts
		local_ts=$(_local_commit_ts "$local_repo")
		local newest_ts="$local_ts" newest_src="local" newest_dest=""
		local local_sha
		local_sha=$(git -C "$local_repo" log --oneline -1 2>/dev/null | cut -c1-7)
		echo -e "    local: ${G}${local_sha:-???}${N} (ts=$local_ts)"

		for idx in "${!online_peers[@]}"; do
			local p="${online_peers[$idx]}" d="${online_dests[$idx]}"
			local rts
			rts=$(_remote_commit_ts "$d" "$rpath")
			local rsha
			rsha=$(ssh -n -o ConnectTimeout=10 -o BatchMode=yes "$d" \
				"${REMOTE_PATH_PREFIX}git -C $rpath log --oneline -1 2>/dev/null | cut -c1-7" 2>/dev/null) || rsha="???"
			echo -e "    $p: ${G}${rsha}${N} (ts=$rts)"
			if [[ "$rts" -gt "$newest_ts" ]]; then
				newest_ts="$rts"
				newest_src="$p"
				newest_dest="$d"
			fi
		done

		# If a peer is ahead, pull from it first
		if [[ "$newest_src" != "local" && -n "$newest_dest" ]]; then
			echo -e "    ${Y}⟵ PULL from $newest_src (ahead)${N}"
			local pull_cmd="$REMOTE_PATH_PREFIX"
			[[ -n "$raccount" ]] && pull_cmd+="gh auth switch --user $raccount 2>&1; "
			# Create a bundle on the ahead peer and fetch it locally
			local bundle_file="/tmp/mesh-sync-${rname}-$$.bundle"
			local remote_bundle="/tmp/mesh-sync-${rname}-$$.bundle"
			local bundle_ok=false

			# Try 1: git bundle from remote peer
			ssh -n -o ConnectTimeout=15 "$newest_dest" \
				"${REMOTE_PATH_PREFIX}cd $rpath && git bundle create $remote_bundle $rbranch 2>/dev/null && echo BUNDLE_OK" 2>/dev/null | grep -q 'BUNDLE_OK' && \
			scp -o ConnectTimeout=15 "$newest_dest:$remote_bundle" "$bundle_file" 2>/dev/null && \
			bundle_ok=true
			ssh -n "$newest_dest" "rm -f $remote_bundle" 2>/dev/null || true

			if $bundle_ok && [[ -f "$bundle_file" ]]; then
				if git -C "$local_repo" fetch "$bundle_file" "$rbranch" 2>/dev/null; then
					if $FORCE; then
						git -C "$local_repo" reset --hard FETCH_HEAD 2>/dev/null
					else
						git -C "$local_repo" merge --ff-only FETCH_HEAD 2>/dev/null
					fi
					local new_sha
					new_sha=$(git -C "$local_repo" log --oneline -1 2>/dev/null | cut -c1-7)
					echo -e "    ${G}OK${N}: pulled → ${new_sha}"
					((pulled++)) || true
				else
					echo -e "    ${R}FAIL${N}: git fetch from bundle"
				fi
				rm -f "$bundle_file"
			else
				echo -e "    ${R}FAIL${N}: could not create/transfer bundle from $newest_src"
				rm -f "$bundle_file" 2>/dev/null || true
			fi
		else
			echo -e "    ${G}✓ local is newest${N}"
		fi

		# Now push updated state to all peers (via git pull on remote)
		for idx in "${!online_peers[@]}"; do
			local p="${online_peers[$idx]}" d="${online_dests[$idx]}"
			local cmd="$REMOTE_PATH_PREFIX"
			[[ -n "$raccount" ]] && cmd+="gh auth switch --user $raccount 2>&1; "
			if $FORCE; then
				cmd+="cd $rpath && git fetch origin $rbranch 2>&1 && git reset --hard origin/$rbranch 2>&1"
			else
				cmd+="cd $rpath && git pull --ff-only origin $rbranch 2>&1"
			fi
			cmd+=" && echo 'SYNC_OK:'\$(git log --oneline -1)"

			local result
			result=$(ssh -n -o ConnectTimeout=30 "$d" "$cmd" 2>/dev/null) || true
			if echo "$result" | grep -q '^SYNC_OK:'; then
				echo -e "    ${G}→ $p${N}: $(echo "$result" | grep '^SYNC_OK:' | sed 's/^SYNC_OK://')"
			else
				echo -e "    ${R}→ $p FAIL${N}"
				peer_ok=false
			fi

			# SCP non-git files (sync_files from repos.conf)
			if [[ -n "$rsyncfiles" ]]; then
				IFS=',' read -ra files <<<"$rsyncfiles"
				for sf in "${files[@]}"; do
					sf="${sf// /}"
					if [[ -f "$local_repo/$sf" ]]; then
						if scp -o ConnectTimeout=5 "$local_repo/$sf" "$d:$rpath/$sf" 2>/dev/null; then
							echo -e "    ${G}SCP${N}: $sf → $p"
						else
							echo -e "    ${R}SCP FAIL${N}: $sf → $p"
						fi
					fi
				done
			fi
		done
		((synced++)) || true
	done 4< <(echo "$repos")

	echo -e "\n  Summary: ${G}$synced repos synced${N} | ${Y}$pulled pulled from peers${N} | ${R}$failed failed${N} | ${Y}$offline offline${N}\n"
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
