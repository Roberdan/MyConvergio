#!/usr/bin/env bash
# mesh-dispatcher.sh — Floating coordinator: scores peers and dispatches tasks.
# Version: 1.0.0
# Usage: mesh-dispatcher.sh [--plan PLAN_ID | --all-plans] [--dry-run] [--force-provider PEER]
# F-13 (floating coordinator), F-15 (cost routing), F-16/F-17 (privacy), F-18 (dispatch)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB_PATH="${DB_PATH:-$CLAUDE_HOME/data/dashboard.db}"

source "$SCRIPT_DIR/lib/peers.sh"
source "$SCRIPT_DIR/lib/mesh-scoring.sh"

MESH_MAX_TASKS_PER_PEER="${MESH_MAX_TASKS_PER_PEER:-3}"
MESH_DISPATCH_TIMEOUT="${MESH_DISPATCH_TIMEOUT:-600}"

DRY_RUN=false
PLAN_ID=""
ALL_PLANS=false
FORCE_PROVIDER=""

_info() { echo "[mesh-dispatcher] $*"; }
_warn() { echo "[mesh-dispatcher] WARN: $*" >&2; }
_die() {
	echo "[mesh-dispatcher] ERROR: $*" >&2
	exit 1
}

usage() {
	cat >&2 <<'EOF'
Usage: mesh-dispatcher.sh [OPTIONS]

Options:
  --plan PLAN_ID      Dispatch tasks for a specific plan
  --all-plans         Dispatch tasks across all active plans (status='doing')
  --dry-run           Print assignment table; do not execute
  --force-provider P  Force all tasks to a specific peer name
  --help

Env vars:
  MESH_MAX_TASKS_PER_PEER  Max concurrent tasks per peer (default: 3)
  MESH_DISPATCH_TIMEOUT    Timeout for remote dispatch in seconds (default: 600)

EOF
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--plan)
		PLAN_ID="${2:-}"
		shift 2
		;;
	--all-plans)
		ALL_PLANS=true
		shift
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--force-provider)
		FORCE_PROVIDER="${2:-}"
		shift 2
		;;
	-h | --help) usage ;;
	*) _die "Unknown option: $1" ;;
	esac
done

[[ -z "$PLAN_ID" && "$ALL_PLANS" == false ]] && {
	_warn "No --plan or --all-plans specified. Nothing to do."
	usage
}

# ── Step 1: Get pending/in_progress tasks from DB ────────────────────────────
_get_tasks() {
	[[ ! -f "$DB_PATH" ]] && {
		_warn "DB not found: $DB_PATH"
		echo ""
		return 0
	}
	local plan_filter=""
	if [[ -n "$PLAN_ID" ]]; then
		plan_filter="AND t.plan_id = $PLAN_ID"
	elif [[ "$ALL_PLANS" == true ]]; then
		plan_filter="AND EXISTS (SELECT 1 FROM plans p WHERE p.id = t.plan_id AND p.status = 'doing')"
	fi
	# Output: id|plan_id|title|privacy_required (pipe-delimited)
	sqlite3 "$DB_PATH" \
		"SELECT t.id, t.plan_id, COALESCE(t.title,''), COALESCE(t.privacy_required,0)
		 FROM tasks t
		 WHERE t.status IN ('pending','in_progress')
		   AND (t.execution_host IS NULL OR t.execution_host = '')
		   ${plan_filter}
		 ORDER BY t.id;" 2>/dev/null || true
}

# ── Step 2: Get peer states via mesh-load-query.sh ───────────────────────────
_get_peer_states() {
	local mlq="$SCRIPT_DIR/mesh-load-query.sh"
	[[ ! -x "$mlq" ]] && {
		_warn "mesh-load-query.sh not found/executable: $mlq"
		echo "[]"
		return 0
	}
	"$mlq" --json 2>/dev/null || echo "[]"
}

# ── Step 3+4: Score and assign tasks ─────────────────────────────────────────
_assign_tasks() {
	local peers_json="$1"
	local self_name
	self_name="$(peers_self 2>/dev/null || echo "")"

	printf "%-8s %-10s %-30s %-20s %-6s\n" \
		"TASK_ID" "PLAN_ID" "TITLE" "PEER" "SCORE"
	printf '%0.s-' {1..80}
	echo

	local assigned=0 skipped=0

	while IFS='|' read -r task_id plan_id title privacy_req; do
		[[ -z "$task_id" ]] && continue

		local winner score
		if [[ -n "$FORCE_PROVIDER" ]]; then
			winner="$FORCE_PROVIDER"
			score="forced"
		else
			winner="$(mesh_best_peer "$peers_json" "" "$privacy_req" 2>/dev/null || echo "")"
			score="auto"
		fi

		if [[ -z "$winner" ]]; then
			printf "%-8s %-10s %-30s %-20s %-6s\n" \
				"$task_id" "$plan_id" "${title:0:29}" "(no peer)" "-"
			skipped=$((skipped + 1))
			continue
		fi

		printf "%-8s %-10s %-30s %-20s %-6s\n" \
			"$task_id" "$plan_id" "${title:0:29}" "$winner" "$score"
		assigned=$((assigned + 1))

		if [[ "$DRY_RUN" == false ]]; then
			# Write assignment to DB
			sqlite3 "$DB_PATH" \
				"UPDATE tasks SET execution_host='$winner' WHERE id=$task_id;" 2>/dev/null || true

			# Step 6: Dispatch
			if [[ "$winner" == "$self_name" || -z "$self_name" ]]; then
				_info "Local dispatch: task $task_id"
				"$SCRIPT_DIR/delegate.sh" "$task_id" &
			else
				_info "Remote dispatch: task $task_id → $winner"
				timeout "$MESH_DISPATCH_TIMEOUT" \
					"$SCRIPT_DIR/remote-dispatch.sh" "$task_id" "$winner" &
			fi
		fi
	done

	echo ""
	_info "Summary: $assigned assigned, $skipped skipped (no qualifying peer)"
	if [[ "$DRY_RUN" == true ]]; then
		_info "DRY RUN — no tasks executed"
	fi
}

main() {
	peers_load || { _warn "Failed to load peers. Continuing with empty peer list."; }

	_info "Querying peer states..."
	local peers_json
	peers_json="$(_get_peer_states)"

	_info "Fetching tasks..."
	local tasks
	tasks="$(_get_tasks)"

	if [[ -z "$tasks" ]]; then
		_info "No pending tasks found for the given plan selection."
		exit 0
	fi

	_assign_tasks "$peers_json" <<<"$tasks"

	# Wait for background dispatches
	if [[ "$DRY_RUN" == false ]]; then
		wait
		_info "All dispatches complete."
	fi
}

main
