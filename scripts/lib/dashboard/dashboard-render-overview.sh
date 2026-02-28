#!/bin/bash
# Dashboard overview rendering (multi-plan mode)
# Version: 2.1.0

_render_dashboard_overview() {
	echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${BOLD}${CYAN}║${NC}          ${BOLD}${WHITE}🎯 Convergio.io - Dashboard Piani${NC}          ${BOLD}${CYAN}║${NC}"
	echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
	echo ""

	# Overview (single query, uses plan_id direct index instead of nested wave subqueries)
	local overview
	overview=$(dbq "
SELECT
(SELECT COUNT(*) FROM plans),
(SELECT COUNT(*) FROM plans WHERE status='done'),
(SELECT COUNT(*) FROM plans WHERE status='doing'),
(SELECT COUNT(*) FROM plans WHERE status='todo'),
(SELECT COUNT(*) FROM tasks WHERE plan_id IN (SELECT id FROM plans WHERE status='doing')),
(SELECT COUNT(*) FROM tasks WHERE status='done' AND plan_id IN (SELECT id FROM plans WHERE status='doing')),
(SELECT COUNT(*) FROM tasks WHERE status='in_progress' AND plan_id IN (SELECT id FROM plans WHERE status='doing')),
(SELECT COUNT(*) FROM plans WHERE status='cancelled');
")
	local total plan_done doing todo total_tasks done_tasks in_progress_tasks cancelled
	total=$(echo "$overview" | cut -d'|' -f1)
	plan_done=$(echo "$overview" | cut -d'|' -f2)
	doing=$(echo "$overview" | cut -d'|' -f3)
	todo=$(echo "$overview" | cut -d'|' -f4)
	total_tasks=$(echo "$overview" | cut -d'|' -f5)
	done_tasks=$(echo "$overview" | cut -d'|' -f6)
	in_progress_tasks=$(echo "$overview" | cut -d'|' -f7)
	cancelled=$(echo "$overview" | cut -d'|' -f8)

	echo -e "${BOLD}${WHITE}📊 Overview${NC}"
	local plan_line="${GREEN}${plan_done}${NC} done, ${YELLOW}${doing}${NC} doing, ${BLUE}${todo}${NC} todo"
	[ "${cancelled:-0}" -gt 0 ] && plan_line+=", ${RED}${cancelled}${NC} cancelled"
	echo -e "${GRAY}├─${NC} Piani: $plan_line ${GRAY}(${total} totali)${NC}"
	echo -e "${GRAY}└─${NC} Tasks attivi: ${GREEN}${done_tasks}${NC} done, ${YELLOW}${in_progress_tasks}${NC} in progress ${GRAY}(${total_tasks} totali)${NC}"
	echo ""

	# Active plans
	_render_active_plans

	# Pipeline plans
	_render_pipeline_plans

	# Blocked tasks (if requested)
	if [ "$SHOW_BLOCKED" -eq 1 ]; then
		local blocked_count
		blocked_count=$(dbq "SELECT COUNT(*) FROM tasks WHERE status='blocked'" 2>/dev/null)
		if [ "$blocked_count" -gt 0 ]; then
			echo -e "${BOLD}${RED}✗ Task Bloccati ($blocked_count)${NC}"
			dbq "SELECT t.task_id, REPLACE(REPLACE(t.title, char(10), ' '), char(13), ''), p.id, p.project_id FROM tasks t JOIN waves w ON t.wave_id_fk = w.id JOIN plans p ON w.plan_id = p.id WHERE t.status = 'blocked' ORDER BY p.id" 2>/dev/null | while IFS='|' read -r task_id title plan_id blocked_project; do
				local short_title
				short_title=$(echo "$title" | cut -c1-45)
				[ ${#title} -gt 45 ] && short_title="${short_title}..."
				local blocked_project_display=""
				[ -n "$blocked_project" ] && blocked_project_display="${BLUE}[$blocked_project]${NC} "
				echo -e "${GRAY}├─${NC} ${RED}$task_id${NC} ${WHITE}$short_title${NC} ${blocked_project_display}${GRAY}[#$plan_id]${NC}"
			done
			echo -e "${GRAY}└─${NC}"
			echo ""
		fi
	fi

	# Last 7 completed/cancelled plans (compact list + total count)
	local completed_data
	completed_data=$(dbq "
		SELECT COUNT(*) FROM plans WHERE status IN ('done', 'cancelled');
	")
	local completed_total="${completed_data:-0}"
	if [ "$completed_total" -gt 0 ]; then
		echo -e "${GRAY}Recenti ${GRAY}(${GREEN}${completed_total}${GRAY} totali — premi ${WHITE}C${GRAY} per tutti):${NC}"
		dbq "
			SELECT p.id, p.name, p.project_id, p.status,
				COALESCE(p.completed_at, p.updated_at, p.created_at),
				(SELECT COUNT(*) FROM tasks WHERE plan_id=p.id)
			FROM plans p WHERE p.status IN ('done', 'cancelled')
			ORDER BY COALESCE(p.completed_at, p.updated_at, p.created_at) DESC LIMIT 7
		" | while IFS='|' read -r pid pname pproject pstatus pcompleted ptasks; do
			[ -z "$pid" ] && continue
			local short_name=$(echo "$pname" | cut -c1-35)
			[ ${#pname} -gt 35 ] && short_name="${short_name}..."
			local date_short=$(echo "$pcompleted" | cut -c1-10)
			if [ "$pstatus" = "cancelled" ]; then
				echo -e "${GRAY}  ${RED}#${pid}${NC} ${GRAY}${short_name}${NC} ${GRAY}[${pproject}] ${date_short} (${ptasks}t)${NC} ${RED}CANCELLED${NC}"
			else
				echo -e "${GRAY}  ${GREEN}#${pid}${NC} ${WHITE}${short_name}${NC} ${GRAY}[${pproject}] ${date_short} (${ptasks}t)${NC}"
			fi
		done
		echo ""
	fi

	# Warn about active/pipeline plans missing descriptions
	local missing_desc
	missing_desc=$(dbq "SELECT GROUP_CONCAT('#' || id, ', ') FROM plans WHERE status IN ('doing', 'todo') AND (description IS NULL OR description = '' OR description = '{')")
	if [ -n "$missing_desc" ]; then
		echo -e "${YELLOW}⚠ Piani senza descrizione: ${WHITE}${missing_desc}${NC}"
		echo -e "${GRAY}  Usa: plan-db.sh update-desc <id> \"descrizione\"${NC}"
		echo ""
	fi

	echo -e "${GRAY}Usa ${WHITE}piani -h${GRAY} per opzioni${NC}"
	echo ""
}
