#!/bin/bash
# Plan DB Remote - Cross-machine cluster commands
# Functions for remote status and token reports
# Sourced by plan-db.sh

# Source peer discovery library (idempotent guard)
_REMOTE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${_PEERS_LOADED:-}" ]]; then
	# shellcheck source=peers.sh
	source "${_REMOTE_LIB_DIR}/peers.sh"
	peers_load 2>/dev/null || true
	_PEERS_LOADED=1
fi

# Version: 1.2.0

# ============================================================
# cmd_remote_status [peer_name] [project_id]
# ============================================================
# SSH to peer and run plan-db.sh status.
# peer_name: peer name from peers.conf, or falls back to REMOTE_HOST.
# Backward compat: single numeric arg is treated as project_id.
cmd_remote_status() {
	local peer="${1:-}"
	local project_id="${2:-}"

	# Backward compat: numeric-only first arg = project_id (old callers)
	if [[ "$peer" =~ ^[0-9]+$ ]]; then
		project_id="$peer"
		peer=""
	fi

	load_sync_config

	# Resolve target: prefer named peer, fallback to REMOTE_HOST
	local ssh_target peer_label
	if [[ -n "$peer" ]] && peers_best_route "$peer" &>/dev/null 2>&1; then
		local route user
		route="$(peers_best_route "$peer")"
		user="$(_peers_get_raw "$peer" "user" 2>/dev/null || true)"
		ssh_target="${user:+${user}@}${route}"
		peer_label="$peer"
	elif [[ -n "${REMOTE_HOST:-}" ]]; then
		ssh_target="${REMOTE_HOST}"
		peer_label="${REMOTE_HOST}"
	else
		log_error "No peer specified and REMOTE_HOST not set"
		return 1
	fi

	echo -e "${BLUE}=== Remote Status: ${peer_label} ===${NC}"

	if ! ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT:-5}" -o BatchMode=yes \
		-o StrictHostKeyChecking=no -o LogLevel=quiet \
		"$ssh_target" true &>/dev/null; then
		log_error "Cannot reach $peer_label ($ssh_target)"
		return 1
	fi

	local remote_args="status"
	[[ -n "$project_id" ]] && remote_args="status $project_id"

	ssh -o ConnectTimeout=10 "$ssh_target" \
		"bash ~/.claude/scripts/plan-db.sh $remote_args 2>/dev/null" || {
		log_error "Remote command failed"
		return 1
	}
}

# ============================================================
# cmd_token_report
# ============================================================
# Per-project token/cost totals: local DB + all online peers.
# Shows per-peer breakdown. Falls back to REMOTE_HOST if no peers configured.
cmd_token_report() {
	echo -e "${BLUE}======= TOKEN REPORT =======${NC}"
	echo ""

	printf "%-20s %-12s %-25s %12s %12s %10s %6s\n" \
		"PROJECT" "SOURCE" "HOST" "INPUT" "OUTPUT" "COST" "CALLS"
	printf "%s\n" \
		"--------------------------------------------------------------------------------------------"

	# Local data
	sqlite3 -separator '|' "$DB_FILE" "
		SELECT COALESCE(project_id, 'unknown'),
		       'local',
		       COALESCE(execution_host, '$PLAN_DB_HOST'),
		       SUM(input_tokens), SUM(output_tokens),
		       PRINTF('%.2f', SUM(cost_usd)),
		       COUNT(*)
		FROM token_usage
		GROUP BY project_id, execution_host
		ORDER BY SUM(cost_usd) DESC;
	" | while IFS='|' read -r proj src host input output cost calls; do
		printf "%-20s %-12s %-25s %12s %12s \$%9s %6s\n" \
			"$(_truncate "$proj" 19)" "$src" "$(_truncate "$host" 24)" \
			"$input" "$output" "$cost" "$calls"
	done

	# Remote peers: use cluster helper if available, else REMOTE_HOST fallback
	local all_peers peer_name ssh_target
	if declare -f _cluster_online_peers &>/dev/null; then
		all_peers="$(_cluster_online_peers 2>/dev/null)"
	elif [[ -n "${REMOTE_HOST:-}" ]]; then
		if ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT:-5}" -o BatchMode=yes \
			-o StrictHostKeyChecking=no -o LogLevel=quiet \
			"$REMOTE_HOST" true &>/dev/null; then
			all_peers="${REMOTE_HOST}|${REMOTE_HOST}"
		fi
	fi

	if [[ -n "${all_peers:-}" ]]; then
		while IFS='|' read -r peer_name ssh_target; do
			[[ -z "$peer_name" ]] && continue
			ssh -o ConnectTimeout=10 \
				-o StrictHostKeyChecking=no -o LogLevel=quiet \
				"$ssh_target" "
				sqlite3 -separator '|' ~/.claude/data/dashboard.db \"
					SELECT COALESCE(project_id, 'unknown'),
					       '${peer_name}',
					       COALESCE(execution_host, '${peer_name}'),
					       SUM(input_tokens), SUM(output_tokens),
					       PRINTF('%.2f', SUM(cost_usd)),
					       COUNT(*)
					FROM token_usage
					GROUP BY project_id, execution_host
					ORDER BY SUM(cost_usd) DESC;
				\"
			" 2>/dev/null | while IFS='|' read -r proj src host input output cost calls; do
				printf "%-20s %-12s %-25s %12s %12s \$%9s %6s\n" \
					"$(_truncate "$proj" 19)" "$src" "$(_truncate "$host" 24)" \
					"$input" "$output" "$cost" "$calls"
			done
		done <<<"$all_peers"
	fi

	echo ""
	echo -e "${YELLOW}Local totals:${NC}"
	local totals total_in total_out total_cost total_calls
	totals=$(sqlite3 -separator '|' "$DB_FILE" "
		SELECT SUM(input_tokens), SUM(output_tokens),
		       PRINTF('%.2f', SUM(cost_usd)), COUNT(*)
		FROM token_usage;
	")
	IFS='|' read -r total_in total_out total_cost total_calls <<<"$totals"
	printf "  Input: %s | Output: %s | Cost: \$%s | Calls: %s\n" \
		"$total_in" "$total_out" "$total_cost" "$total_calls"
}
