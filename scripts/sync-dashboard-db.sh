#!/bin/bash
# sync-dashboard-db.sh - Sync dashboard.db between machines
# Usage: sync-dashboard-db.sh [push|pull|incremental|diagnose|status]
# Version: 2.0.0 - Modularized
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/sync-dashboard-db-ops.sh"

CONFIG_FILE="$HOME/.claude/config/sync-db.conf"
if [[ -f "$CONFIG_FILE" ]]; then
	source "$CONFIG_FILE"
else
	echo "ERROR: Config file not found: $CONFIG_FILE"
	echo "Create it with REMOTE_HOST, REMOTE_DB, LOCAL_DB settings"
	exit 1
fi

LOCAL_DB="${LOCAL_DB:-$HOME/.claude/data/dashboard.db}"
REMOTE_DB="${REMOTE_DB:-~/.claude/data/dashboard.db}"
BACKUP_DIR="$HOME/.claude/data/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Export vars for use in sourced modules
export LOCAL_DB REMOTE_DB BACKUP_DIR TIMESTAMP REMOTE_HOST

# ============================================================================
# Main dispatcher
# ============================================================================
case "${1:-status}" in
pull)
	check_ssh "$REMOTE_HOST"
	backup_local
	sync_plans pull
	log_info "Sync complete (Linux → Mac)"
	;;
push)
	check_ssh "$REMOTE_HOST"
	backup_remote
	sync_plans push
	log_info "Sync complete (Mac → Linux)"
	;;
full-pull)
	check_ssh "$REMOTE_HOST"
	full_pull
	;;
full-push)
	check_ssh "$REMOTE_HOST"
	full_push
	;;
status)
	check_ssh "$REMOTE_HOST"
	show_status
	;;
incremental)
	check_ssh "$REMOTE_HOST"
	incremental_sync
	;;
copy-plan)
	check_ssh "$REMOTE_HOST"
	copy_plan "$2" "$3"
	;;
diagnose)
	check_ssh "$REMOTE_HOST"
	diagnose_sync
	;;
*)
	echo "Usage: $0 [pull|push|incremental|diagnose|full-pull|full-push|copy-plan|status]"
	echo "  pull/push - Sync completed plans | incremental - Changed rows only"
	echo "  diagnose - Run incremental sync with verbose tracing for debugging"
	echo "  full-pull/full-push - Replace entire DB | copy-plan <id> [push|pull]"
	echo "  status - Compare both DBs | Config: $CONFIG_FILE"
	exit 1
	;;
esac
