#!/bin/bash
set -euo pipefail
# file-lock-session.sh - Session-based file locking (non-plan workflow)
# Sourced by file-lock.sh for acquire-session and release-session commands.
# Provides re-entrant locking using session_id instead of task_id.
# Version: 1.0.0
#
# Dependencies: file-lock.sh must source this (provides db_query, sql_escape,
# _resolve_path, STALE_HEARTBEAT_SEC, PLAN_DB_HOST)

cmd_acquire_session() {
	local file="$1" session_id="$2" agent="${3:-session-agent}" timeout="${4:-5}"
	local abs_path
	abs_path=$(_resolve_path "$file")
	local deadline=$((SECONDS + timeout))

	while true; do
		# Re-entrant: if same session already holds it, refresh heartbeat
		local holder_sid
		holder_sid=$(db_query "
			SELECT session_id FROM file_locks
			WHERE file_path='$(sql_escape "$abs_path")';
		")
		if [[ "$holder_sid" == "$session_id" ]]; then
			db_query "UPDATE file_locks SET heartbeat_at=datetime('now')
				WHERE file_path='$(sql_escape "$abs_path")';"
			jq -n --arg f "$abs_path" --arg s "$session_id" \
				'{"status":"reentrant","file":$f,"session_id":$s}'
			return 0
		fi

		# Atomic: clean stale + insert
		if db_query "
			BEGIN EXCLUSIVE;
			DELETE FROM file_locks
				WHERE file_path='$(sql_escape "$abs_path")'
				AND host='$(sql_escape "$PLAN_DB_HOST")'
				AND (strftime('%s','now') - strftime('%s', heartbeat_at)) > $STALE_HEARTBEAT_SEC;
			INSERT INTO file_locks (file_path, session_id, agent_name, pid, host)
			VALUES ('$(sql_escape "$abs_path")', '$(sql_escape "$session_id")',
				'$(sql_escape "$agent")', $$, '$(sql_escape "$PLAN_DB_HOST")');
			COMMIT;
		" 2>/dev/null; then
			jq -n --arg f "$abs_path" --arg s "$session_id" \
				'{"status":"acquired","file":$f,"session_id":$s}'
			return 0
		fi

		# Timeout check
		if [[ $SECONDS -ge $deadline ]]; then
			local holder
			holder=$(db_query "
				SELECT json_object('task_id', task_id, 'session_id', session_id,
					'agent', agent_name, 'pid', pid, 'host', host,
					'age_sec', (strftime('%s','now') - strftime('%s', acquired_at)))
				FROM file_locks WHERE file_path='$(sql_escape "$abs_path")';
			")
			jq -n --arg f "$abs_path" --argjson h "${holder:-null}" \
				'{"status":"blocked","file":$f,"held_by":$h}' >&2
			return 1
		fi

		sleep 0.$((100 + RANDOM % 400))
	done
}

cmd_release_session() {
	local session_id="$1"
	local deleted
	deleted=$(db_query "
		DELETE FROM file_locks WHERE session_id='$(sql_escape "$session_id")';
		SELECT changes();
	")
	jq -n --arg s "$session_id" --argjson n "$deleted" \
		'{"session_id":$s,"released_count":$n}'
}
