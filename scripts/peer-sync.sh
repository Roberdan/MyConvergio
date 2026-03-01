#!/usr/bin/env bash
# peer-sync.sh — One-command sync-all: config + DB across all peers
# Usage: peer-sync.sh [push|pull|status]
# Version: 1.0.0
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/peers.sh
source "${_SCRIPT_DIR}/lib/peers.sh"

peers_load 2>/dev/null || true

G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' N='\033[0m'
info() { echo -e "${C}[peer-sync]${N} $*"; }
ok() { echo -e "${G}[peer-sync]${N} $*"; }
warn() { echo -e "${Y}[peer-sync]${N} $*"; }
err() { echo -e "${R}[peer-sync]${N} $*" >&2; }

CONFIG_SYNC="${_SCRIPT_DIR}/sync-claude-config.sh"
DB_SYNC="${_SCRIPT_DIR}/sync-dashboard-db.sh"

_check_scripts() {
	local ok=1
	[[ -x "$CONFIG_SYNC" ]] || {
		err "Missing or not executable: $CONFIG_SYNC"
		ok=0
	}
	[[ -x "$DB_SYNC" ]] || {
		err "Missing or not executable: $DB_SYNC"
		ok=0
	}
	[[ "$ok" -eq 1 ]]
}

# Run push-all or pull-all for both config and DB in parallel.
_run_all() {
	local verb="$1" # push-all or pull-all
	local cfg_log db_log rc_cfg rc_db
	cfg_log="${TMPDIR:-/tmp}/peer-sync-cfg-$$.log"
	db_log="${TMPDIR:-/tmp}/peer-sync-db-$$.log"
	rc_cfg=0
	rc_db=0

	"$CONFIG_SYNC" "$verb" >"$cfg_log" 2>&1 &
	local pid_cfg=$!
	"$DB_SYNC" "$verb" >"$db_log" 2>&1 &
	local pid_db=$!

	wait "$pid_cfg" || rc_cfg=$?
	wait "$pid_db" || rc_db=$?

	if [[ "$rc_cfg" -eq 0 && "$rc_db" -eq 0 ]]; then
		ok "Config sync: OK"
		ok "DB sync: OK"
	else
		[[ "$rc_cfg" -ne 0 ]] && {
			warn "Config sync: FAILED"
			cat "$cfg_log" >&2 2>/dev/null || true
		}
		[[ "$rc_db" -ne 0 ]] && {
			warn "DB sync: FAILED"
			cat "$db_log" >&2 2>/dev/null || true
		}
	fi
	rm -f "$cfg_log" "$db_log"

	local total_count online_count failed=0 synced=0 offline=0
	total_count=$(peers_others 2>/dev/null | wc -l | tr -d ' ')
	online_count=$(peers_online 2>/dev/null | wc -l | tr -d ' ')
	offline=$((total_count - online_count))

	if [[ "$rc_cfg" -ne 0 || "$rc_db" -ne 0 ]]; then
		failed=1
		synced=$((online_count > 0 ? online_count - 1 : 0))
	else
		synced="$online_count"
	fi

	echo ""
	echo -e "  ${G}Synced${N}: $synced  ${R}Failed${N}: $failed  ${Y}Offline${N}: $offline"
	echo ""

	[[ "$rc_cfg" -eq 0 && "$rc_db" -eq 0 ]]
}

cmd_push() {
	info "Pushing to all peers (config + DB in parallel)..."
	_run_all "push-all"
}

cmd_pull() {
	info "Pulling from all peers (config + DB in parallel)..."
	_run_all "pull-all"
}

cmd_status() {
	info "Peer sync status:"
	echo ""

	printf "  %-20s %-12s %-12s %s\n" "PEER" "CONFIG" "DB" "ONLINE"
	printf "  %-20s %-12s %-12s %s\n" "----" "------" "--" "------"

	local synced=0 offline=0
	local cfg_log db_log
	cfg_log="${TMPDIR:-/tmp}/peer-sync-cfg-status-$$.log"
	db_log="${TMPDIR:-/tmp}/peer-sync-db-status-$$.log"

	"$CONFIG_SYNC" status-all >"$cfg_log" 2>&1 &
	local pid_cfg=$!
	"$DB_SYNC" status-all >"$db_log" 2>&1 &
	local pid_db=$!
	wait "$pid_cfg" || true
	wait "$pid_db" || true

	while IFS= read -r peer; do
		[[ -z "$peer" ]] && continue
		local reachable=0
		peers_check "$peer" 2>/dev/null && reachable=1 || true

		if [[ "$reachable" -eq 0 ]]; then
			printf "  %-20s %-12s %-12s %s\n" "$peer" "offline" "offline" "NO"
			offline=$((offline + 1))
			continue
		fi

		local cfg_status db_status
		cfg_status=$(grep -i "$peer" "$cfg_log" 2>/dev/null | grep -oiE 'in sync|ahead|behind|diverged|unreachable' | tr '[:upper:]' '[:lower:]' || echo "ok")
		db_status=$(grep -i "$peer" "$db_log" 2>/dev/null | grep -oiE 'in sync|ahead|behind|diverged|unreachable' | tr '[:upper:]' '[:lower:]' || echo "ok")
		[[ -z "$cfg_status" ]] && cfg_status="ok"
		[[ -z "$db_status" ]] && db_status="ok"

		printf "  %-20s %-12s %-12s %s\n" "$peer" "$cfg_status" "$db_status" "YES"
		synced=$((synced + 1))
	done < <(peers_others 2>/dev/null)

	rm -f "$cfg_log" "$db_log"

	echo ""
	echo -e "  ${G}Online${N}: $synced  ${Y}Offline${N}: $offline"
	echo ""
}

case "${1:-}" in
push) cmd_push ;;
pull) cmd_pull ;;
status) cmd_status ;;
-h | --help | help)
	echo "Usage: $(basename "$0") [push|pull|status]"
	echo "  push   — push config + DB to all peers in parallel"
	echo "  pull   — pull config + DB from all peers in parallel"
	echo "  status — show per-peer config_status, db_status, online"
	;;
"")
	err "No command given. Use: push|pull|status"
	echo "Usage: $(basename "$0") [push|pull|status]" >&2
	exit 1
	;;
*)
	err "Unknown command: $1. Use: push|pull|status"
	exit 1
	;;
esac
