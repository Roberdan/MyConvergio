#!/bin/bash
# stale-check.sh - Detect when files changed under an agent's feet
# Backend: SQLite (dashboard.db) file_snapshots table
# Usage: stale-check.sh <command> [args]
#
# Commands:
#   snapshot <task_id> <file1> [file2...] - Record file hashes
#   check <task_id>                       - Check if files changed
#   diff <task_id>                        - Show changed files with details
#   cleanup [task_id]                     - Remove snapshots
# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/plan-db-core.sh"

# Detect hash command once at startup
if command -v shasum &>/dev/null; then
	_HASH_CMD="shasum -a 256"
elif command -v sha256sum &>/dev/null; then
	_HASH_CMD="sha256sum"
else
	_HASH_CMD="md5"
fi

# Cross-platform file hash (SHA-256)
_file_hash() {
	if [[ ! -f "$1" ]]; then
		echo "MISSING"
		return
	fi
	if [[ "$_HASH_CMD" == "md5" ]]; then
		md5 -q "$1" 2>/dev/null || md5sum "$1" | cut -d' ' -f1
	else
		$_HASH_CMD "$1" | cut -d' ' -f1
	fi
}

# Resolve to absolute path (pure bash, no python3 overhead)
_resolve_path() {
	local p="$1"
	[[ "$p" != /* ]] && p="$(pwd)/$p"
	while [[ "$p" == */./* ]]; do p="${p//\/.\///}"; done
	while [[ "$p" == */../* ]]; do p=$(echo "$p" | sed 's|/[^/][^/]*/\.\./|/|'); done
	echo "${p%/}"
}

# Get current branch
_current_branch() {
	git branch --show-current 2>/dev/null || echo "unknown"
}

cmd_snapshot() {
	local task_id="$1"
	shift
	local branch
	branch=$(_current_branch)
	local count=0 sql="BEGIN;"

	# Batch all inserts into a single transaction
	for file in "$@"; do
		local abs_path hash
		abs_path=$(_resolve_path "$file")
		hash=$(_file_hash "$abs_path")
		sql="$sql INSERT OR REPLACE INTO file_snapshots (task_id, file_path, file_hash, branch)
			VALUES ('$(sql_escape "$task_id")', '$(sql_escape "$abs_path")',
				'$(sql_escape "$hash")', '$(sql_escape "$branch")');"
		count=$((count + 1))
	done
	sql="$sql COMMIT;"
	db_query "$sql"

	jq -n --arg t "$task_id" --argjson n "$count" --arg b "$branch" \
		'{"task_id":$t,"snapshots":$n,"branch":$b}'
}

cmd_check() {
	local task_id="$1"
	local snapshots
	snapshots=$(db_query "
		SELECT json_group_array(json_object('file', file_path, 'stored_hash', file_hash))
		FROM file_snapshots WHERE task_id='$(sql_escape "$task_id")';
	")

	local total=0 changed=0 missing=0 ok_count=0
	local changed_files="[]"

	while IFS= read -r row; do
		[[ -z "$row" ]] && continue
		local file stored_hash current_hash status
		file=$(echo "$row" | jq -r '.file')
		stored_hash=$(echo "$row" | jq -r '.stored_hash')
		current_hash=$(_file_hash "$file")
		total=$((total + 1))

		if [[ "$current_hash" == "MISSING" ]]; then
			status="deleted"
			missing=$((missing + 1))
		elif [[ "$current_hash" != "$stored_hash" ]]; then
			status="modified"
			changed=$((changed + 1))
		else
			status="unchanged"
			ok_count=$((ok_count + 1))
			continue
		fi

		changed_files=$(echo "$changed_files" | jq --arg f "$file" --arg s "$status" \
			--arg old "${stored_hash:0:12}" --arg new "${current_hash:0:12}" \
			'. + [{"file":$f,"status":$s,"old_hash":$old,"new_hash":$new}]')
	done < <(echo "$snapshots" | jq -c '.[]')

	local stale="false"
	[[ $changed -gt 0 || $missing -gt 0 ]] && stale="true"

	jq -n --arg t "$task_id" --argjson stale "$stale" \
		--argjson total "$total" --argjson changed "$changed" \
		--argjson missing "$missing" --argjson ok "$ok_count" \
		--argjson files "$changed_files" \
		'{task_id:$t,stale:$stale,total:$total,changed:$changed,
		  missing:$missing,ok:$ok,changed_files:$files}'
}

cmd_diff() {
	local task_id="$1"
	local result
	result=$(cmd_check "$task_id")
	local is_stale
	is_stale=$(echo "$result" | jq -r '.stale')

	if [[ "$is_stale" == "true" ]]; then
		echo "$result" | jq -r '.changed_files[] |
			"\(.status | ascii_upcase)\t\(.old_hash)→\(.new_hash)\t\(.file)"'
		return 1
	else
		echo "All files unchanged for task $task_id"
		return 0
	fi
}

cmd_cleanup() {
	local task_id="${1:-}"

	if [[ -n "$task_id" ]]; then
		local deleted
		deleted=$(db_query "
			DELETE FROM file_snapshots WHERE task_id='$(sql_escape "$task_id")';
			SELECT changes();
		")
		jq -n --arg t "$task_id" --argjson n "$deleted" '{"task_id":$t,"cleaned":$n}'
	else
		# Clean all snapshots older than 24 hours
		local deleted
		deleted=$(db_query "
			DELETE FROM file_snapshots
			WHERE snapshot_at < datetime('now', '-24 hours');
			SELECT changes();
		")
		jq -n --argjson n "$deleted" '{"cleaned":$n,"policy":"older than 24h"}'
	fi
}

# Dispatch
case "${1:-help}" in
snapshot) cmd_snapshot "${2:?task_id required}" "${@:3}" ;;
check) cmd_check "${2:?task_id required}" ;;
diff) cmd_diff "${2:?task_id required}" ;;
cleanup) cmd_cleanup "${2:-}" ;;
*)
	echo "Usage: stale-check.sh <command> [args]"
	echo "  snapshot <task_id> <file1> [file2...]  - Record file hashes"
	echo "  check <task_id>                        - Check if files changed (JSON)"
	echo "  diff <task_id>                         - Show changed files (human)"
	echo "  cleanup [task_id]                      - Remove snapshots"
	;;
esac
