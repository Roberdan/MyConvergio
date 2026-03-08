#!/bin/bash
# Plan DB READ operations
# Sourced by plan-db-crud.sh

# List plans for a project
cmd_list() {
	local project_id="$1"
	local safe_project_id="$(sql_escape "$project_id")"
	echo -e "${BLUE}Plans for project: ${project_id}${NC}"
	echo ""
	sqlite3 -header -column "$DB_FILE" "
        SELECT id, name,
            CASE WHEN is_master THEN 'MASTER' ELSE '' END as type,
            status, tasks_done || '/' || tasks_total as progress
        FROM plans WHERE project_id = '$safe_project_id'
        ORDER BY is_master DESC, status, name;
    "
}

# Get worktree path for a plan (expanded to $HOME)
# Usage: get-worktree <plan_id>
cmd_get_worktree() {
	local plan_id="$1"
	local wt_path
	wt_path=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id = $plan_id;")
	if [[ -z "$wt_path" ]]; then
		log_error "No worktree_path set for plan $plan_id"
		exit 1
	fi
	echo "$(_expand_path "$wt_path")"
}


# Get wave worktree path (expanded to $HOME)
# Usage: get-wave-worktree <wave_db_id>
cmd_get_wave_worktree() {
	local wave_db_id="$1"
	local wt_path
	wt_path=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM waves WHERE id = $wave_db_id;")
	if [[ -z "$wt_path" ]]; then
		log_error "No worktree_path set for wave $wave_db_id"
		exit 1
	fi
	echo "$(_expand_path "$wt_path")"
}

# Show execution host for plans
# Usage: where [plan_id]
cmd_where() {
	local plan_id="${1:-}"

	if [[ -n "$plan_id" ]]; then
		local info=$(sqlite3 "$DB_FILE" "SELECT name, status, execution_host FROM plans WHERE id = $plan_id;")
		if [[ -z "$info" ]]; then
			log_error "Plan $plan_id not found"
			return 1
		fi
		local name=$(echo "$info" | cut -d'|' -f1)
		local status=$(echo "$info" | cut -d'|' -f2)
		local host=$(echo "$info" | cut -d'|' -f3)
		[[ -z "$host" ]] && host="unknown"

		# Liveness check for remote hosts
		local liveness=""
		if [[ "$host" == "$PLAN_DB_HOST" || "$host" == "unknown" ]]; then
			liveness="${GREEN}LOCAL${NC}"
		elif type cmd_is_alive &>/dev/null; then
			local alive_result=$(cmd_is_alive "$host" 2>/dev/null)
			case "$alive_result" in
			ALIVE) liveness="${GREEN}ALIVE${NC}" ;;
			STALE) liveness="${YELLOW}STALE${NC}" ;;
			*) liveness="${RED}UNREACHABLE${NC}" ;;
			esac
		fi

		echo -e "Plan $plan_id (${BLUE}$name${NC}) -> ${GREEN}$host${NC} [$status] $liveness"
		echo ""

		# Show per-task hosts for active tasks
		local task_hosts=$(sqlite3 "$DB_FILE" "
			SELECT t.task_id, t.title, t.status, COALESCE(t.executor_host, '-')
			FROM tasks t WHERE t.plan_id = $plan_id AND t.status IN ('in_progress', 'done')
			ORDER BY t.id;
		")
		if [[ -n "$task_hosts" ]]; then
			echo -e "${YELLOW}Tasks with host info:${NC}"
			while IFS='|' read -r tid title tstatus thost; do
				[[ -z "$tid" ]] && continue
				local status_color="$GREEN"
				[[ "$tstatus" == "in_progress" ]] && status_color="$YELLOW"
				echo -e "  $tid ${status_color}[$tstatus]${NC} -> $thost"
			done <<<"$task_hosts"
		fi
	else
		echo -e "${BLUE}=== Plan Execution Hosts ===${NC}"
		echo -e "Current host: ${GREEN}$PLAN_DB_HOST${NC}"
		echo ""

		local active=$(sqlite3 "$DB_FILE" "
			SELECT id, name, status, COALESCE(execution_host, 'unknown')
			FROM plans WHERE status IN ('todo', 'doing')
			ORDER BY status, id;
		")
		if [[ -z "$active" ]]; then
			echo "No active plans."
		else
			while IFS='|' read -r pid pname pstatus phost; do
				[[ -z "$pid" ]] && continue
				local host_color="$GREEN"
				[[ "$phost" == "unknown" ]] && host_color="$RED"
				[[ "$phost" == "$PLAN_DB_HOST" ]] && host_color="$GREEN" || host_color="$YELLOW"
				echo -e "  Plan $pid (${BLUE}$pname${NC}) [$pstatus] -> ${host_color}$phost${NC}"
			done <<<"$active"
		fi
	fi
}
