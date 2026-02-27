#!/bin/bash
# session-reaper.sh — Kill orphaned AI agent shell processes (Claude Code + Copilot CLI)
# Version: 3.0.0
# Usage:
#   session-reaper.sh                     # Kill all orphans (ppid=1 or parent dead)
#   session-reaper.sh --snapshot <file>   # Kill processes for a specific snapshot
#   session-reaper.sh --dry-run           # Show what would be killed
#   session-reaper.sh --max-age <min>     # Only kill processes older than N minutes (default: 3)
#   session-reaper.sh --pre-spawn         # Memory gate: reap + check before spawning new agents
set -euo pipefail

DRY_RUN=0
SNAPSHOT=""
MAX_AGE=3
PRE_SPAWN=0
MY_PID=$$

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		DRY_RUN=1
		shift
		;;
	--snapshot)
		SNAPSHOT="$2"
		shift 2
		;;
	--max-age)
		MAX_AGE="$2"
		shift 2
		;;
	--pre-spawn)
		PRE_SPAWN=1
		MAX_AGE=1
		shift
		;;
	*)
		echo "Unknown: $1" >&2
		exit 1
		;;
	esac
done

LOG="$HOME/.claude/logs/session-reaper.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >>"$LOG"; }

# Recursive SIGKILL on entire process tree (bottom-up)
_kill_tree() {
	local target_pid="$1"
	local children
	children=$(pgrep -P "$target_pid" 2>/dev/null || true)
	for child in $children; do
		_kill_tree "$child"
	done
	kill -9 "$target_pid" 2>/dev/null || true
}

killed=0
skipped=0

# Find all zsh processes spawned by Claude (they reference shell-snapshots)
while IFS= read -r line; do
	pid=$(echo "$line" | awk '{print $1}')
	ppid=$(echo "$line" | awk '{print $2}')
	etime=$(echo "$line" | awk '{print $3}')

	# Skip self
	[[ "$pid" -eq "$MY_PID" ]] && continue

	# If snapshot specified, only match that one
	if [[ -n "$SNAPSHOT" ]]; then
		cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
		[[ "$cmd" != *"$SNAPSHOT"* ]] && continue
	fi

	# Parse elapsed time to minutes (formats: MM:SS, HH:MM:SS, D-HH:MM:SS)
	minutes=0
	if [[ "$etime" == *-* ]]; then
		days=${etime%%-*}
		rest=${etime#*-}
		hours=${rest%%:*}
		minutes=$((days * 1440 + hours * 60))
	elif [[ $(echo "$etime" | tr -cd ':' | wc -c) -eq 2 ]]; then
		hours=$(echo "$etime" | cut -d: -f1)
		mins=$(echo "$etime" | cut -d: -f2)
		minutes=$((hours * 60 + mins))
	else
		mins=$(echo "$etime" | cut -d: -f1)
		minutes=$mins
	fi

	# Skip if too young (unless snapshot-specific cleanup)
	if [[ -z "$SNAPSHOT" ]] && [[ "$minutes" -lt "$MAX_AGE" ]]; then
		skipped=$((skipped + 1))
		continue
	fi

	# Check if parent is dead or is PID 1 (orphan)
	is_orphan=0
	if [[ "$ppid" -eq 1 ]]; then
		is_orphan=1
	elif ! ps -p "$ppid" -o command= 2>/dev/null | grep -q 'claude'; then
		is_orphan=1
	fi

	# For snapshot-specific cleanup (Stop hook), kill regardless of orphan status
	if [[ -n "$SNAPSHOT" ]]; then
		is_orphan=1
	fi

	[[ "$is_orphan" -eq 0 ]] && continue

	# Get full command for logging
	cmd_short=$(ps -p "$pid" -o command= 2>/dev/null | cut -c1-80 || echo "?")

	if [[ "$DRY_RUN" -eq 1 ]]; then
		echo "[DRY] Would kill PID $pid (${minutes}m) ppid=$ppid: $cmd_short" >&2
		killed=$((killed + 1))
	else
		_kill_tree "$pid"
		log "Killed PID $pid (${minutes}m): $cmd_short"
		killed=$((killed + 1))
	fi
done < <(ps -eo pid,ppid,etime,command | grep 'shell-snapshots/snapshot' | grep -v grep | grep -v "$MY_PID")

# Pass 2: orphaned processes writing to claude temp CWD files
# Pattern: both Claude Code and Copilot CLI write pwd to /tmp/claude-*-cwd or similar
# These are shell wrappers that may not reference shell-snapshots
while IFS= read -r line; do
	pid=$(echo "$line" | awk '{print $1}')
	ppid=$(echo "$line" | awk '{print $2}')
	etime=$(echo "$line" | awk '{print $3}')

	[[ "$pid" -eq "$MY_PID" ]] && continue

	# Parse elapsed time (same logic as above)
	minutes=0
	if [[ "$etime" == *-* ]]; then
		days=${etime%%-*}
		rest=${etime#*-}
		hours=${rest%%:*}
		minutes=$((days * 1440 + hours * 60))
	elif [[ $(echo "$etime" | tr -cd ':' | wc -c) -eq 2 ]]; then
		hours=$(echo "$etime" | cut -d: -f1)
		mins=$(echo "$etime" | cut -d: -f2)
		minutes=$((hours * 60 + mins))
	else
		mins=$(echo "$etime" | cut -d: -f1)
		minutes=$mins
	fi

	if [[ -z "$SNAPSHOT" ]] && [[ "$minutes" -lt "$MAX_AGE" ]]; then
		skipped=$((skipped + 1))
		continue
	fi

	# Only kill true orphans (ppid=1 or parent not an AI agent)
	is_orphan=0
	if [[ "$ppid" -eq 1 ]]; then
		is_orphan=1
	elif ! ps -p "$ppid" -o command= 2>/dev/null | grep -qE 'claude|copilot|github-copilot'; then
		is_orphan=1
	fi

	[[ "$is_orphan" -eq 0 ]] && continue

	cmd_short=$(ps -p "$pid" -o command= 2>/dev/null | cut -c1-80 || echo "?")

	if [[ "$DRY_RUN" -eq 1 ]]; then
		echo "[DRY] Would kill PID $pid (${minutes}m) ppid=$ppid: $cmd_short" >&2
		killed=$((killed + 1))
	else
		_kill_tree "$pid"
		log "Killed PID $pid (${minutes}m) [cwd-pattern]: $cmd_short"
		killed=$((killed + 1))
	fi
done < <(ps -eo pid,ppid,etime,command | grep -E 'claude-[a-zA-Z0-9_-]+-cwd' | grep -v grep | grep -v "$MY_PID" | grep -v 'shell-snapshots/snapshot')

# Also clean up stale shell-snapshot files (older than 2 days)
if [[ -z "$SNAPSHOT" ]] && [[ -d "$HOME/.claude/shell-snapshots" ]]; then
	find "$HOME/.claude/shell-snapshots" -name 'snapshot-*.sh' -mtime +2 -delete 2>/dev/null || true
fi

# Pre-spawn memory gate: check swap pressure after cleanup
if [[ "$PRE_SPAWN" -eq 1 ]]; then
	swap_used_mb=$(sysctl vm.swapusage 2>/dev/null | awk -F'[ M]' '{for(i=1;i<=NF;i++) if($i=="used") {gsub(/[^0-9.]/,"",$((i+2))); printf "%.0f", $((i+2)); exit}}')
	# Fallback: parse differently
	if [[ -z "$swap_used_mb" ]]; then
		swap_used_mb=$(sysctl vm.swapusage 2>/dev/null | sed 's/.*used = \([0-9.]*\)M.*/\1/' | awk '{printf "%.0f", $1}')
	fi
	swap_used_mb=${swap_used_mb:-0}
	mem_pressure=$(memory_pressure 2>/dev/null | grep 'System-wide' | awk '{print $NF}' || echo "unknown")
	if [[ "$swap_used_mb" -gt 10000 ]]; then
		log "PRE-SPAWN BLOCKED: swap=${swap_used_mb}MB pressure=${mem_pressure}"
		echo '{"killed":'"$killed"',"skipped":'"$skipped"',"dry_run":'"$DRY_RUN"',"spawn_ok":false,"swap_mb":'"$swap_used_mb"',"pressure":"'"$mem_pressure"'"}'
		exit 1
	fi
	log "PRE-SPAWN OK: swap=${swap_used_mb}MB pressure=${mem_pressure} killed=$killed"
	echo '{"killed":'"$killed"',"skipped":'"$skipped"',"dry_run":'"$DRY_RUN"',"spawn_ok":true,"swap_mb":'"$swap_used_mb"',"pressure":"'"$mem_pressure"'"}'
	exit 0
fi

# Always output JSON summary
[[ "$DRY_RUN" -eq 0 ]] && [[ "$killed" -gt 0 ]] && log "Reaped $killed orphan(s), skipped $skipped"
echo '{"killed":'"$killed"',"skipped":'"$skipped"',"dry_run":'"$DRY_RUN"'}'
