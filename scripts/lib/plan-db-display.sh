#!/bin/bash
# Plan DB Display - Output and export functions
# Sourced by plan-db.sh

# Version: 1.2.0

# Disable colors when stdout is not a terminal
[[ ! -t 1 ]] && GREEN='' && YELLOW='' && BLUE='' && RED='' && NC=''

# Truncate string to max length
_truncate() {
	local str="$1"
	local max="${2:-40}"
	if [[ ${#str} -gt $max ]]; then
		echo "${str:0:$max}..."
	else
		echo "$str"
	fi
}

# Get last N path segments
_last_segments() {
	local path="$1"
	local n="${2:-2}"
	echo "$path" | rev | cut -d'/' -f1-$n | rev
}

# Get branch from worktree
_get_branch() {
	local wt_path="$1"
	# Expand tilde
	wt_path="${wt_path/#\~/$HOME}"
	# Expand ../ relative paths
	wt_path="$(cd "$(dirname "$wt_path")" 2>/dev/null && echo "${PWD}/$(basename "$wt_path")")"
	if [[ -n "$wt_path" && -d "$wt_path" ]]; then
		git -C "$wt_path" branch --show-current 2>/dev/null || echo "-"
	else
		echo "-"
	fi
}

# Show kanban board
cmd_kanban() {
	echo -e "${BLUE}=============== KANBAN BOARD ===============${NC}"
	echo ""

	echo -e "${YELLOW}DOING${NC}"
	# Query plans directly to get execution_host, description, worktree_path
	while IFS='|' read -r proj plan prog master exec_host desc wt_path; do
		local host_color desc_trunc wt_display branch wt_branch
		# Color code host
		if [[ "$exec_host" == "$PLAN_DB_HOST" ]]; then
			host_color="${GREEN}${exec_host}${NC}"
		elif [[ -n "$exec_host" ]]; then
			host_color="${YELLOW}${exec_host}${NC}"
		else
			host_color="-"
		fi

		# Truncate description
		desc_trunc="$(_truncate "$desc" 40)"

		# Get worktree and branch
		if [[ -n "$wt_path" ]]; then
			wt_display="$(_last_segments "$wt_path" 2)"
			branch="$(_get_branch "$wt_path")"
			wt_branch="${wt_display}:${branch}"
		else
			wt_branch="-"
		fi

		printf "%-15s %-25s %4s%% %-1s %-20s %-43s %s\n" \
			"$proj" "$plan" "$prog" "$master" "$host_color" "$desc_trunc" "$wt_branch"
	done < <(sqlite3 -separator '|' "$DB_FILE" "
        SELECT pr.name, p.name,
               CASE WHEN p.tasks_total > 0 THEN ROUND(100.0 * p.tasks_done / p.tasks_total) ELSE 0 END,
               CASE WHEN p.is_master THEN '*' ELSE '' END,
               COALESCE(p.execution_host, ''),
               COALESCE(p.description, ''),
               COALESCE(p.worktree_path, '')
        FROM plans p
        JOIN projects pr ON p.project_id = pr.id
        WHERE p.status = 'doing';
    ")
	[[ ${PIPESTATUS[0]} -ne 0 ]] && echo "  (none)"
	echo ""

	echo -e "${NC}TODO${NC}"
	sqlite3 -column "$DB_FILE" "
        SELECT project_name, plan_name,
               CASE WHEN is_master THEN '*' ELSE '' END as m
        FROM v_kanban WHERE status = 'todo' LIMIT 10;
    " || echo "  (none)"
	echo ""

	echo -e "${GREEN}DONE (recent)${NC}"
	sqlite3 -column "$DB_FILE" "
        SELECT project_name, plan_name, completed_at
        FROM v_kanban WHERE status = 'done'
        ORDER BY completed_at DESC LIMIT 5;
    " || echo "  (none)"
}

# Get plan as JSON (single object, not array)
cmd_json() {
	local plan_id="$1"
	sqlite3 -json "$DB_FILE" "
        SELECT p.id, p.name, p.status, p.is_master, p.tasks_done, p.tasks_total,
               p.created_at, p.started_at, p.completed_at, p.validated_at,
               pr.id as project_id, pr.name as project_name
        FROM plans p
        JOIN projects pr ON p.project_id = pr.id
        WHERE p.id = $plan_id;
    " | jq '.[0] // empty'
}

# Get kanban as JSON
cmd_kanban_json() {
	sqlite3 -json "$DB_FILE" "SELECT * FROM v_kanban;"
}

# Quick status for current context
cmd_status() {
	local project_id="${1:-}"

	echo -e "${BLUE}=== Quick Status ===${NC}"

	local safe_project_id=""
	[[ -n "$project_id" ]] && safe_project_id="$(sql_escape "$project_id")"

	# Active plans
	echo -e "\n${YELLOW}Active Plans:${NC}"
	if [[ -n "$project_id" ]]; then
		while IFS='|' read -r plan prog exec_host desc wt_path; do
			local host_color desc_trunc wt_display branch wt_branch
			# Color code host
			if [[ "$exec_host" == "$PLAN_DB_HOST" ]]; then
				host_color="${GREEN}${exec_host}${NC}"
			elif [[ -n "$exec_host" ]]; then
				host_color="${YELLOW}${exec_host}${NC}"
			else
				host_color="-"
			fi

			# Truncate description
			desc_trunc="$(_truncate "$desc" 40)"

			# Get worktree and branch
			if [[ -n "$wt_path" ]]; then
				wt_display="$(_last_segments "$wt_path" 2)"
				branch="$(_get_branch "$wt_path")"
				wt_branch="${wt_display}:${branch}"
			else
				wt_branch="-"
			fi

			printf "%-25s %-8s %-20s %-43s %s\n" \
				"$plan" "$prog" "$host_color" "$desc_trunc" "$wt_branch"
		done < <(sqlite3 -separator '|' "$DB_FILE" "
            SELECT p.name,
                   p.tasks_done || '/' || p.tasks_total,
                   COALESCE(p.execution_host, ''),
                   COALESCE(p.description, ''),
                   COALESCE(p.worktree_path, '')
            FROM plans p
            WHERE p.project_id = '$safe_project_id' AND p.status = 'doing';
        ")
	else
		while IFS='|' read -r proj plan prog exec_host desc wt_path; do
			local host_color desc_trunc wt_display branch wt_branch
			# Color code host
			if [[ "$exec_host" == "$PLAN_DB_HOST" ]]; then
				host_color="${GREEN}${exec_host}${NC}"
			elif [[ -n "$exec_host" ]]; then
				host_color="${YELLOW}${exec_host}${NC}"
			else
				host_color="-"
			fi

			# Truncate description
			desc_trunc="$(_truncate "$desc" 40)"

			# Get worktree and branch
			if [[ -n "$wt_path" ]]; then
				wt_display="$(_last_segments "$wt_path" 2)"
				branch="$(_get_branch "$wt_path")"
				wt_branch="${wt_display}:${branch}"
			else
				wt_branch="-"
			fi

			printf "%-15s %-25s %-8s %-20s %-43s %s\n" \
				"$proj" "$plan" "$prog" "$host_color" "$desc_trunc" "$wt_branch"
		done < <(sqlite3 -separator '|' "$DB_FILE" "
            SELECT pr.name, p.name,
                   p.tasks_done || '/' || p.tasks_total,
                   COALESCE(p.execution_host, ''),
                   COALESCE(p.description, ''),
                   COALESCE(p.worktree_path, '')
            FROM plans p
            JOIN projects pr ON p.project_id = pr.id
            WHERE p.status = 'doing' LIMIT 5;
        ")
	fi

	# In-progress tasks
	echo -e "\n${YELLOW}In-Progress Tasks:${NC}"
	sqlite3 -column "$DB_FILE" "
        SELECT task_id, title, wave_id FROM tasks
        WHERE status = 'in_progress'
        ${safe_project_id:+AND project_id = '$safe_project_id'}
        LIMIT 5;
    "
}
