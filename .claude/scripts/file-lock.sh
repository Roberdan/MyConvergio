#!/bin/bash
# file-lock.sh - File-level locking for concurrent agent work
# Backend: SQLite (dashboard.db). Commands: acquire|release|release-task|check|heartbeat|list|cleanup
# Session commands: acquire-session|release-session (non-plan workflow)
# Version: 2.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/plan-db-core.sh"

STALE_HEARTBEAT_SEC=300 # 5 minutes
STALE_MAX_AGE_SEC=1800  # 30 minutes
DEFAULT_TIMEOUT=30      # seconds

# Resolve to absolute path
_resolve_path() {
	local p="$1"
	if [[ "$p" != /* ]]; then p="$(pwd)/$p"; fi
	# Normalize without python3 (avoid 150ms startup penalty)
	# Remove /./  then collapse /../  then strip trailing /
	while [[ "$p" == */./* ]]; do p="${p//\/.\///}"; done
	while [[ "$p" == */../* ]]; do
		p=$(echo "$p" | sed 's|/[^/][^/]*/\.\./|/|')
	done
	echo "${p%/}"
}

# Check if a PID is alive on this host
_pid_alive() {
	local pid="$1" host="$2"
	[[ "$host" != "$PLAN_DB_HOST" ]] && return 0 # assume alive on remote
	kill -0 "$pid" 2>/dev/null
}

# Remove stale lock (PID dead + heartbeat old)
_try_break_stale() {
	local file_path="$1"
	local lock_info
	lock_info=$(db_query "
		SELECT json_object('pid', pid, 'host', host, 'task_id', task_id,
			'heartbeat_age', (strftime('%s','now') - strftime('%s', heartbeat_at)))
		FROM file_locks WHERE file_path='$(sql_escape "$file_path")';
	")
	[[ -z "$lock_info" || "$lock_info" == "null" ]] && return 0

	local pid host hb_age
	pid=$(echo "$lock_info" | jq -r '.pid')
	host=$(echo "$lock_info" | jq -r '.host')
	hb_age=$(echo "$lock_info" | jq -r '.heartbeat_age')

	# Lock is stale if: PID dead on same host AND heartbeat older than threshold
	if ! _pid_alive "$pid" "$host" && [[ "$hb_age" -gt "$STALE_HEARTBEAT_SEC" ]]; then
		db_query "DELETE FROM file_locks WHERE file_path='$(sql_escape "$file_path")';"
		log_warn "Broke stale lock on $file_path (pid=$pid, age=${hb_age}s)"
		return 0
	fi
	return 1
}

cmd_acquire() {
	local file="" task_id="" agent="unknown" plan_id="NULL" timeout="$DEFAULT_TIMEOUT"

	file="$1"
	task_id="$2"
	shift 2
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--agent)
			agent="$2"
			shift 2
			;;
		--plan-id)
			plan_id="$2"
			shift 2
			;;
		--timeout)
			timeout="$2"
			shift 2
			;;
		*) shift ;;
		esac
	done

	local abs_path
	abs_path=$(_resolve_path "$file")
	local deadline=$((SECONDS + timeout))

	while true; do
		# Atomic: delete stale + insert in exclusive transaction (prevents race conditions)
		if db_query "
			BEGIN EXCLUSIVE;
			DELETE FROM file_locks
				WHERE file_path='$(sql_escape "$abs_path")'
				AND host='$(sql_escape "$PLAN_DB_HOST")'
				AND (strftime('%s','now') - strftime('%s', heartbeat_at)) > $STALE_HEARTBEAT_SEC;
			INSERT INTO file_locks (file_path, task_id, plan_id, agent_name, pid, host)
			VALUES ('$(sql_escape "$abs_path")', '$(sql_escape "$task_id")',
				$plan_id, '$(sql_escape "$agent")', $$, '$(sql_escape "$PLAN_DB_HOST")');
			COMMIT;
		" 2>/dev/null; then
			jq -n --arg f "$abs_path" --arg t "$task_id" \
				'{"status":"acquired","file":$f,"task_id":$t}'
			return 0
		fi

		# Check timeout
		if [[ $SECONDS -ge $deadline ]]; then
			local holder
			holder=$(db_query "
				SELECT json_object('task_id', task_id, 'agent', agent_name,
					'pid', pid, 'host', host,
					'age_sec', (strftime('%s','now') - strftime('%s', acquired_at)))
				FROM file_locks WHERE file_path='$(sql_escape "$abs_path")';
			")
			jq -n --arg f "$abs_path" --argjson h "$holder" \
				'{"status":"blocked","file":$f,"held_by":$h}' >&2
			return 1
		fi

		# Exponential backoff with jitter (100ms base, cap 2s)
		local attempt=$(((SECONDS - deadline + timeout) / 2 + 1))
		local jitter=$((RANDOM % 100))
		local base_ms=$((100 * (1 << attempt)))
		[[ $base_ms -gt 2000 ]] && base_ms=2000
		local delay_ms=$(((base_ms / 2) + (base_ms * jitter / 200)))
		sleep "0.${delay_ms}"
	done
}

cmd_release() {
	local file="$1" task_id="${2:-}"
	local abs_path
	abs_path=$(_resolve_path "$file")

	local where="file_path='$(sql_escape "$abs_path")'"
	[[ -n "$task_id" ]] && where="$where AND task_id='$(sql_escape "$task_id")'"

	local deleted
	deleted=$(db_query "DELETE FROM file_locks WHERE $where; SELECT changes();")
	jq -n --arg f "$abs_path" --argjson n "$deleted" '{"released":$f,"count":$n}'
}

cmd_release_task() {
	local task_id="$1"
	local deleted
	deleted=$(db_query "
		DELETE FROM file_locks WHERE task_id='$(sql_escape "$task_id")';
		SELECT changes();
	")
	jq -n --arg t "$task_id" --argjson n "$deleted" '{"task_id":$t,"released_count":$n}'
}

cmd_check() {
	local file="$1"
	local abs_path
	abs_path=$(_resolve_path "$file")
	local info
	info=$(db_query "
		SELECT json_object('locked', 1, 'file', file_path, 'task_id', task_id,
			'agent', agent_name, 'pid', pid, 'host', host,
			'age_sec', (strftime('%s','now') - strftime('%s', acquired_at)),
			'heartbeat_age', (strftime('%s','now') - strftime('%s', heartbeat_at)))
		FROM file_locks WHERE file_path='$(sql_escape "$abs_path")';
	")
	if [[ -z "$info" ]]; then
		jq -n --arg f "$abs_path" '{"locked":false,"file":$f}'
	else
		echo "$info"
	fi
}

cmd_heartbeat() {
	local file="$1" task_id="${2:-}"
	local abs_path
	abs_path=$(_resolve_path "$file")
	local where="file_path='$(sql_escape "$abs_path")'"
	[[ -n "$task_id" ]] && where="$where AND task_id='$(sql_escape "$task_id")'"
	db_query "UPDATE file_locks SET heartbeat_at=datetime('now') WHERE $where;"
	echo '{"heartbeat":"updated"}'
}

# list and cleanup are in file-lock-utils.sh (split for 250-line limit)

# Dispatch
case "${1:-help}" in
acquire) cmd_acquire "${2:?file required}" "${3:?task_id required}" "${@:4}" ;;
acquire-session)
	source "$SCRIPT_DIR/file-lock-session.sh"
	cmd_acquire_session "${2:?file required}" "${3:?session_id required}" "${4:-session-agent}" "${5:-5}"
	;;
release) cmd_release "${2:?file required}" "${3:-}" ;;
release-task) cmd_release_task "${2:?task_id required}" ;;
release-session)
	source "$SCRIPT_DIR/file-lock-session.sh"
	cmd_release_session "${2:?session_id required}"
	;;
check) cmd_check "${2:?file required}" ;;
heartbeat) cmd_heartbeat "${2:?file required}" "${3:-}" ;;
list)
	source "$SCRIPT_DIR/file-lock-utils.sh"
	cmd_list "${@:2}"
	;;
cleanup)
	source "$SCRIPT_DIR/file-lock-utils.sh"
	cmd_cleanup "${@:2}"
	;;
*)
	echo "Usage: file-lock.sh <command> [args]"
	echo "  acquire <file> <task_id> [--agent N] [--plan-id N] [--timeout N]"
	echo "  acquire-session <file> <session_id> [agent] [timeout_sec]"
	echo "  release <file> [task_id]"
	echo "  release-task <task_id>  |  release-session <session_id>"
	echo "  check <file>  |  heartbeat <file> [task_id]"
	echo "  list [--plan-id N] [--task-id ID]  |  cleanup [--max-age MIN]"
	;;
esac
