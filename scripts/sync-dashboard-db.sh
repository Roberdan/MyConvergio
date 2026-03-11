#!/bin/bash
# sync-dashboard-db.sh - Sync dashboard.db between machines
# Usage: sync-dashboard-db.sh [push|pull|incremental|diagnose|status]
# Version: 2.0.0 - Modularized
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/peers.sh"
source "${SCRIPT_DIR}/lib/sync-dashboard-db-ops.sh"
source "${SCRIPT_DIR}/lib/sync-dashboard-db-multi.sh"

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
peers_load 2>/dev/null || true

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
push-all)
	multi_push_all
	;;
pull-all)
	multi_pull_all
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
status-all)
	multi_status_all
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
	echo "Usage: $0 [pull|push|push-all|pull-all|incremental|diagnose|full-pull|full-push|copy-plan|status|status-all]"
	echo "  pull/push - Sync completed plans with configured REMOTE_HOST"
	echo "  push-all/pull-all/status-all - Multi-peer operations via peers.conf"
	echo "  diagnose - Run incremental sync with verbose tracing for debugging"
	echo "  full-pull/full-push - Replace entire DB | copy-plan <id> [push|pull]"
	echo "  status - Compare both DBs | Config: $CONFIG_FILE"
	exit 1
	;;
esac
