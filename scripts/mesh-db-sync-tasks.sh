#!/usr/bin/env bash
# mesh-db-sync-tasks.sh — Bidirectional task sync across mesh peers
# Pulls task/wave/plan updates from ALL active peers, not just execution_host-matched.
# Version: 2.1.0
# Usage: mesh-db-sync-tasks.sh [--peer NAME] [--plan ID] [--dry-run] [--verbose]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB="${CLAUDE_HOME}/data/dashboard.db"
SSH_OPTS="-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

source "$SCRIPT_DIR/lib/peers.sh"

C='\033[0;36m' G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' N='\033[0m'
info() { echo -e "${C}[db-sync]${N} $*"; }
ok() { echo -e "${G}[db-sync]${N} $*"; }
warn() { echo -e "${Y}[db-sync]${N} $*" >&2; }

DRY_RUN=false
VERBOSE=false
TARGET_PEER=""
PLAN_FILTER=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--peer)
		TARGET_PEER="${2:-}"
		shift 2
		;;
	--plan)
		PLAN_FILTER="${2:-}"
		shift 2
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--verbose)
		VERBOSE=true
		shift
		;;
	--help | -h)
		echo "Usage: mesh-db-sync-tasks.sh [--peer NAME] [--plan ID] [--dry-run]"
		exit 0
		;;
	*) shift ;;
	esac
done

_db() { sqlite3 "$DB" ".timeout 3000" "$@" 2>/dev/null; }

_ssh() {
	local peer="$1"
	shift
	local dest
	dest="$(peers_get "$peer" ssh_alias 2>/dev/null || echo "$peer")"
	ssh $SSH_OPTS "$dest" "$@" 2>/dev/null
}

# Pull all non-pending task data from a remote peer
_pull_from_peer() {
	local peer="$1"
	local self
	self="$(peers_self 2>/dev/null || echo "")"
	[[ "$peer" == "$self" ]] && return 0

	info "Pulling from $peer..."

	# Build remote query: all non-pending tasks for doing plans
	local plan_where="p.status='doing'"
	[[ -n "$PLAN_FILTER" ]] && plan_where="p.id=$PLAN_FILTER"

	local remote_sql="SELECT t.id,t.status,t.validated_by,t.validated_at,t.completed_at,t.started_at,t.tokens,t.executor_agent,t.executor_status,t.output_data,t.plan_id FROM tasks t JOIN plans p ON t.plan_id=p.id WHERE $plan_where AND t.status NOT IN ('pending') ORDER BY t.id;"
	local wave_sql="SELECT w.id,w.wave_id,w.status,w.tasks_done,w.tasks_total,w.plan_id FROM waves w JOIN plans p ON w.plan_id=p.id WHERE $plan_where;"
	local plan_sql="SELECT p.id,p.tasks_done,p.tasks_total,p.status FROM plans p WHERE $plan_where;"

	local hb_sql="SELECT peer_name,last_seen,load_json,capabilities FROM peer_heartbeats;"
	local remote_claude_home remote_db
	remote_claude_home="$(_remote_claude_home "$peer")"
	remote_db="${remote_claude_home}/data/dashboard.db"

	local remote_data
	remote_data="$(_ssh "$peer" "sqlite3 ${remote_db} '.timeout 3000' \
    '.separator |' \
    \"$remote_sql\" \
    2>/dev/null; echo '===WAVES==='; \
    sqlite3 ${remote_db} '.timeout 3000' '.separator |' \
    \"$wave_sql\" 2>/dev/null; \
    echo '===PLANS==='; \
    sqlite3 ${remote_db} '.timeout 3000' '.separator |' \
    \"$plan_sql\" 2>/dev/null; \
    echo '===HEARTBEATS==='; \
    sqlite3 ${remote_db} '.timeout 3000' '.separator |' \
    \"$hb_sql\" 2>/dev/null")" || {
		warn "$peer: SSH failed"
		return 1
	}

	local section="tasks" synced=0 skipped=0

	while IFS= read -r line; do
		[[ "$line" == "===WAVES===" ]] && {
			section="waves"
			continue
		}
		[[ "$line" == "===PLANS===" ]] && {
			section="plans"
			continue
		}
		[[ "$line" == "===HEARTBEATS===" ]] && {
			section="heartbeats"
			continue
		}
		[[ -z "$line" ]] && continue

		case "$section" in
		tasks) _sync_task "$line" && ((synced++)) || ((skipped++)) ;;
		waves) _sync_wave "$line" ;;
		plans) _sync_plan "$line" ;;
		heartbeats) _sync_heartbeat "$line" ;;
		esac
	done <<<"$remote_data"

	ok "$peer: Synced $synced tasks ($skipped unchanged)"
}

# Sync a single task row: id|status|validated_by|validated_at|completed_at|started_at|tokens|executor_agent|executor_status|output_data|plan_id
_sync_task() {
	local IFS='|'
	read -r tid tstatus tval_by tval_at tcomplete tstart ttokens tagent texec_st toutput tplan <<<"$1"
	[[ -z "$tid" ]] && return 1

	local local_status
	local_status=$(_db "SELECT status FROM tasks WHERE id=$tid;")
	[[ -z "$local_status" ]] && return 1

	# Status priority: done > submitted > in_progress > blocked > pending
	local dominated=false
	case "$local_status" in
	done) dominated=true ;; # never regress from done
	submitted) [[ "$tstatus" != "done" ]] && dominated=true ;;
	esac
	$dominated && return 1

	[[ "$local_status" == "$tstatus" ]] && {
		# Same status — still update tokens/output if richer
		local local_tokens
		local_tokens=$(_db "SELECT tokens FROM tasks WHERE id=$tid;")
		if [[ "${ttokens:-0}" -gt "${local_tokens:-0}" ]]; then
			$DRY_RUN && {
				$VERBOSE && warn "UPDATE tokens $tid: $local_tokens → $ttokens"
				return 0
			}
			_db "UPDATE tasks SET tokens=$ttokens WHERE id=$tid;"
			return 0
		fi
		return 1
	}

	$VERBOSE && info "Task $tid: $local_status → $tstatus"

	if $DRY_RUN; then
		warn "[dry-run] Task $tid: $local_status → $tstatus"
		return 0
	fi

	# Build UPDATE with all available fields
	local sets="status='$tstatus'"
	[[ -n "$tval_by" ]] && sets="$sets, validated_by='$tval_by'"
	[[ -n "$tval_at" ]] && sets="$sets, validated_at='$tval_at'"
	[[ -n "$tcomplete" ]] && sets="$sets, completed_at='$tcomplete'"
	[[ -n "$tstart" ]] && sets="$sets, started_at='$tstart'"
	[[ "${ttokens:-0}" -gt 0 ]] && sets="$sets, tokens=$ttokens"
	[[ -n "$tagent" ]] && sets="$sets, executor_agent='$tagent'"
	[[ -n "$texec_st" ]] && sets="$sets, executor_status='$texec_st'"

	# For done status: bypass the enforce_thor_done trigger by going submitted→done
	if [[ "$tstatus" == "done" && "$local_status" != "submitted" ]]; then
		_db "UPDATE tasks SET status='submitted' WHERE id=$tid AND status NOT IN ('submitted','done');" || true
	fi

	_db "UPDATE tasks SET $sets WHERE id=$tid;" || true
	return 0
}

_sync_wave() {
	local IFS='|'
	read -r wid wave_id wstatus wdone wtotal wplan <<<"$1"
	[[ -z "$wid" ]] && return

	local local_status
	local_status=$(_db "SELECT status FROM waves WHERE id=$wid;")
	[[ "$local_status" == "$wstatus" && "$local_status" == "done" ]] && return

	if ! $DRY_RUN; then
		_db "UPDATE waves SET status='$wstatus', tasks_done=$wdone, tasks_total=$wtotal WHERE id=$wid;"
	fi
}

_sync_plan() {
	local IFS='|'
	read -r pid pdone ptotal pstatus <<<"$1"
	[[ -z "$pid" ]] && return

	local local_done
	local_done=$(_db "SELECT tasks_done FROM plans WHERE id=$pid;")
	# Take the higher count (more progress) — NEVER touch execution_host
	if [[ "${pdone:-0}" -gt "${local_done:-0}" ]]; then
		if ! $DRY_RUN; then
			_db "UPDATE plans SET tasks_done=$pdone, tasks_total=$ptotal WHERE id=$pid;"
		fi
	fi
}

_sync_heartbeat() {
	local IFS='|'
	read -r hpeer hlast hload hcaps <<<"$1"
	[[ -z "$hpeer" ]] && return
	local local_last
	local_last=$(_db "SELECT last_seen FROM peer_heartbeats WHERE peer_name='$hpeer';")
	# Take the more recent heartbeat (higher timestamp wins)
	if [[ -z "$local_last" || "${hlast:-0}" -gt "${local_last:-0}" ]]; then
		$DRY_RUN && return
		_db "INSERT OR REPLACE INTO peer_heartbeats (peer_name, last_seen, load_json, capabilities) VALUES ('$hpeer', ${hlast:-0}, '${hload:-{}}', '${hcaps:-}');"
	fi
}

# Main
peers_load 2>/dev/null || true

if [[ -n "$TARGET_PEER" ]]; then
	_pull_from_peer "$TARGET_PEER"
else
	for p in $(peers_list 2>/dev/null); do
		_pull_from_peer "$p" || true
	done
fi
