#!/bin/bash
set -euo pipefail
# file-lock-utils.sh - List and cleanup utilities for file locks
# Sourced by file-lock.sh for list and cleanup commands.
# Version: 1.0.0
#
# Dependencies: file-lock.sh must source this (provides db_query, sql_escape,
# STALE_HEARTBEAT_SEC, STALE_MAX_AGE_SEC)

cmd_list() {
	local filter=""
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--plan-id)
			filter="AND plan_id=$2"
			shift 2
			;;
		--task-id)
			filter="AND task_id='$(sql_escape "$2")'"
			shift 2
			;;
		--session-id)
			filter="AND session_id='$(sql_escape "$2")'"
			shift 2
			;;
		*) shift ;;
		esac
	done
	db_query "
		SELECT json_group_array(json_object(
			'file', file_path, 'task_id', task_id, 'session_id', session_id,
			'agent', agent_name, 'pid', pid, 'host', host,
			'age_sec', (strftime('%s','now') - strftime('%s', acquired_at)),
			'heartbeat_age', (strftime('%s','now') - strftime('%s', heartbeat_at))
		)) FROM file_locks WHERE 1=1 $filter;
	"
}

cmd_cleanup() {
	local max_age="$STALE_MAX_AGE_SEC" dry_run=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--max-age)
			max_age=$(($2 * 60))
			shift 2
			;;
		--dry-run)
			dry_run=1
			shift
			;;
		*) shift ;;
		esac
	done

	if [[ $dry_run -eq 1 ]]; then
		db_query "
			SELECT json_group_array(json_object('file', file_path, 'task_id', task_id,
				'session_id', session_id,
				'age_sec', (strftime('%s','now') - strftime('%s', acquired_at))))
			FROM file_locks
			WHERE (strftime('%s','now') - strftime('%s', heartbeat_at)) > $STALE_HEARTBEAT_SEC;
		"
	else
		local deleted
		deleted=$(db_query "
			DELETE FROM file_locks
			WHERE (strftime('%s','now') - strftime('%s', heartbeat_at)) > $max_age;
			SELECT changes();
		")
		jq -n --argjson n "$deleted" '{"cleaned":$n}'
	fi
}
