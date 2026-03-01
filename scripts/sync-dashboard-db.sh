#!/bin/bash
# sync-dashboard-db.sh - Sync dashboard.db between machines
# Usage: sync-dashboard-db.sh [push|pull|push-all|pull-all|status-all|incremental|diagnose|status]
# Version: 2.1.0 - Multi-peer support
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
push-all)
	peers_load
	multi_push_all
	log_info "push-all complete"
	;;
pull-all)
	peers_load
	multi_pull_all
	log_info "pull-all complete"
	;;
status-all)
	peers_load
	multi_status_all
	;;
*)
	echo "Usage: $0 [pull|push|push-all|pull-all|status-all|incremental|diagnose|full-pull|full-push|copy-plan|status]"
	echo "  pull/push       - Sync completed plans (single peer) | incremental - Changed rows only"
	echo "  push-all        - Push to all active peers (latest-wins merge)"
	echo "  pull-all        - Pull from all active peers (latest-wins merge)"
	echo "  status-all      - DB state table for all peers"
	echo "  diagnose        - Incremental sync with verbose tracing"
	echo "  full-pull/full-push - Replace entire DB | copy-plan <id> [push|pull]"
	echo "  status          - Compare both DBs | Config: $CONFIG_FILE"
	exit 1
	;;
esac
