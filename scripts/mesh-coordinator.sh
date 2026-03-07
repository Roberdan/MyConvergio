#!/usr/bin/env bash
# mesh-coordinator.sh — Event-driven coordinator daemon for coordinator node.
# Processes mesh_events, handles auto-finish, offline detection, auto-reassign.
# Usage: mesh-coordinator.sh [start|stop|status|run-once|--help]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB="${CLAUDE_DB:-$CLAUDE_HOME/data/dashboard.db}"
PID_FILE="$CLAUDE_HOME/data/mesh-coordinator.pid"
LOG_FILE="$CLAUDE_HOME/logs/mesh-coordinator.log"
INTERVAL=15
OFFLINE_THRESHOLD=900   # 15 min
REASSIGN_THRESHOLD=1800 # 30 min
REASSIGN_GRACE=2        # cycles before reassign
SCRIPT_MTIME="$(stat -f %m "$0" 2>/dev/null || stat -c %Y "$0" 2>/dev/null || echo 0)"

source "$SCRIPT_DIR/lib/peers.sh"
source "$SCRIPT_DIR/lib/notify-config.sh"
peers_load 2>/dev/null || true
notify_load 2>/dev/null || true

C='\033[0;36m' G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' N='\033[0m'
_log() { echo -e "[$(date '+%H:%M:%S')] $*"; }
_info() { _log "${C}[coord]${N} $*"; }
_ok() { _log "${G}[coord]${N} $*"; }
_warn() { _log "${Y}[coord]${N} $*"; }
_err() { _log "${R}[coord]${N} $*"; }
_db() { sqlite3 "$DB" ".timeout 5000" "$@" 2>/dev/null; }
_notify() {
	local sev="$1" title="$2" msg="$3"
	shift 3
	[[ -x "$SCRIPT_DIR/mesh-notify.sh" ]] && "$SCRIPT_DIR/mesh-notify.sh" "$sev" "$title" "$msg" "$@" 2>/dev/null || true
}

# Event handlers
_handle_plan_completed() {
	local plan_id="$1" source_peer="$2" payload="$3"
	local plan_name
	plan_name=$(_db "SELECT name FROM plans WHERE id=$plan_id;" || echo "Plan#$plan_id")
	_info "Plan completed: #$plan_id ($plan_name) on $source_peer"
	# Pull DB from peer
	local pc_alias
	pc_alias=$(python3 -c "
import sys; sys.path.insert(0,'$SCRIPT_DIR/dashboard_web')
from mesh_handoff import pull_db_from_peer
import configparser; cp=configparser.ConfigParser()
cp.read('$CLAUDE_HOME/config/peers.conf')
for s in cp.sections():
  if s=='$source_peer': print(cp[s].get('ssh_alias',s)); break
" 2>/dev/null || echo "")
	if [[ -n "$pc_alias" ]]; then
		python3 -c "
import sys; sys.path.insert(0,'$SCRIPT_DIR/dashboard_web')
from mesh_handoff import pull_db_from_peer
ok, detail = pull_db_from_peer('$pc_alias', [$plan_id])
print(f'Pull: {\"OK\" if ok else \"FAIL\"} — {detail}')
" 2>/dev/null || _warn "DB pull failed from $source_peer"
	fi
	# Complete plan if not already
	local status
	status=$(_db "SELECT status FROM plans WHERE id=$plan_id;" || echo "")
	if [[ "$status" == "doing" ]]; then
		"$SCRIPT_DIR/plan-db.sh" complete "$plan_id" 2>/dev/null &&
			_ok "Plan #$plan_id marked complete" ||
			_warn "plan-db.sh complete failed (may need manual)"
	fi
	# Sync to all nodes
	"$SCRIPT_DIR/mesh-sync-all.sh" 2>>"$LOG_FILE" &
	_notify info "Plan #$plan_id completed" "$plan_name finished on $source_peer" \
		--link "http://localhost:8420/#plan/$plan_id" --plan-id "$plan_id"
}

_handle_wave_completed() {
	local plan_id="$1" source_peer="$2" payload="$3"
	local wave_id
	wave_id=$(echo "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('wave','?'))" 2>/dev/null || echo "?")
	_info "Wave $wave_id completed on plan #$plan_id ($source_peer)"
	_notify info "Wave $wave_id done" "Plan #$plan_id — wave completed on $source_peer" \
		--link "http://localhost:8420/#plan/$plan_id" --plan-id "$plan_id"
}

_handle_human_needed() {
	local plan_id="$1" source_peer="$2" payload="$3"
	local action task_id
	action=$(echo "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('action','unknown'))" 2>/dev/null || echo "unknown")
	task_id=$(echo "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('task',''))" 2>/dev/null || echo "")
	_warn "Human needed: $action on plan #$plan_id (task: $task_id)"
	local sev="warning"
	[[ "$action" == "merge" ]] && sev="action_required"
	[[ "$action" == "thor_reject" ]] && sev="warning"
	_notify "$sev" "Action needed: $action" "Plan #$plan_id task $task_id on $source_peer" \
		--link "http://localhost:8420/#plan/$plan_id" --plan-id "$plan_id"
}

_handle_task_change() {
	local plan_id="$1" source_peer="$2" payload="$3"
	_info "Task status change on plan #$plan_id from $source_peer"
}

# Process pending events
_process_events() {
	local processed=0
	while IFS='|' read -r eid etype plan_id source_peer payload; do
		[[ -z "$eid" ]] && continue
		case "$etype" in
		plan_completed) _handle_plan_completed "$plan_id" "$source_peer" "$payload" ;;
		wave_completed) _handle_wave_completed "$plan_id" "$source_peer" "$payload" ;;
		human_needed) _handle_human_needed "$plan_id" "$source_peer" "$payload" ;;
		task_status_changed) _handle_task_change "$plan_id" "$source_peer" "$payload" ;;
		node_offline) _warn "Node offline event: $source_peer" ;;
		*) _info "Unknown event: $etype" ;;
		esac
		_db "UPDATE mesh_events SET status='delivered', delivered_at=unixepoch() WHERE id=$eid;"
		((processed++)) || true
	done < <(_db "SELECT id, event_type, plan_id, source_peer, COALESCE(payload,'{}') FROM mesh_events WHERE status='pending' ORDER BY created_at LIMIT 20;")
	[[ $processed -gt 0 ]] && _info "Processed $processed event(s)"
}

# Offline detection — NOTIFY ONLY, never auto-reassign (requires user approval)
_check_offline_nodes() {
	local now
	now=$(date +%s)
	while IFS='|' read -r peer_name last_seen; do
		[[ -z "$peer_name" ]] && continue
		local age=$((now - last_seen))
		[[ $age -lt $OFFLINE_THRESHOLD ]] && continue
		# Check active plans on this peer
		local active_plans
		active_plans=$(_db "SELECT id FROM plans WHERE status='doing' AND (execution_host='$peer_name' OR execution_host LIKE '%$peer_name%') LIMIT 5;")
		[[ -z "$active_plans" ]] && continue
		# Deduplicate: only notify once per offline window (counter tracks)
		local counter_file="/tmp/mesh-offline-${peer_name}.count"
		local count=0
		[[ -f "$counter_file" ]] && count=$(cat "$counter_file" 2>/dev/null || echo "0")
		count=$((count + 1))
		echo "$count" >"$counter_file"
		# Cap: once past grace + 1, stop logging (notification already sent)
		if [[ $count -gt $((REASSIGN_GRACE + 1)) ]]; then
			continue
		fi
		# First detection: warn. After grace: notify critical (but NEVER reassign)
		if [[ $count -le 1 ]]; then
			_warn "Node $peer_name offline (${age}s). Plans affected: $(echo "$active_plans" | tr '\n' ',' | sed 's/,$//')"
		elif [[ $count -eq $REASSIGN_GRACE ]]; then
			while IFS= read -r pid; do
				[[ -z "$pid" ]] && continue
				local current_host
				current_host=$(_db "SELECT execution_host FROM plans WHERE id=$pid;")
				if [[ -n "$current_host" && "$current_host" != "$peer_name" ]]; then
					continue # already reassigned
				fi
				_notify critical "Node $peer_name offline" \
					"Plan #$pid needs manual reassignment (use dashboard Delegate or mesh-migrate.sh)" \
					--link "http://localhost:8420/#plan/$pid" --plan-id "$pid"
			done <<<"$active_plans"
		fi
		# Never auto-reassign — log only
	done < <(_db "SELECT peer_name, last_seen FROM peer_heartbeats WHERE peer_name != '$(peers_self 2>/dev/null || hostname -s)' ORDER BY peer_name;")
	# Clean counters for online peers
	while IFS='|' read -r peer_name last_seen; do
		[[ -z "$peer_name" ]] && continue
		local age=$((now - last_seen))
		[[ $age -lt $OFFLINE_THRESHOLD ]] && rm -f "/tmp/mesh-offline-${peer_name}.count" 2>/dev/null
	done < <(_db "SELECT peer_name, last_seen FROM peer_heartbeats;")
}

_run_once() { _process_events; _check_offline_nodes; }

_check_script_update() {
	local current_mtime="$(stat -f %m "${BASH_SOURCE[0]}" 2>/dev/null || stat -c %Y "${BASH_SOURCE[0]}" 2>/dev/null || echo 0)"
	[[ "$current_mtime" == "$SCRIPT_MTIME" ]] && return 0
	_info "Script updated (mtime $SCRIPT_MTIME → $current_mtime), restarting..."
	exec "$0" start
}

# Daemon loop
_daemon_loop() {
	local cycle_count=0
	_info "Coordinator started (interval: ${INTERVAL}s)"
	while true; do
		cycle_count=$((cycle_count + 1))
		_run_once 2>>"$LOG_FILE" || true
		((cycle_count % 10 == 0)) && _check_script_update
		sleep "$INTERVAL"
	done
}

# Commands
cmd_start() {
	if [[ -f "$PID_FILE" ]]; then
		local old_pid
		old_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
		if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
			_warn "Already running (PID $old_pid)"
			return 1
		fi
		rm -f "$PID_FILE"
	fi
	mkdir -p "$(dirname "$LOG_FILE")"
	_daemon_loop </dev/null >>"$LOG_FILE" 2>&1 &
	local pid=$!
	disown "$pid"
	echo "$pid" >"$PID_FILE"
	_ok "Started (PID $pid). Log: $LOG_FILE"
}
cmd_stop() {
	[[ ! -f "$PID_FILE" ]] && {
		_warn "Not running"
		return 0
	}
	local pid
	pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
	[[ -n "$pid" ]] && kill "$pid" 2>/dev/null && _ok "Stopped (PID $pid)" || _warn "PID $pid not running"
	rm -f "$PID_FILE"
}
cmd_status() {
	local running="no" pid=""
	if [[ -f "$PID_FILE" ]]; then
		pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
		[[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && running="yes"
	fi
	local pending
	pending=$(_db "SELECT COUNT(*) FROM mesh_events WHERE status='pending';" || echo "0")
	echo "{\"running\":$([ "$running" = "yes" ] && echo "true" || echo "false"),\"pid\":\"${pid:-}\",\"pending_events\":$pending}"
}
cmd_check() { _run_once; }

# Main
case "${1:-}" in
start) cmd_start ;;
stop) cmd_stop ;;
status) cmd_status ;;
run-once | --check) cmd_check ;;
-h | --help | help)
	echo "Usage: $(basename "$0") [start|stop|status|run-once]"
	echo "  start    — start coordinator daemon"
	echo "  stop     — stop daemon"
	echo "  status   — JSON status (running, pending events)"
	echo "  run-once — single processing cycle"
	;;
"")
	_err "No command. Use: start|stop|status|run-once"
	exit 1
	;;
*)
	_err "Unknown: $1"
	exit 1
	;;
esac
