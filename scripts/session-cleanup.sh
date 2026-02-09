#!/bin/bash
# session-cleanup.sh - Kill idle Claude/caffeinate processes to prevent overnight CPU waste
# Usage: session-cleanup.sh [--dry-run] [--max-idle MINUTES]
# Can be run manually or via launchd/cron
set -euo pipefail

MAX_IDLE_MIN="${2:-120}" # 2 hours default
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1
[[ "${1:-}" == "--max-idle" ]] && MAX_IDLE_MIN="${2:-120}"

killed=0
skipped=0

# Kill orphaned caffeinate processes (no parent claude session)
while IFS= read -r line; do
	pid=$(echo "$line" | awk '{print $1}')
	ppid=$(echo "$line" | awk '{print $2}')
	elapsed=$(echo "$line" | awk '{print $3}')

	# Parse elapsed time (format: [[dd-]hh:]mm:ss)
	minutes=0
	if [[ "$elapsed" == *-* ]]; then
		days=${elapsed%%-*}
		rest=${elapsed#*-}
		minutes=$((days * 1440))
		elapsed="$rest"
	fi
	if [[ "$elapsed" == *:*:* ]]; then
		hours=$(echo "$elapsed" | cut -d: -f1)
		mins=$(echo "$elapsed" | cut -d: -f2)
		minutes=$((minutes + hours * 60 + mins))
	else
		mins=$(echo "$elapsed" | cut -d: -f1)
		minutes=$((minutes + mins))
	fi

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
