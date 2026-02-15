#!/usr/bin/env bash
# Version: 1.1.0
set -euo pipefail

# plan-db-autosync.sh - Auto-sync daemon for dashboard.db
# Watches DB for changes, runs incremental sync, sends heartbeats
# Usage: plan-db-autosync.sh [start|stop|status]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${HOME}/.claude/data/dashboard.db"
PID_FILE="${HOME}/.claude/data/autosync.pid"
LOG_FILE="${HOME}/.claude/data/autosync.log"
SYNC_SCRIPT="$SCRIPT_DIR/sync-dashboard-db.sh"
LAST_SYNC_FILE="${HOME}/.claude/data/last-sync.txt"

DEBOUNCE_SECS=5
HEARTBEAT_INTERVAL=60

# Source core for hostname normalization
source "$SCRIPT_DIR/lib/plan-db-core.sh"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >>"$LOG_FILE"; }

# ============================================================
# cmd_autosync <start|stop|status>
# ============================================================
cmd_autosync() {
	local action="${1:-status}"
	case "$action" in
	start) _autosync_start ;;
	stop) _autosync_stop ;;
	status) _autosync_status ;;
	*)
		echo "Usage: plan-db-autosync.sh [start|stop|status]"
		return 1
		;;
	esac
}

_autosync_start() {
	if _is_running; then
		echo "Autosync already running (PID: $(cat "$PID_FILE"))"
		return 0
	fi

	mkdir -p "$(dirname "$PID_FILE")" "$(dirname "$LOG_FILE")"

	# Launch daemon in background
	_daemon &
	local daemon_pid=$!
	echo "$daemon_pid" >"$PID_FILE"

	log "Daemon started (PID: $daemon_pid, host: $PLAN_DB_HOST)"
	echo "Autosync started (PID: $daemon_pid)"
}

_autosync_stop() {
	if ! _is_running; then
		echo "Autosync not running"
		rm -f "$PID_FILE"
		return 0
	fi

	local pid
	pid=$(cat "$PID_FILE")
	kill "$pid" 2>/dev/null || true
	rm -f "$PID_FILE"
	log "Daemon stopped (PID: $pid)"
	echo "Autosync stopped (PID: $pid)"
}

_autosync_status() {
	if _is_running; then
		local pid
		pid=$(cat "$PID_FILE")
		echo "Autosync: RUNNING (PID: $pid)"
		echo "Host: $PLAN_DB_HOST"
		echo "DB: $DB_FILE"

		# Show last sync time
		if [[ -f "$LAST_SYNC_FILE" ]]; then
			echo "Last sync: $(cat "$LAST_SYNC_FILE")"
		else
			echo "Last sync: never"
		fi

		# Show last heartbeat
		local hb
		hb=$(sqlite3 "$DB_FILE" "SELECT last_seen FROM host_heartbeats WHERE host='$PLAN_DB_HOST';" 2>/dev/null || echo "none")
		echo "Last heartbeat: $hb"
	else
		echo "Autosync: STOPPED"
		rm -f "$PID_FILE"
	fi
}

_is_running() {
	[[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

# ============================================================
# Daemon main loop
# ============================================================
_daemon() {
	trap 'log "Daemon exiting"; exit 0' TERM INT

	local last_heartbeat=0
	local pending_sync=0
	local last_change=0

	while true; do
		local now
		now=$(date +%s)

		# Heartbeat every HEARTBEAT_INTERVAL seconds
		if ((now - last_heartbeat >= HEARTBEAT_INTERVAL)); then
			_send_heartbeat
			last_heartbeat=$now
		fi

		# Check DB modification time for changes
		local db_mtime
		db_mtime=$(_get_mtime "$DB_FILE")

		if ((db_mtime > last_change)); then
			last_change=$db_mtime
			pending_sync=1
		fi

		# Debounced sync: run if pending and no changes for DEBOUNCE_SECS
		if ((pending_sync == 1)) && ((now - last_change >= DEBOUNCE_SECS)); then
			_run_incremental_sync
			pending_sync=0
		fi

		sleep 2
	done
}

# Cross-platform file modification time (epoch seconds)
_get_mtime() {
	if [[ "$(uname)" == "Darwin" ]]; then
		stat -f '%m' "$1" 2>/dev/null || echo 0
	else
		stat -c '%Y' "$1" 2>/dev/null || echo 0
	fi
}

# ============================================================
# Heartbeat
# ============================================================
_send_heartbeat() {
	local plan_count
	plan_count=$(sqlite3 "$DB_FILE" \
		"SELECT COUNT(*) FROM plans WHERE execution_host='$PLAN_DB_HOST' AND status='doing';" 2>/dev/null || echo 0)
	local os_name
	os_name=$(uname -s)

	local safe_host
	safe_host=$(sql_escape "$PLAN_DB_HOST")
	sqlite3 "$DB_FILE" "
		INSERT OR REPLACE INTO host_heartbeats (host, last_seen, plan_count, os)
		VALUES ('${safe_host}', datetime('now'), $plan_count, '$os_name');
	" 2>/dev/null

	log "Heartbeat: plans=$plan_count os=$os_name"
}

# ============================================================
# Incremental sync
# ============================================================
_run_incremental_sync() {
	# Check SSH connectivity before trying
	if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$(get_remote_host)" "echo ok" &>/dev/null; then
		log "Sync skipped: remote unreachable"
		return 0
	fi

	log "Starting incremental sync..."
	if "$SYNC_SCRIPT" incremental 2>/dev/null; then
		date '+%Y-%m-%d %H:%M:%S' >"$LAST_SYNC_FILE"
		log "Sync completed"
	else
		log "Sync failed"
	fi

	# Config sync: check if ~/.claude repo needs push
	_sync_config
}

# ============================================================
# Config sync (T4-05)
# ============================================================
_sync_config() {
	local sync_result
	sync_result=$(config_sync_check 2>/dev/null) || sync_result="ERROR"

	case "$sync_result" in
	SYNCED) ;; # Nothing to do
	PUSHED) log "Config auto-pushed to remote" ;;
	DIVERGED) log "Config DIVERGED — manual resolution needed" ;;
	OFFLINE) log "Config sync skipped: remote offline" ;;
	*) log "Config sync check: $sync_result" ;;
	esac
}

# ============================================================
# Entry point
# ============================================================
cmd_autosync "${1:-status}"
