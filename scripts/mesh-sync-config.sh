#!/usr/bin/env bash
# mesh-sync-config.sh v1.1.0
# Sync config files and scripts to all online mesh peers.
# Usage: mesh-sync-config.sh [--dry-run] [--peer NAME]
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
PEERS_CONF="${PEERS_CONF:-$CLAUDE_HOME/config/peers.conf}"
DRY_RUN=false
TARGET_PEER=""

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
	*)
		echo "Unknown: $1" >&2
		exit 1
		;;
	esac
done

# Files to sync to peers
SYNC_FILES=(
	"config/models.yaml"
	"config/peers.conf"
	"scripts/model-update.sh"
	"scripts/mesh-discover.sh"
	"scripts/mesh-sync-config.sh"
)

# Parse peers.conf for active peers
parse_peers() {
	local name="" ssh_alias="" user="" status="active"
	while IFS= read -r line; do
		line="${line%%#*}"
		line="${line// /}"
		[[ -z "$line" ]] && continue
		if [[ "$line" =~ ^\[(.+)\]$ ]]; then
			if [[ -n "$name" && "$status" == "active" ]]; then
				echo "$name|$ssh_alias|$user"
			fi
			name="${BASH_REMATCH[1]}"
			ssh_alias="" user="" status="active"
		elif [[ "$line" =~ ^ssh_alias=(.+)$ ]]; then
			ssh_alias="${BASH_REMATCH[1]}"
		elif [[ "$line" =~ ^user=(.+)$ ]]; then
			user="${BASH_REMATCH[1]}"
		elif [[ "$line" =~ ^status=(.+)$ ]]; then
			status="${BASH_REMATCH[1]}"
		fi
	done <"$PEERS_CONF"
	if [[ -n "$name" && "$status" == "active" ]]; then
		echo "$name|$ssh_alias|$user"
	fi
}

SYNCED=0
FAILED=0
SKIPPED=0
inc() { eval "$1=\$(( $1 + 1 ))"; }

# Read into fd 3 to prevent ssh from consuming stdin
while IFS='|' read -r name ssh_alias user <&3 || [[ -n "$name" ]]; do
	[[ -z "$name" ]] && continue

	# Skip self (coordinator)
	if [[ "$name" == "m3max" ]]; then
		inc SKIPPED
		continue
	fi

	# Filter by --peer if specified
	if [[ -n "$TARGET_PEER" && "$name" != "$TARGET_PEER" ]]; then
		inc SKIPPED
		continue
	fi

	REMOTE="${user}@${ssh_alias}"
	echo "=== $name ($REMOTE) ==="

	# Check connectivity (-n: don't read stdin)
	if ! ssh -n -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE" true 2>/dev/null; then
		echo "  OFFLINE — skipping"
		inc FAILED
		continue
	fi

	# Ensure remote ~/.claude directory structure exists
	if ! $DRY_RUN; then
		ssh -n "$REMOTE" "mkdir -p ~/.claude/config ~/.claude/scripts" 2>/dev/null
	fi

	for file in "${SYNC_FILES[@]}"; do
		local_path="$CLAUDE_HOME/$file"
		remote_path="~/.claude/$file"

		if [[ ! -f "$local_path" ]]; then
			echo "  SKIP: $file (not found locally)"
			continue
		fi

		if $DRY_RUN; then
			echo "  WOULD sync: $file"
		else
			if scp -o ConnectTimeout=5 "$local_path" "${REMOTE}:${remote_path}" 2>/dev/null; then
				echo "  SYNCED: $file"
			else
				echo "  FAILED: $file"
			fi
		fi
	done

	# Make scripts executable on remote
	if ! $DRY_RUN; then
		ssh -n "$REMOTE" "chmod +x ~/.claude/scripts/*.sh 2>/dev/null" 2>/dev/null || true
	fi

	inc SYNCED
	echo ""
done 3< <(parse_peers)

echo "Summary: $SYNCED synced, $FAILED offline, $SKIPPED skipped"
if $DRY_RUN; then echo "(dry-run — no files transferred)"; fi
