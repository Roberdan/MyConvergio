#!/bin/bash
# Plan DB Core - Shared utilities
# Sourced by plan-db.sh

# Version: 1.3.0
DB_FILE="${HOME}/.claude/data/dashboard.db"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Export hostname for distributed execution tracking
# Strip .local suffix for consistency (macOS hostname vs DB stored values)
PLAN_DB_HOST="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
export PLAN_DB_HOST="${PLAN_DB_HOST%.local}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# SQLite wrapper with busy timeout and performance PRAGMAs
db_query() {
	sqlite3 -cmd ".timeout 5000" \
		-cmd "PRAGMA cache_size = -8000" \
		-cmd "PRAGMA temp_store = MEMORY" \
		"$DB_FILE" "$@"
}

# Initialize DB if needed
init_db() {
	if [[ ! -f "$DB_FILE" ]]; then
		mkdir -p "$(dirname "$DB_FILE")"
		sqlite3 "$DB_FILE" <"$SCRIPT_DIR/init-db.sql"
		sqlite3 "$DB_FILE" "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA cache_size=-8000; PRAGMA temp_store=MEMORY; PRAGMA mmap_size=268435456;"
		log_info "Database initialized"
	fi
}

# Escape single quotes for SQL
sql_escape() {
	printf '%s' "$1" | tr '\n\r' '  ' | sed "s/'/''/g"
}

# ============================================================
# SSH and Sync Configuration Helpers
# ============================================================

# Load sync configuration from sync-db.conf
load_sync_config() {
	local config_file="${HOME}/.claude/config/sync-db.conf"

	# Set defaults
	REMOTE_HOST="${REMOTE_HOST:-omarchy-ts}"
	REMOTE_DB="${REMOTE_DB:-~/.claude/data/dashboard.db}"

	# Source config file if it exists
	if [[ -f "$config_file" ]]; then
		source "$config_file"
	fi
}

# Check SSH connectivity to remote host
# Returns: 0 if connectable, 1 if not
ssh_check() {
	load_sync_config
	ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_HOST" "echo ok" &>/dev/null
	return $?
}

# Get remote host from config
get_remote_host() {
	load_sync_config
	echo "$REMOTE_HOST"
}

# Check if local and remote ~/.claude configs are in sync
# Returns: SYNCED (both at same commit), PUSHED (auto-pushed local changes), DIVERGED (manual intervention needed)
config_sync_check() {
	load_sync_config

	# Get local HEAD
	local local_head
	local_head=$(cd ~/.claude && git rev-parse HEAD 2>/dev/null) || {
		echo "ERROR"
		return 1
	}

	# Check if remote is accessible
	if ! ssh_check; then
		echo "OFFLINE"
		return 0
	fi

	# Get remote HEAD
	local remote_head
	remote_head=$(ssh -o ConnectTimeout=5 "$REMOTE_HOST" "cd ~/.claude && git rev-parse HEAD 2>/dev/null") || {
		echo "ERROR"
		return 1
	}

	# Compare commits
	if [[ "$local_head" == "$remote_head" ]]; then
		echo "SYNCED"
		return 0
	fi

	# Check if remote is behind local (can be fast-forwarded)
	local merge_base
	merge_base=$(cd ~/.claude && git merge-base HEAD "$remote_head" 2>/dev/null)

	if [[ "$merge_base" == "$remote_head" ]]; then
		# Remote is behind, auto-push
		if "$SCRIPT_DIR/sync-claude-config.sh" push &>/dev/null; then
			echo "PUSHED"
			return 0
		else
			echo "PUSH_FAILED"
			return 1
		fi
	fi

	# Diverged - manual intervention needed
	echo "DIVERGED"
	return 2
}
