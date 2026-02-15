#!/bin/bash
# Prune old cache/log artifacts to keep ~/.claude tidy.
# Usage: cleanup-cache.sh [--verbose]

# Version: 1.1.0
set -euo pipefail

CLAUDE_HOME="${HOME}/.claude"
VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

prune_dir() {
	local dir="$1"
	local days="$2"
	[ -d "$dir" ] || return 0
	if [[ $VERBOSE -eq 1 ]]; then
		find "$dir" -type f -mtime +"$days" -delete -print
	else
		local count
		count=$(find "$dir" -type f -mtime +"$days" -delete -print 2>/dev/null | wc -l | tr -d ' ')
		echo "Deleted $count cached files from $(basename "$dir")"
	fi
}

# Logs and transient data
prune_dir "${CLAUDE_HOME}/logs" 30
prune_dir "${CLAUDE_HOME}/cache" 30
prune_dir "${CLAUDE_HOME}/telemetry" 30
prune_dir "${CLAUDE_HOME}/paste-cache" 30
