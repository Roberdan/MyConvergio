#!/bin/bash
# Shared hooks library - DRY utilities for all hooks
# Source this file: source "$HOOK_DIR/lib/common.sh"
# Version: 1.1.0

# Check if binary exists
have_bin() {
	command -v "$1" >/dev/null 2>&1
}

# Check multiple dependencies
check_deps() {
	local missing=()
	for dep in "$@"; do
		have_bin "$dep" || missing+=("$dep")
	done
	if [ ${#missing[@]} -gt 0 ]; then
		echo "Missing: ${missing[*]}" >&2
		return 1
	fi
	return 0
}

# Log hook execution (async-safe)
log_hook() {
	local hook_name="$1"
	local message="$2"
	local log_file="${MYCONVERGIO_HOOKS_LOG:-${MYCONVERGIO_HOME}/logs/hooks.log}"
	mkdir -p "$(dirname "$log_file")" 2>/dev/null
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$hook_name] $message" >>"$log_file" 2>/dev/null &
}

# Extract JSON field from stdin
json_field() {
	local field="$1"
	jq -r "$field // empty" 2>/dev/null
}

# Dashboard DB path
MYCONVERGIO_HOME="${MYCONVERGIO_HOME:-$HOME/.myconvergio}"
DASHBOARD_DB="${MYCONVERGIO_DASHBOARD_DB:-${MYCONVERGIO_HOME}/data/dashboard.db}"

# Check dashboard is accessible
check_dashboard() {
	[ -f "$DASHBOARD_DB" ] && have_bin sqlite3
}

# Async DB write (non-blocking)
async_db_write() {
	local sql="$1"
	{
		sqlite3 "$DASHBOARD_DB" "$sql" 2>/dev/null
	} &
}
