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
		local pid=$(cat "$PID_FILE")
		local sync_time="never"
		[[ -f "$LAST_SYNC_FILE" ]] && sync_time=$(cat "$LAST_SYNC_FILE")
		local hb=$(sqlite3 "$DB_FILE" "SELECT last_seen FROM host_heartbeats WHERE host='$PLAN_DB_HOST';" 2>/dev/null || echo "none")
		echo "Autosync: RUNNING (PID: $pid) | Host: $PLAN_DB_HOST | Last sync: $sync_time | Heartbeat: $hb"
	else
		echo "Autosync: STOPPED"
		rm -f "$PID_FILE"
	fi
}

_is_running() {
	[[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

_daemon() {
	trap 'log "Daemon exiting"; exit 0' TERM INT

	local last_heartbeat=0
	local pending_sync=0
	local last_change=0
	local consecutive_failures=0

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

_run_incremental_sync() {
	# Determine active execution host
	local exec_host
	exec_host=$(sqlite3 "$DB_FILE" \
		"SELECT execution_host FROM plans WHERE status='doing' ORDER BY id DESC LIMIT 1;" 2>/dev/null || echo "")

	# If a plan is executing on a REMOTE host, pull full DB from there
	if [[ -n "$exec_host" && "$exec_host" != "$PLAN_DB_HOST" ]]; then
		_pull_from_remote "$exec_host"
		return
	fi

	# Check SSH connectivity before trying
	if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$(get_remote_host)" "echo ok" &>/dev/null; then
		log "Sync skipped: remote unreachable"
		return 0
	fi

	log "Starting incremental sync..."
	if "$SYNC_SCRIPT" incremental 2>>"$LOG_FILE"; then
		date '+%Y-%m-%d %H:%M:%S' >"$LAST_SYNC_FILE"
		log "Sync completed"
		consecutive_failures=0
	else
		consecutive_failures=$((consecutive_failures + 1))
		log "Sync failed (consecutive: $consecutive_failures)"
		if ((consecutive_failures >= 10)); then
			log "WARNING: $consecutive_failures consecutive sync failures — falling back to full pull"
			_pull_from_remote "$(get_remote_host)"
		fi
	fi

	# Config sync: check if ~/.claude repo needs push
	_sync_config
}

# Pull full DB from remote execution host (atomic, WAL-safe)
_pull_from_remote() {
	local remote_host="$1"
	local ssh_target=""
	local peers_conf="${HOME}/.claude/config/peers.conf"
	if [[ -f "$peers_conf" ]]; then
		ssh_target=$(awk -F= -v h="$remote_host" '
			/^\[/{section=$0; gsub(/[\[\]]/,"",section)}
			section==h && /^ssh_alias=/{print $2; exit}
		' "$peers_conf" 2>/dev/null || echo "")
	fi
	[[ -z "$ssh_target" ]] && ssh_target="$remote_host"
	log "Pulling DB from $remote_host ($ssh_target)..."
	if "$SCRIPT_DIR/db-pull.sh" "$ssh_target" >>"$LOG_FILE" 2>&1; then
		date '+%Y-%m-%d %H:%M:%S' >"$LAST_SYNC_FILE"
		log "DB pull from $remote_host completed"
		consecutive_failures=0
	else
		consecutive_failures=$((consecutive_failures + 1))
		log "DB pull from $remote_host FAILED (consecutive: $consecutive_failures)"
	fi
}

_sync_config() {
	local r
	r=$(config_sync_check 2>/dev/null) || r="ERROR"
	[[ "$r" == "SYNCED" ]] && return
	log "Config sync: $r"
}

cmd_autosync "${1:-status}"
