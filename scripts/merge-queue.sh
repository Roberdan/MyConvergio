#!/bin/bash
# merge-queue.sh - Sequential merge with flock exclusion + SQLite state
# Commands: enqueue|process|status|cancel|clean
# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/plan-db-core.sh"

LOCK_FILE="${HOME}/.claude/data/merge-queue.lock"
MAIN_BRANCH="main"

# Find git root (walk up from worktree if needed)
_git_root() {
	git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null
}

# Ensure we're in the main repo for merging
_ensure_main_repo() {
	local main_root
	main_root=$(_git_root "$(git worktree list --porcelain | head -1 | sed 's/^worktree //')")
	echo "$main_root"
}

cmd_enqueue() {
	local branch="$1"
	shift
	local plan_id="NULL" priority=0 wt_path=""
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--plan-id)
			plan_id="$2"
			shift 2
			;;
		--priority)
			priority="$2"
			shift 2
			;;
		--worktree)
			wt_path="$2"
			shift 2
			;;
		*) shift ;;
		esac
	done

	# Check branch exists
	if ! git rev-parse --verify "$branch" &>/dev/null; then
		echo '{"error":"branch not found","branch":"'"$branch"'"}' >&2
		return 1
	fi

	# Check merge readiness
	local dirty
	if [[ -n "$wt_path" ]] && [[ -d "$wt_path" ]]; then
		dirty=$(git -C "$wt_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
		if [[ "$dirty" -gt 0 ]]; then
			echo '{"error":"worktree has uncommitted changes","count":'"$dirty"'}' >&2
			return 1
		fi
	fi

	# Atomic insert (UNIQUE on branch)
	if db_query "
		INSERT INTO merge_queue (branch, worktree_path, plan_id, priority)
		VALUES ('$(sql_escape "$branch")', '$(sql_escape "$wt_path")',
			$plan_id, $priority);
	" 2>/dev/null; then
		jq -n --arg b "$branch" --argjson p "$priority" \
			'{"status":"queued","branch":$b,"priority":$p}'
	else
		echo '{"error":"branch already in queue","branch":"'"$branch"'"}' >&2
		return 1
	fi
}

cmd_process() {
	local validate=0 dry_run=0
	while [[ $# -gt 0 ]]; do
		case "$1" in --validate) validate=1 ;; --dry-run) dry_run=1 ;; esac
		shift
	done

	mkdir -p "$(dirname "$LOCK_FILE")"

	# Use flock for process-level exclusion
	exec 9>"$LOCK_FILE"
	if ! flock -n 9; then
		exec 9>&-
		echo '{"error":"another merge process is running"}' >&2
		return 1
	fi

	# Atomic: select and mark as processing in one operation
	local next
	next=$(db_query "
		UPDATE merge_queue SET status='processing', started_at=datetime('now')
		WHERE id = (SELECT id FROM merge_queue WHERE status='queued'
			ORDER BY priority DESC, id ASC LIMIT 1)
		RETURNING json_object('id', id, 'branch', branch, 'worktree_path', worktree_path,
			'plan_id', plan_id);
	")

	if [[ -z "$next" || "$next" == "null" ]]; then
		echo '{"status":"empty","message":"no items in queue"}'
		exec 9>&-
		return 0
	fi

	local q_id branch wt_path plan_id
	q_id=$(echo "$next" | jq -r '.id')
	branch=$(echo "$next" | jq -r '.branch')
	wt_path=$(echo "$next" | jq -r '.worktree_path')
	plan_id=$(echo "$next" | jq -r '.plan_id')

	if [[ $dry_run -eq 1 ]]; then
		# Dry run: check if merge would succeed
		local merge_base
		merge_base=$(git merge-base "$MAIN_BRANCH" "$branch" 2>/dev/null)
		local conflicts
		conflicts=$(git merge-tree "$merge_base" "$MAIN_BRANCH" "$branch" 2>/dev/null)
		local has_conflict=0
		echo "$conflicts" | grep -q "^<<<<<<" && has_conflict=1

		db_query "UPDATE merge_queue SET status='queued', started_at=NULL WHERE id=$q_id;"
		jq -n --arg b "$branch" --argjson conflict "$has_conflict" \
			'{"dry_run":true,"branch":$b,"would_conflict":($conflict==1)}'
		return 0
	fi

	# Perform the merge
	local main_repo
	main_repo=$(_ensure_main_repo)

	local merge_result
	if merge_result=$(git -C "$main_repo" merge --no-ff "$branch" \
		-m "Merge branch '$branch' via merge-queue" 2>&1); then

		local merge_sha
		merge_sha=$(git -C "$main_repo" rev-parse HEAD)

		# Post-merge validation
		if [[ $validate -eq 1 ]]; then
			local valid=1
			# Run build check if package.json exists
			if [[ -f "$main_repo/package.json" ]]; then
				if ! (cd "$main_repo" && npx tsc --noEmit 2>/dev/null); then
					valid=0
				fi
			fi

			if [[ $valid -eq 0 ]]; then
				# Revert the merge
				git -C "$main_repo" reset --hard HEAD~1
				db_query "
					UPDATE merge_queue SET status='failed',
						completed_at=datetime('now'),
						error='post-merge validation failed (typecheck)'
					WHERE id=$q_id;
				"
				jq -n --arg b "$branch" \
					'{"status":"failed","branch":$b,"reason":"validation_failed","reverted":true}'
				return 1
			fi
		fi

		# Success
		db_query "
			UPDATE merge_queue SET status='done', completed_at=datetime('now'),
				result='$(sql_escape "$merge_sha")'
			WHERE id=$q_id;
		"
		jq -n --arg b "$branch" --arg sha "${merge_sha:0:12}" \
			'{"status":"merged","branch":$b,"sha":$sha}'

	else
		# Merge failed (conflict)
		git -C "$main_repo" merge --abort 2>/dev/null || true
		db_query "
			UPDATE merge_queue SET status='failed', completed_at=datetime('now'),
				error='$(sql_escape "$merge_result")'
			WHERE id=$q_id;
		"
		jq -n --arg b "$branch" --arg err "$merge_result" \
			'{"status":"failed","branch":$b,"reason":"merge_conflict","error":$err}'
		return 1
	fi
}

cmd_status() {
	db_query "
		SELECT json_object(
			'queued', (SELECT COUNT(*) FROM merge_queue WHERE status='queued'),
			'processing', (SELECT COUNT(*) FROM merge_queue WHERE status='processing'),
			'done', (SELECT COUNT(*) FROM merge_queue WHERE status='done'),
			'failed', (SELECT COUNT(*) FROM merge_queue WHERE status='failed'),
			'items', (SELECT json_group_array(json_object(
				'id', id, 'branch', branch, 'status', status,
				'priority', priority,
				'age', CASE WHEN status='queued'
					THEN (strftime('%s','now') - strftime('%s', queued_at)) || 's'
					ELSE COALESCE(result, error, '') END
			)) FROM merge_queue WHERE status IN ('queued','processing'))
		);
	"
}

cmd_cancel() {
	local branch="$1"
	local updated
	updated=$(db_query "
		UPDATE merge_queue SET status='cancelled', completed_at=datetime('now')
		WHERE branch='$(sql_escape "$branch")' AND status='queued';
		SELECT changes();
	")
	jq -n --arg b "$branch" --argjson n "$updated" '{"cancelled":$b,"count":$n}'
}

cmd_clean() {
	local age=24
	[[ "${1:-}" == "--age" ]] && age="${2:-24}"
	local deleted
	deleted=$(db_query "
		DELETE FROM merge_queue
		WHERE status IN ('done','failed','cancelled')
		AND completed_at < datetime('now', '-$age hours');
		SELECT changes();
	")
	jq -n --argjson n "$deleted" --argjson h "$age" '{"cleaned":$n,"older_than_hours":$h}'
}

# Dispatch
case "${1:-help}" in
enqueue) cmd_enqueue "${2:?branch required}" "${@:3}" ;;
process) cmd_process "${@:2}" ;;
status) cmd_status ;;
cancel) cmd_cancel "${2:?branch required}" ;;
clean) cmd_clean "${@:2}" ;;
*)
	echo "Usage: merge-queue.sh <command> [args]"
	echo "  enqueue <branch> [--plan-id N] [--priority N] [--worktree PATH]"
	echo "  process [--validate] [--dry-run]"
	echo "  status  |  cancel <branch>  |  clean [--age HOURS]"
	;;
esac
