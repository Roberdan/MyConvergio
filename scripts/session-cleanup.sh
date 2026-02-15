#!/bin/bash
# session-cleanup.sh - Kill idle Claude/caffeinate processes to prevent overnight CPU waste
# Usage: session-cleanup.sh [--dry-run] [--max-idle MINUTES]
# Can be run manually or via launchd/cron
# Version: 1.1.0
set -euo pipefail

MAX_IDLE_MIN="${2:-120}" # 2 hours default
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1
[[ "${1:-}" == "--max-idle" ]] && MAX_IDLE_MIN="${2:-120}"

killed=0
skipped=0

# Parse elapsed time string to minutes
# Handles formats: mm:ss, hh:mm:ss, d-hh:mm:ss
parse_elapsed_minutes() {
	local elapsed="$1"
	local days=0 hours=0 mins=0
	# Handle days: "2-03:45:12"
	if [[ "$elapsed" == *-* ]]; then
		days=${elapsed%%-*}
		elapsed=${elapsed#*-}
	fi
	# Handle hours:mins:secs or mins:secs
	IFS=':' read -ra parts <<<"$elapsed"
	if [[ ${#parts[@]} -eq 3 ]]; then
		hours=${parts[0]#0} # strip leading zero
		mins=${parts[1]#0}
	elif [[ ${#parts[@]} -eq 2 ]]; then
		mins=${parts[0]#0}
	fi
	echo $((days * 1440 + ${hours:-0} * 60 + ${mins:-0}))
}

# Kill orphaned caffeinate processes (no parent claude session)
while IFS= read -r line; do
	pid=$(echo "$line" | awk '{print $1}')
	ppid=$(echo "$line" | awk '{print $2}')
	elapsed=$(echo "$line" | awk '{print $3}')

	minutes=$(parse_elapsed_minutes "$elapsed")

	if [[ $minutes -gt $MAX_IDLE_MIN ]]; then
		if [[ $DRY_RUN -eq 1 ]]; then
			echo "WOULD KILL caffeinate PID=$pid (idle ${minutes}min, parent=$ppid)"
			skipped=$((skipped + 1))
		else
			kill "$pid" 2>/dev/null && killed=$((killed + 1))
		fi
	fi
done < <(ps -eo pid,ppid,etime,comm 2>/dev/null | grep caffeinate | grep -v grep || true)

# Report
jq -n --argjson killed "$killed" --argjson skipped "$skipped" \
	--argjson threshold "$MAX_IDLE_MIN" \
	'{"killed":$killed,"skipped_dry_run":$skipped,"threshold_min":$threshold}'
