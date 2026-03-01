#!/usr/bin/env bash
set -euo pipefail
# sync-claude-config.sh - Sync ~/.claude git repo between peers
# Usage: sync-claude-config.sh [push|pull|status|push-all|pull-all|status-all]
# Uses git bundle for safe, atomic transfer. Only fast-forward merges.
# Version: 2.0.0

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/peers.sh
source "${_SCRIPT_DIR}/lib/peers.sh"

CONFIG_FILE="$HOME/.claude/config/sync-db.conf"
if [[ -f "$CONFIG_FILE" ]]; then
	source "$CONFIG_FILE"
else
	echo "ERROR: Config file not found: $CONFIG_FILE"
	exit 1
fi

REMOTE_HOST="${REMOTE_HOST:-}"
LOCAL_REPO="$HOME/.claude"
REMOTE_REPO="~/.claude"
BUNDLE="${TMPDIR:-/tmp}/claude-config-sync.bundle"
_CLEANUP_HOST=""

# Load peers; no-op if peers.conf missing (single-peer mode works via REMOTE_HOST)
peers_load 2>/dev/null || true

G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' N='\033[0m'
info() { echo -e "${C}[sync]${N} $*"; }
ok() { echo -e "${G}[sync]${N} $*"; }
warn() { echo -e "${Y}[sync]${N} $*"; }
err() { echo -e "${R}[sync]${N} $*" >&2; }

local_head() { git -C "$LOCAL_REPO" rev-parse HEAD; }
remote_head() { ssh "$1" "git -C $REMOTE_REPO rev-parse HEAD" 2>/dev/null; }

check_clean() {
	local where="$1" host="${2:-}" dirty
	if [[ "$where" == "local" ]]; then
		dirty=$(git -C "$LOCAL_REPO" status --porcelain 2>/dev/null)
	else dirty=$(ssh "$host" "git -C $REMOTE_REPO status --porcelain 2>/dev/null"); fi
	[[ -n "$dirty" ]] && warn "$where has uncommitted changes (proceeding)"
	return 0
}

cleanup() {
	rm -f "$BUNDLE"
	[[ -n "$_CLEANUP_HOST" ]] && ssh "$_CLEANUP_HOST" "rm -f $BUNDLE" 2>/dev/null || true
}
trap cleanup EXIT
# Resolve peer name to SSH destination (user@host or host)
_peer_ssh() {
	local name="$1" route user
	route="$(peers_best_route "$name" 2>/dev/null)" || return 1
	user="$(_peers_get_raw "$name" "user" 2>/dev/null || true)"
	echo "${user:+${user}@}${route}"
}

cmd_status() {
	local host="${1:-$REMOTE_HOST}"
	[[ -z "$host" ]] && {
		err "No remote host. Set REMOTE_HOST or use status-all."
		return 1
	}
	info "Comparing local vs remote ($host)..."
	local lh rh
	lh=$(local_head)
	rh=$(remote_head "$host")
	echo -e "\n  Local:  ${C}${lh:0:7}${N}\n  Remote: ${C}${rh:0:7}${N}\n"
	if [[ "$lh" == "$rh" ]]; then
		ok "Already in sync!"
		return 0
	fi
	if git -C "$LOCAL_REPO" merge-base --is-ancestor "$rh" "$lh" 2>/dev/null; then
		local count
		count=$(git -C "$LOCAL_REPO" rev-list --count "$rh".."$lh")
		warn "Local is $count commit(s) AHEAD. Run: csync push"
		echo -e "\n  Commits to push:"
		git -C "$LOCAL_REPO" log --oneline "$rh".."$lh" | sed 's/^/    /'
	elif git -C "$LOCAL_REPO" cat-file -t "$rh" &>/dev/null; then
		if git -C "$LOCAL_REPO" merge-base --is-ancestor "$lh" "$rh" 2>/dev/null; then
			warn "Remote is ahead. Run: csync pull"
		else
			err "Histories diverged! Manual resolution needed."
			echo "  Local:"
			git -C "$LOCAL_REPO" log --oneline -3 | sed 's/^/    /'
			echo "  Remote:"
			ssh "$host" "git -C $REMOTE_REPO log --oneline -3" 2>/dev/null | sed 's/^/    /'
		fi
	else err "Remote commit not found locally. Histories may have diverged."; fi
}

cmd_push() {
	local host="${1:-$REMOTE_HOST}"
	[[ -z "$host" ]] && {
		err "No remote host. Set REMOTE_HOST or use push-all."
		return 1
	}
	_CLEANUP_HOST="$host"
	info "Pushing local -> $host..."
	local lh rh
	lh=$(local_head)
	rh=$(remote_head "$host")
	[[ "$lh" == "$rh" ]] && {
		ok "Already in sync."
		return 0
	}
	git -C "$LOCAL_REPO" merge-base --is-ancestor "$rh" "$lh" 2>/dev/null ||
		{
			err "Cannot fast-forward. Run 'csync pull' first."
			return 1
		}
	check_clean "remote" "$host"
	local count
	count=$(git -C "$LOCAL_REPO" rev-list --count "$rh".."$lh")
	info "Bundling $count commit(s)..."
	git -C "$LOCAL_REPO" bundle create "$BUNDLE" "$rh".."$lh" 2>/dev/null
	scp -q "$BUNDLE" "$host:$BUNDLE"
	info "Applying on remote..."
	ssh "$host" "cd $REMOTE_REPO && git bundle verify $BUNDLE >/dev/null 2>&1 && git fetch $BUNDLE HEAD:refs/heads/_sync_tmp && git merge --ff-only _sync_tmp && git branch -d _sync_tmp"
	local new_rh
	new_rh=$(remote_head "$host")
	if [[ "$lh" == "$new_rh" ]]; then
		ok "Sync complete! Both at ${lh:0:7}"
		echo -e "\n  Pushed $count commit(s):"
		git -C "$LOCAL_REPO" log --oneline "$rh".."$lh" | sed 's/^/    /'
	else
		err "Verification failed. Remote: ${new_rh:0:7}, expected: ${lh:0:7}"
		return 1
	fi
}

cmd_pull() {
	local host="${1:-$REMOTE_HOST}"
	[[ -z "$host" ]] && {
		err "No remote host. Set REMOTE_HOST or use pull-all."
		return 1
	}
	_CLEANUP_HOST="$host"
	info "Pulling $host -> local..."
	local lh rh
	lh=$(local_head)
	rh=$(remote_head "$host")
	[[ "$lh" == "$rh" ]] && {
		ok "Already in sync."
		return 0
	}
	ssh "$host" "cd $REMOTE_REPO && git merge-base --is-ancestor $lh HEAD && git bundle create $BUNDLE ${lh}..HEAD" 2>/dev/null ||
		{
			err "Cannot fast-forward. Run 'csync push' first."
			return 1
		}
	scp -q "$host:$BUNDLE" "$BUNDLE"
	check_clean "local"
	info "Applying locally..."
	git -C "$LOCAL_REPO" bundle verify "$BUNDLE" >/dev/null 2>&1
	git -C "$LOCAL_REPO" fetch "$BUNDLE" HEAD:refs/heads/_sync_tmp 2>/dev/null
	git -C "$LOCAL_REPO" merge --ff-only _sync_tmp
	git -C "$LOCAL_REPO" branch -d _sync_tmp
	local new_lh
	new_lh=$(local_head)
	if [[ "$rh" == "$new_lh" ]]; then
		local count
		count=$(git -C "$LOCAL_REPO" rev-list --count "$lh".."$new_lh")
		ok "Sync complete! Both at ${new_lh:0:7}"
		echo -e "\n  Pulled $count commit(s):"
		git -C "$LOCAL_REPO" log --oneline "$lh".."$new_lh" | sed 's/^/    /'
	else
		err "Verification failed. Local: ${new_lh:0:7}, expected: ${rh:0:7}"
		return 1
	fi
}

# Multi-peer: iterate peers_others(), invoke single-peer command for each
_for_each_peer() {
	local verb="$1" cmd="$2" failed=0 peer host
	while IFS= read -r peer; do
		[[ -z "$peer" ]] && continue
		host="$(_peer_ssh "$peer" 2>/dev/null)" || {
			warn "Skipping $peer (no route)"
			continue
		}
		echo ""
		info "=== $verb $peer ($host) ==="
		"$cmd" "$host" || {
			warn "$verb $peer FAILED"
			failed=$((failed + 1))
		}
	done < <(peers_others)
	if [[ $failed -gt 0 ]]; then
		err "$failed peer(s) failed"
		return 1
	fi
	ok "${cmd#cmd_}-all complete"
}

cmd_push_all() { _for_each_peer "push ->" "cmd_push"; }
cmd_pull_all() { _for_each_peer "pull <-" "cmd_pull"; }

cmd_status_all() {
	local lh peer host rh status_str n
	lh=$(local_head)
	printf "\n  %-20s %-10s %-10s %s\n" "PEER" "LOCAL" "REMOTE" "STATUS"
	printf "  %-20s %-10s %-10s %s\n" "----" "-----" "------" "------"
	while IFS= read -r peer; do
		[[ -z "$peer" ]] && continue
		host="$(_peer_ssh "$peer" 2>/dev/null)" ||
			{
				printf "  %-20s %-10s %-10s %s\n" "$peer" "${lh:0:7}" "?" "no route"
				continue
			}
		rh="$(remote_head "$host" 2>/dev/null || echo "?")"
		if [[ "$rh" == "?" ]]; then
			status_str="unreachable"
		elif [[ "$lh" == "$rh" ]]; then
			status_str="in sync"
		elif git -C "$LOCAL_REPO" merge-base --is-ancestor "$rh" "$lh" 2>/dev/null; then
			n=$(git -C "$LOCAL_REPO" rev-list --count "${rh}".."${lh}" 2>/dev/null || echo "?")
			status_str="local ahead +$n"
		elif [[ "$rh" != "?" ]] && git -C "$LOCAL_REPO" cat-file -t "$rh" &>/dev/null &&
			git -C "$LOCAL_REPO" merge-base --is-ancestor "$lh" "$rh" 2>/dev/null; then
			n=$(git -C "$LOCAL_REPO" rev-list --count "${lh}".."${rh}" 2>/dev/null || echo "?")
			status_str="remote ahead +$n"
		else status_str="diverged"; fi
		printf "  %-20s %-10s %-10s %s\n" "$peer" "${lh:0:7}" "${rh:0:7}" "$status_str"
	done < <(peers_others)
	echo ""
}

case "${1:-status}" in
push) cmd_push ;;
pull) cmd_pull ;;
status) cmd_status ;;
push-all) cmd_push_all ;;
pull-all) cmd_pull_all ;;
status-all) cmd_status_all ;;
-h | --help | help)
	echo "Usage: $(basename "$0") [push|pull|status|push-all|pull-all|status-all]"
	echo "  push/pull/status — single peer (REMOTE_HOST) | *-all — all peers (peers.conf)"
	;;
*)
	err "Unknown: $1. Use push|pull|status|push-all|pull-all|status-all"
	exit 1
	;;
esac
