#!/usr/bin/env bash
# sync-claude-config.sh - Sync ~/.claude git repo between Mac and Linux
# Usage: sync-claude-config.sh [push|pull|status]
# Uses git bundle for safe, atomic transfer. Only fast-forward merges.
# Version: 1.1.0
set -euo pipefail

# --- Configuration ---
CONFIG_FILE="$HOME/.claude/config/sync-db.conf"
if [[ -f "$CONFIG_FILE" ]]; then
	source "$CONFIG_FILE"
else
	echo "ERROR: Config file not found: $CONFIG_FILE"
	exit 1
fi

REMOTE_HOST="${REMOTE_HOST:-omarchy-ts}"
LOCAL_REPO="$HOME/.claude"
REMOTE_REPO="~/.claude"
BUNDLE="/tmp/claude-config-sync.bundle"

# Runs from Mac only (Linux cannot SSH back to Mac)
CURRENT_HOST=$(hostname -s 2>/dev/null || hostname)
if [[ "$CURRENT_HOST" == "omarchy" && "${ALLOW_LINUX_SYNC:-0}" != "1" ]]; then
	echo -e "\033[0;31m[sync]\033[0m Run from Mac, not Linux. Set ALLOW_LINUX_SYNC=1 to override."
	exit 1
fi

# --- Output helpers ---
G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' N='\033[0m'
info() { echo -e "${C}[sync]${N} $*"; }
ok() { echo -e "${G}[sync]${N} $*"; }
warn() { echo -e "${Y}[sync]${N} $*"; }
err() { echo -e "${R}[sync]${N} $*" >&2; }

# --- Helpers ---
local_head() { git -C "$LOCAL_REPO" rev-parse HEAD; }
remote_head() { ssh "$REMOTE_HOST" "git -C $REMOTE_REPO rev-parse HEAD" 2>/dev/null; }

check_clean() {
	local where="$1" dirty
	if [[ "$where" == "local" ]]; then
		dirty=$(git -C "$LOCAL_REPO" status --porcelain 2>/dev/null | head -3)
	else
		dirty=$(ssh "$REMOTE_HOST" "git -C $REMOTE_REPO status --porcelain 2>/dev/null | head -3")
	fi
	[[ -n "$dirty" ]] && warn "$where has uncommitted changes (proceeding)"
	return 0
}

cleanup() {
	rm -f "$BUNDLE"
	ssh "$REMOTE_HOST" "rm -f $BUNDLE" 2>/dev/null || true
}
trap cleanup EXIT

# --- Status ---
cmd_status() {
	info "Comparing local vs remote ($REMOTE_HOST)..."
	local lh rh
	lh=$(local_head)
	rh=$(remote_head)
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
			ssh "$REMOTE_HOST" "git -C $REMOTE_REPO log --oneline -3" 2>/dev/null | sed 's/^/    /'
		fi
	else
		err "Remote commit not found locally. Histories may have diverged."
	fi
}

# --- Push (local → remote) ---
cmd_push() {
	info "Pushing local -> $REMOTE_HOST..."
	local lh rh
	lh=$(local_head)
	rh=$(remote_head)
	if [[ "$lh" == "$rh" ]]; then
		ok "Already in sync."
		return 0
	fi

	if ! git -C "$LOCAL_REPO" merge-base --is-ancestor "$rh" "$lh" 2>/dev/null; then
		err "Cannot fast-forward. Run 'csync pull' first."
		return 1
	fi

	check_clean "remote"
	local count
	count=$(git -C "$LOCAL_REPO" rev-list --count "$rh".."$lh")
	info "Bundling $count commit(s)..."

	git -C "$LOCAL_REPO" bundle create "$BUNDLE" "$rh".."$lh" 2>/dev/null
	scp -q "$BUNDLE" "$REMOTE_HOST:$BUNDLE"

	info "Applying on remote..."
	ssh "$REMOTE_HOST" "cd $REMOTE_REPO && git bundle verify $BUNDLE >/dev/null 2>&1 && git fetch $BUNDLE HEAD:refs/heads/_sync_tmp && git merge --ff-only _sync_tmp && git branch -d _sync_tmp"

	local new_rh
	new_rh=$(remote_head)
	if [[ "$lh" == "$new_rh" ]]; then
		ok "Sync complete! Both at ${lh:0:7}"
		echo -e "\n  Pushed $count commit(s):"
		git -C "$LOCAL_REPO" log --oneline "$rh".."$lh" | sed 's/^/    /'
	else
		err "Verification failed. Remote: ${new_rh:0:7}, expected: ${lh:0:7}"
		return 1
	fi
}

# --- Pull (remote → local) ---
cmd_pull() {
	info "Pulling $REMOTE_HOST -> local..."
	local lh rh
	lh=$(local_head)
	rh=$(remote_head)
	if [[ "$lh" == "$rh" ]]; then
		ok "Already in sync."
		return 0
	fi

	if ! ssh "$REMOTE_HOST" "cd $REMOTE_REPO && git merge-base --is-ancestor $lh HEAD && git bundle create $BUNDLE ${lh}..HEAD" 2>/dev/null; then
		err "Cannot fast-forward. Run 'csync push' first."
		return 1
	fi

	scp -q "$REMOTE_HOST:$BUNDLE" "$BUNDLE"
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

# --- Main ---
case "${1:-status}" in
push) cmd_push ;;
pull) cmd_pull ;;
status) cmd_status ;;
-h | --help | help)
	echo "Usage: $(basename "$0") [push|pull|status]"
	echo "  push   - Send local commits to $REMOTE_HOST"
	echo "  pull   - Fetch remote commits from $REMOTE_HOST"
	echo "  status - Compare both machines (default)"
	;;
*)
	err "Unknown: $1. Use push|pull|status"
	exit 1
	;;
esac
