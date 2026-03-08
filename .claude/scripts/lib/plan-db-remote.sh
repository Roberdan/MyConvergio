#!/bin/bash
# Plan DB Remote - Cross-machine cluster commands
# Functions for remote status, cluster views, and token reports
# Sourced by plan-db.sh

# ============================================================
# cmd_remote_status [project_id]
# ============================================================
# SSH to remote host and run plan-db.sh status
# Version: 1.1.0
cmd_remote_status() {
	local project_id="${1:-}"
	load_sync_config

	echo -e "${BLUE}=== Remote Status: ${REMOTE_HOST} ===${NC}"

	if ! ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT:-5}" -o BatchMode=yes "$REMOTE_HOST" "echo ok" &>/dev/null; then
		log_error "Cannot reach $REMOTE_HOST"
		return 1
	fi

	local remote_args="status"
	[[ -n "$project_id" ]] && remote_args="status $project_id"

	ssh -o ConnectTimeout=10 "$REMOTE_HOST" \
		"bash ~/.claude/scripts/plan-db.sh $remote_args 2>/dev/null" || {
		log_error "Remote command failed"
		return 1
	}
}

# ============================================================
# cmd_cluster_status
# ============================================================
# Unified view: local + remote active plans merged
cmd_cluster_status() {
	load_sync_config

	echo -e "${BLUE}======= CLUSTER STATUS =======${NC}"

	# Local active plans
	local local_plans
	local_plans=$(sqlite3 -separator '|' "$DB_FILE" "
		SELECT p.id, p.name, p.tasks_done || '/' || p.tasks_total,
		       COALESCE(p.execution_host, '$PLAN_DB_HOST'), p.status
		FROM plans p WHERE p.status IN ('doing','todo')
		ORDER BY p.status, p.id;
	")

	# Connectivity check
	local remote_online=0
	local remote_plans=""
	if ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT:-5}" -o BatchMode=yes "$REMOTE_HOST" "echo ok" &>/dev/null; then
		remote_online=1
		remote_plans=$(ssh -o ConnectTimeout=10 "$REMOTE_HOST" "
			sqlite3 -separator '|' ~/.claude/data/dashboard.db \"
				SELECT p.id, p.name, p.tasks_done || '/' || p.tasks_total,
				       COALESCE(p.execution_host, '$(hostname -s)'), p.status
				FROM plans p WHERE p.status IN ('doing','todo')
				ORDER BY p.status, p.id;
			\"
		" 2>/dev/null) || remote_plans=""
	fi

	# Header
	local conn_status pid pname prog host status host_short
	if [[ $remote_online -eq 1 ]]; then
		conn_status="${GREEN}ONLINE${NC}"
	else
		conn_status="${RED}OFFLINE${NC}"
	fi
	echo -e "Local: ${GREEN}$PLAN_DB_HOST${NC} | Remote: $REMOTE_HOST [$conn_status]"
	echo ""

	# Merged output
	printf "%-6s %-4s %-25s %-8s %-30s\n" "HOST" "ID" "PLAN" "PROG" "STATUS"
	printf "%s\n" "----------------------------------------------------------------------"

	# Print local plans
	while IFS='|' read -r pid pname prog host status; do
		[[ -z "$pid" ]] && continue
		local host_short="${host%%.*}"
		if [[ "$host_short" == "${PLAN_DB_HOST%%.*}" ]]; then
			printf "%-6s %-4s %-25s %-8s %-30s\n" "LOCAL" "$pid" "$(_truncate "$pname" 24)" "$prog" "$status"
		else
			printf "%-6s %-4s %-25s %-8s %-30s\n" "$host_short" "$pid" "$(_truncate "$pname" 24)" "$prog" "$status"
		fi
	done <<<"$local_plans"

	# Print remote plans (skip duplicates already synced to local)
	if [[ -n "$remote_plans" ]]; then
		while IFS='|' read -r pid pname prog host status; do
			[[ -z "$pid" ]] && continue
			printf "%-6s %-4s %-25s %-8s %-30s\n" "REMOTE" "$pid" "$(_truncate "$pname" 24)" "$prog" "$status"
		done <<<"$remote_plans"
	fi
}

# ============================================================
# cmd_cluster_tasks
# ============================================================
# In-progress tasks from local DB with host info
cmd_cluster_tasks() {
	load_sync_config

	echo -e "${BLUE}======= CLUSTER TASKS =======${NC}"

	# Local in-progress tasks
	echo -e "\n${GREEN}$PLAN_DB_HOST (local):${NC}"
	sqlite3 -column "$DB_FILE" "
		SELECT t.task_id, t.title, t.wave_id,
		       COALESCE(t.executor_host, '$PLAN_DB_HOST') as host
		FROM tasks t
		WHERE t.status = 'in_progress'
		ORDER BY t.wave_id, t.task_id;
	"

	# Remote in-progress tasks via SSH
	if ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT:-5}" -o BatchMode=yes "$REMOTE_HOST" "echo ok" &>/dev/null; then
		echo -e "\n${YELLOW}$REMOTE_HOST (remote):${NC}"
		ssh -o ConnectTimeout=10 "$REMOTE_HOST" "
			sqlite3 -column ~/.claude/data/dashboard.db \"
				SELECT t.task_id, t.title, t.wave_id,
				       COALESCE(t.executor_host, '$(hostname -s)') as host
				FROM tasks t
				WHERE t.status = 'in_progress'
				ORDER BY t.wave_id, t.task_id;
			\"
		" 2>/dev/null || echo "  (no data)"
	else
		echo -e "\n${RED}$REMOTE_HOST: UNREACHABLE${NC}"
	fi
}

# ============================================================
# cmd_token_report
# ============================================================
# Per-project token/cost totals aggregated across hosts
cmd_token_report() {
	echo -e "${BLUE}======= TOKEN REPORT =======${NC}"
	echo ""

	printf "%-20s %-25s %12s %12s %10s %6s\n" \
		"PROJECT" "HOST" "INPUT" "OUTPUT" "COST" "CALLS"
	printf "%s\n" \
		"------------------------------------------------------------------------------------"

	sqlite3 -separator '|' "$DB_FILE" "
		SELECT COALESCE(project_id, 'unknown'),
		       COALESCE(execution_host, '$PLAN_DB_HOST'),
		       SUM(input_tokens), SUM(output_tokens),
		       PRINTF('%.2f', SUM(cost_usd)),
		       COUNT(*)
		FROM token_usage
		GROUP BY project_id, execution_host
		ORDER BY SUM(cost_usd) DESC;
	" | while IFS='|' read -r proj host input output cost calls; do
		printf "%-20s %-25s %12s %12s \$%9s %6s\n" \
			"$(_truncate "$proj" 19)" "$(_truncate "$host" 24)" \
			"$input" "$output" "$cost" "$calls"
	done

	echo ""
	echo -e "${YELLOW}Totals:${NC}"
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
