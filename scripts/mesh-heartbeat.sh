#!/usr/bin/env bash
# mesh-heartbeat.sh — Liveness daemon: writes heartbeat to peer_heartbeats every 30s
# Version: 1.0.0
# Usage: mesh-heartbeat.sh [start|stop|status]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB="${CLAUDE_DB:-$CLAUDE_HOME/data/dashboard.db}"
PID_FILE="$CLAUDE_HOME/data/mesh-heartbeat.pid"
INTERVAL=30

# shellcheck source=lib/peers.sh
source "$SCRIPT_DIR/lib/peers.sh"

C='\033[0;36m' G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' N='\033[0m'
info() { echo -e "${C}[heartbeat]${N} $*"; }
ok() { echo -e "${G}[heartbeat]${N} $*"; }
warn() { echo -e "${Y}[heartbeat]${N} $*" >&2; }
err() { echo -e "${R}[heartbeat]${N} $*" >&2; }

# Helpers

_db() { sqlite3 "$DB" "$@"; }

_load_json() {
	local cpu tasks
	# uptime load average (1-min) — portable across macOS and Linux
	if command -v uptime &>/dev/null; then
		cpu="$(uptime 2>/dev/null | grep -oE 'load averages?: [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+$' || echo "0")"
	fi
	cpu="${cpu:-0}"

	# count in_progress tasks from DB (non-fatal if DB unavailable)
	tasks="$(_db "SELECT COUNT(*) FROM tasks WHERE status='in_progress';" 2>/dev/null || echo "0")"

	printf '{"cpu":%s,"tasks":%s}' "$cpu" "$tasks"
}

_capabilities() {
	peers_load 2>/dev/null || true
	local self
	self="$(peers_self 2>/dev/null || echo "")"
	if [[ -n "$self" ]]; then
		peers_get "$self" "capabilities" 2>/dev/null || echo ""
	else
		echo ""
	fi
}

_write_heartbeat() {
	local peer_name load_json caps
	peers_load 2>/dev/null || true
	peer_name="$(peers_self 2>/dev/null || echo "$(hostname -s 2>/dev/null || hostname)")"
	load_json="$(_load_json)"
	caps="$(_capabilities)"

	_db "INSERT OR REPLACE INTO peer_heartbeats (peer_name, last_seen, load_json, capabilities)
	     VALUES ('${peer_name}', unixepoch(), '${load_json}', '${caps}');" 2>/dev/null || {
		warn "DB write failed (will retry)"
	}
}

# Event emission: check for completed plans/waves/tasks and emit events
_emit_event() {
	local event_type="$1" plan_id="$2" payload="${3:-}"
	local peer_name
	peer_name="$(peers_self 2>/dev/null || echo "$(hostname -s 2>/dev/null || hostname)")"
	local exists
	exists=$(_db "SELECT COUNT(*) FROM mesh_events WHERE event_type='${event_type}' AND plan_id=${plan_id} AND source_peer='${peer_name}' AND status='pending';" 2>/dev/null || echo "0")
	if [[ "$exists" -eq 0 ]]; then
		_db "INSERT INTO mesh_events (event_type, plan_id, source_peer, payload) VALUES ('${event_type}', ${plan_id}, '${peer_name}', '${payload}');" 2>/dev/null || true
	fi
}

_check_plan_events() {
	local peer_name
	peer_name="$(peers_self 2>/dev/null || echo "$(hostname -s 2>/dev/null || hostname)")"
	while IFS='|' read -r plan_id plan_name tasks_done tasks_total; do
		[[ -z "$plan_id" ]] && continue
		local resolved
		resolved=$(_db "SELECT COUNT(*) FROM tasks t JOIN waves w ON t.wave_id_fk=w.id WHERE w.plan_id=${plan_id} AND t.status IN ('done','skipped','cancelled');" 2>/dev/null || echo "0")
		if [[ "$resolved" -ge "$tasks_total" && "$tasks_total" -gt 0 ]]; then
			_emit_event "plan_completed" "$plan_id" "{\"name\":\"${plan_name}\",\"tasks\":${tasks_total}}"
		fi
		local blocked
		blocked=$(_db "SELECT task_id FROM tasks t JOIN waves w ON t.wave_id_fk=w.id WHERE w.plan_id=${plan_id} AND t.status='blocked' LIMIT 1;" 2>/dev/null || echo "")
		if [[ -n "$blocked" ]]; then
			_emit_event "human_needed" "$plan_id" "{\"action\":\"blocked\",\"task\":\"${blocked}\"}"
		fi
	done < <(_db "SELECT id, name, tasks_done, tasks_total FROM plans WHERE status='doing' AND (execution_host LIKE '%${peer_name}%' OR execution_host='${peer_name}');" 2>/dev/null || true)
	while IFS='|' read -r wave_id wave_name plan_id wd wt; do
		[[ -z "$wave_id" ]] && continue
		local wave_resolved
		wave_resolved=$(_db "SELECT COUNT(*) FROM tasks WHERE wave_id_fk=(SELECT id FROM waves WHERE wave_id='${wave_id}' AND plan_id=${plan_id}) AND status IN ('done','skipped','cancelled');" 2>/dev/null || echo "0")
		if [[ "$wave_resolved" -ge "$wt" && "$wt" -gt 0 ]]; then
			_emit_event "wave_completed" "$plan_id" "{\"wave\":\"${wave_id}\",\"name\":\"${wave_name}\"}"
		fi
	done < <(_db "SELECT w.wave_id, w.name, w.plan_id, w.tasks_done, w.tasks_total FROM waves w JOIN plans p ON w.plan_id=p.id WHERE p.status='doing' AND w.status='in_progress' AND (p.execution_host LIKE '%${peer_name}%' OR p.execution_host='${peer_name}');" 2>/dev/null || true)
}
_daemon_loop() {
	local pulse=0
	while true; do
		_write_heartbeat
		# Check for plan/wave/task events (non-fatal)
		_check_plan_events 2>/dev/null || true
		# Every 10 beats (~5 min): pull config updates from coordinator
		pulse=$((pulse + 1))
		if (( pulse % 10 == 0 )); then
			local sync_script="$SCRIPT_DIR/sync-claude-config.sh"
			if [[ -x "$sync_script" ]]; then
				"$sync_script" pull >>"$CLAUDE_HOME/data/mesh-heartbeat.log" 2>&1 &
			fi
			# Auto-cleanup: kill orphan AI agent processes
			local cleanup_script="$SCRIPT_DIR/mesh-cleanup.sh"
			if [[ -x "$cleanup_script" ]]; then
				"$cleanup_script" --reset-stale --json >>"$CLAUDE_HOME/data/mesh-cleanup.log" 2>&1 &
			fi
		fi
		sleep "$INTERVAL"
	done
}

# Commands

cmd_start() {
	if [[ -f "$PID_FILE" ]]; then
		local old_pid
		old_pid="$(cat "$PID_FILE" 2>/dev/null || echo "")"
		if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
			warn "Already running (PID $old_pid). Use 'stop' first."
			return 1
		else
			warn "Stale PID file found. Removing."
			rm -f "$PID_FILE"
		fi
	fi

	if [[ ! -f "$DB" ]]; then
		err "Database not found: $DB"
		err "Set CLAUDE_DB or ensure $CLAUDE_HOME/data/dashboard.db exists."
		return 1
	fi

	# Daemonize: run loop in background, disown
	_daemon_loop </dev/null >>"$CLAUDE_HOME/data/mesh-heartbeat.log" 2>&1 &
	local pid=$!
	disown "$pid"
	echo "$pid" >"$PID_FILE"

	ok "Started (PID $pid). Writing heartbeat every ${INTERVAL}s."
	ok "Log: $CLAUDE_HOME/data/mesh-heartbeat.log"

	# Auto-sync: pull latest config from coordinator on startup
	local sync_script="$SCRIPT_DIR/sync-claude-config.sh"
	if [[ -x "$sync_script" ]]; then
		info "Pulling latest config from coordinator..."
		"$sync_script" pull >>"$CLAUDE_HOME/data/mesh-heartbeat.log" 2>&1 &
	fi
}

cmd_stop() {
	if [[ ! -f "$PID_FILE" ]]; then
		warn "No PID file found at $PID_FILE. Not running?"
		return 0
	fi
	local pid
	pid="$(cat "$PID_FILE" 2>/dev/null || echo "")"
	if [[ -z "$pid" ]]; then
		warn "Empty PID file. Removing."
		rm -f "$PID_FILE"
		return 0
	fi
	if kill -0 "$pid" 2>/dev/null; then
		kill "$pid" 2>/dev/null && ok "Stopped (PID $pid)." || err "Failed to kill PID $pid"
	else
		warn "Process $pid not running."
	fi
	rm -f "$PID_FILE"
}

cmd_status() {
	# Show daemon status
	local running="no" pid=""
	if [[ -f "$PID_FILE" ]]; then
		pid="$(cat "$PID_FILE" 2>/dev/null || echo "")"
		if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
			running="yes"
		fi
	fi

	if [[ "$running" == "yes" ]]; then
		info "Daemon: RUNNING (PID $pid)"
	else
		info "Daemon: STOPPED"
	fi

	echo ""
	# Show last_seen for all peers from DB
	if [[ ! -f "$DB" ]]; then
		warn "Database not found: $DB"
		return 0
	fi

	printf "  %-20s %-22s %-30s %s\n" "PEER" "LAST_SEEN" "LOAD" "CAPABILITIES"
	printf "  %-20s %-22s %-30s %s\n" "----" "---------" "----" "------------"

	local now
	now="$(date +%s)"

	while IFS='|' read -r peer_name last_seen load_json caps; do
		[[ -z "$peer_name" ]] && continue
		local age_str="never"
		if [[ -n "$last_seen" && "$last_seen" =~ ^[0-9]+$ ]]; then
			local age=$((now - last_seen))
			if ((age < 60)); then
				age_str="${age}s ago"
			elif ((age < 3600)); then
				age_str="$((age / 60))m ago"
			else
				age_str="$((age / 3600))h ago"
			fi
		fi
		printf "  %-20s %-22s %-30s %s\n" \
			"$peer_name" "$age_str" "${load_json:-{}}" "${caps:-}"
	done < <(_db "SELECT peer_name, last_seen, load_json, capabilities
	              FROM peer_heartbeats ORDER BY peer_name;" 2>/dev/null || true)

	echo ""
}

# Main

case "${1:-}" in
start) cmd_start ;;
stop) cmd_stop ;;
status) cmd_status ;;
ping) _write_heartbeat && ok "Heartbeat written" ;;
-h | --help | help)
	echo "Usage: $(basename "$0") [start|stop|status|ping]"
	echo "  start  — start heartbeat daemon (every ${INTERVAL}s)"
	echo "  stop   — stop heartbeat daemon"
	echo "  status — show last_seen for all peers"
	echo "  ping   — write a single heartbeat now"
	;;
"")
	err "No command given. Use: start|stop|status"
	echo "Usage: $(basename "$0") [start|stop|status]" >&2
	exit 1
	;;
*)
	err "Unknown command: $1. Use: start|stop|status"
	exit 1
	;;
esac
