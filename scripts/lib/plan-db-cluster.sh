#!/bin/bash
# Plan DB Cluster - Distributed execution support
# Functions for claim/release/heartbeat/liveness/cluster-status
# Sourced by plan-db.sh
# Version: 1.2.0

# Source peer discovery library (idempotent)
_CLUSTER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${_PEERS_LOADED:-}" ]]; then
	# shellcheck source=peers.sh
	source "${_CLUSTER_LIB_DIR}/peers.sh"
	peers_load 2>/dev/null || true
	_PEERS_LOADED=1
fi

# SSH timeout configurable via environment variable
PLAN_DB_SSH_TIMEOUT="${PLAN_DB_SSH_TIMEOUT:-5}"

# cmd_claim <plan_id> [--force]
# Atomically claim a plan; checks config sync before claiming.
cmd_claim() {
	local plan_id="$1" force=0
	[[ "${2:-}" == "--force" ]] && force=1
	if ! [[ "$plan_id" =~ ^[0-9]+$ ]]; then
		log_error "Invalid plan_id: $plan_id"
		return 1
	fi
	local sync_status
	sync_status=$(config_sync_check)
	if [[ "$sync_status" == "DIVERGED" ]]; then
		log_error "Config diverged. Run 'dbsync pull' or 'dbsync push'."
		return 1
	elif [[ "$sync_status" == "ERROR" ]]; then
		log_warn "Could not verify config sync. Proceeding."
	elif [[ "$sync_status" == "PUSHED" ]]; then
		log_info "Auto-pushed local config changes to remote"
	fi
	init_db
	local safe_host
	safe_host=$(sql_escape "$PLAN_DB_HOST")
	if [[ $force -eq 1 ]]; then
		sqlite3 "$DB_FILE" <<-EOF
			UPDATE plans SET execution_host='${safe_host}', status='doing',
			    started_at=COALESCE(started_at,datetime('now')) WHERE id=$plan_id;
		EOF
		log_info "Force-claimed plan $plan_id on $PLAN_DB_HOST"
		return 0
	fi
	local rows_updated
	rows_updated=$(
		sqlite3 "$DB_FILE" <<-EOF
			UPDATE plans SET execution_host='${safe_host}', status='doing',
			    started_at=COALESCE(started_at,datetime('now'))
			WHERE id=$plan_id AND (execution_host IS NULL OR execution_host='${safe_host}');
			SELECT changes();
		EOF
	)
	if [[ "$rows_updated" -eq 0 ]]; then
		local current_host
		current_host=$(sqlite3 "$DB_FILE" "SELECT execution_host FROM plans WHERE id=$plan_id")
		log_error "Plan $plan_id already claimed by $current_host. Use --force to override."
		return 1
	fi
	log_info "Claimed plan $plan_id on $PLAN_DB_HOST"
}

# cmd_release <plan_id>
# Release plan claim; only works if this host owns it.
cmd_release() {
	local plan_id="$1"
	if ! [[ "$plan_id" =~ ^[0-9]+$ ]]; then
		log_error "Invalid plan_id: $plan_id"
		return 1
	fi
	init_db
	local safe_host
	safe_host=$(sql_escape "$PLAN_DB_HOST")
	local rows_updated
	rows_updated=$(
		sqlite3 "$DB_FILE" <<-EOF
			UPDATE plans SET execution_host=NULL
			WHERE id=$plan_id AND execution_host='${safe_host}';
			SELECT changes();
		EOF
	)
	if [[ "$rows_updated" -eq 0 ]]; then
		local current_host
		current_host=$(sqlite3 "$DB_FILE" "SELECT execution_host FROM plans WHERE id=$plan_id")
		if [[ -n "$current_host" ]] && [[ "$current_host" != "$PLAN_DB_HOST" ]]; then
			log_error "Cannot release plan $plan_id: claimed by $current_host"
			return 1
		fi
		log_warn "Plan $plan_id was not claimed"
		return 0
	fi
	log_info "Released plan $plan_id"
}

# cmd_heartbeat
# Write/update heartbeat record for this host.
cmd_heartbeat() {
	init_db
	local plan_count os_name safe_host
	plan_count=$(sqlite3 "$DB_FILE" \
		"SELECT COUNT(*) FROM plans WHERE execution_host='$PLAN_DB_HOST' AND status='doing'")
	os_name=$(uname -s)
	safe_host=$(sql_escape "$PLAN_DB_HOST")
	sqlite3 "$DB_FILE" <<-EOF
		INSERT OR REPLACE INTO host_heartbeats (host,last_seen,plan_count,os)
		VALUES ('${safe_host}',datetime('now'),$plan_count,'$os_name');
	EOF
	log_info "Heartbeat recorded for $PLAN_DB_HOST (plan_count=$plan_count)"
}

# cmd_is_alive <peer>
# Check if peer is alive. Accepts peer name (peers.conf) or raw hostname.
# Uses peers_best_route for routing; heartbeat freshness check first.
# Output: ALIVE|STALE|UNREACHABLE
cmd_is_alive() {
	local peer="${1:-}"
	[[ -z "$peer" ]] && {
		log_error "Usage: cmd_is_alive <peer>"
		return 1
	}
	init_db
	local ssh_target="$peer" peer_user
	if peers_best_route "$peer" &>/dev/null 2>&1; then
		ssh_target="$(peers_best_route "$peer")"
		peer_user="$(_peers_get_raw "$peer" "user" 2>/dev/null || true)"
		[[ -n "$peer_user" ]] && ssh_target="${peer_user}@${ssh_target}"
	fi
	local last_seen
	last_seen=$(sqlite3 "$DB_FILE" \
		"SELECT last_seen FROM host_heartbeats WHERE host='$(sql_escape "$peer")'")
	if [[ -n "$last_seen" ]]; then
		local age
		age=$(sqlite3 "$DB_FILE" \
			"SELECT CAST((julianday('now')-julianday('$last_seen'))*86400 AS INTEGER)")
		if [[ $age -lt 300 ]]; then
			echo "ALIVE"
			return 0
		fi
		if ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT}" -o BatchMode=yes \
			-o StrictHostKeyChecking=no -o LogLevel=quiet "$ssh_target" true &>/dev/null; then echo "ALIVE"; else echo "STALE"; fi
		return 0
	fi
	if ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT}" -o BatchMode=yes \
		-o StrictHostKeyChecking=no -o LogLevel=quiet "$ssh_target" true &>/dev/null; then echo "ALIVE"; else echo "UNREACHABLE"; fi
}

# _cluster_online_peers
# Internal: echo "peer_name|ssh_target" for each reachable active peer.
# Iterates peers_online(); falls back to REMOTE_HOST if none configured.
_cluster_online_peers() {
	local peer_name route user ssh_target found_any=0
	while IFS= read -r peer_name; do
		[[ -z "$peer_name" ]] && continue
		found_any=1
		if peers_best_route "$peer_name" &>/dev/null 2>&1; then
			route="$(peers_best_route "$peer_name")"
			user="$(_peers_get_raw "$peer_name" "user" 2>/dev/null || true)"
			ssh_target="${user:+${user}@}${route}"
		else
			ssh_target="$peer_name"
		fi
		echo "${peer_name}|${ssh_target}"
	done < <(peers_online 2>/dev/null)
	# Backward compat: REMOTE_HOST fallback when no peers.conf entries
	if [[ $found_any -eq 0 ]] && [[ -n "${REMOTE_HOST:-}" ]]; then
		if ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT:-5}" -o BatchMode=yes \
			-o StrictHostKeyChecking=no -o LogLevel=quiet \
			"$REMOTE_HOST" true &>/dev/null; then
			echo "${REMOTE_HOST}|${REMOTE_HOST}"
		fi
	fi
}

# cmd_cluster_status
# Unified view: local + all online peers active plans merged.
cmd_cluster_status() {
	load_sync_config
	echo -e "${BLUE}======= CLUSTER STATUS =======${NC}"
	local local_plans all_peers peer_count=0
	local_plans=$(sqlite3 -separator '|' "$DB_FILE" "
		SELECT p.id, p.name, p.tasks_done||'/'||p.tasks_total,
		       COALESCE(p.execution_host,'$PLAN_DB_HOST'), p.status
		FROM plans p WHERE p.status IN ('doing','todo') ORDER BY p.status, p.id;")
	all_peers="$(_cluster_online_peers)"
	[[ -n "$all_peers" ]] && peer_count=$(wc -l <<<"$all_peers")
	echo -e "Local: ${GREEN}$PLAN_DB_HOST${NC} | Online peers: ${peer_count}"
	echo ""
	printf "%-12s %-4s %-25s %-8s %-20s\n" "HOST" "ID" "PLAN" "PROG" "STATUS"
	printf "%s\n" "------------------------------------------------------------------------"
	local pid pname prog host status
	while IFS='|' read -r pid pname prog host status; do
		[[ -z "$pid" ]] && continue
		printf "%-12s %-4s %-25s %-8s %-20s\n" \
			"LOCAL" "$pid" "$(_truncate "$pname" 24)" "$prog" "$status"
	done <<<"$local_plans"
	local peer_name ssh_target peer_label remote_plans
	while IFS='|' read -r peer_name ssh_target; do
		[[ -z "$peer_name" ]] && continue
		peer_label="$(_truncate "$peer_name" 11)"
		remote_plans=$(ssh -o ConnectTimeout=10 \
			-o StrictHostKeyChecking=no -o LogLevel=quiet "$ssh_target" "
			sqlite3 -separator '|' ~/.claude/data/dashboard.db \"
				SELECT p.id, p.name, p.tasks_done||'/'||p.tasks_total,
				       COALESCE(p.execution_host,'${peer_name}'), p.status
				FROM plans p WHERE p.status IN ('doing','todo') ORDER BY p.status, p.id;\"
		" 2>/dev/null) || remote_plans=""
		while IFS='|' read -r pid pname prog host status; do
			[[ -z "$pid" ]] && continue
			printf "%-12s %-4s %-25s %-8s %-20s\n" \
				"$peer_label" "$pid" "$(_truncate "$pname" 24)" "$prog" "$status"
		done <<<"$remote_plans"
	done <<<"$all_peers"
}

# cmd_cluster_tasks
# In-progress tasks: local DB + all online peers.
cmd_cluster_tasks() {
	load_sync_config
	echo -e "${BLUE}======= CLUSTER TASKS =======${NC}"
	echo -e "\n${GREEN}$PLAN_DB_HOST (local):${NC}"
	sqlite3 -column "$DB_FILE" "
		SELECT t.task_id, t.title, t.wave_id,
		       COALESCE(t.executor_host,'$PLAN_DB_HOST') as host
		FROM tasks t WHERE t.status='in_progress' ORDER BY t.wave_id, t.task_id;"
	local all_peers peer_name ssh_target
	all_peers="$(_cluster_online_peers)"
	while IFS='|' read -r peer_name ssh_target; do
		[[ -z "$peer_name" ]] && continue
		echo -e "\n${YELLOW}${peer_name} (remote):${NC}"
		ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o LogLevel=quiet \
			"$ssh_target" "
			sqlite3 -column ~/.claude/data/dashboard.db \"
				SELECT t.task_id, t.title, t.wave_id,
				       COALESCE(t.executor_host,'${peer_name}') as host
				FROM tasks t WHERE t.status='in_progress' ORDER BY t.wave_id, t.task_id;\"
		" 2>/dev/null || echo "  (no data)"
	done <<<"$all_peers"
}
