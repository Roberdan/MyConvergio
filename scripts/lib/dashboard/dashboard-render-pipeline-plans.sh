#!/bin/bash
# Pipeline plans rendering
# Version: 2.0.0

_render_pipeline_plans() {
	local pipeline_count
	pipeline_count=$(dbq "SELECT COUNT(*) FROM plans WHERE status='todo'")
	echo -e "${BOLD}${WHITE}📋 In Pipeline ($pipeline_count)${NC}"
	dbq "
		SELECT p.id, p.name, p.created_at, p.project_id,
			COALESCE(p.human_summary, REPLACE(REPLACE(COALESCE(p.description, ''), char(10), ' '), char(13), '')),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND status NOT IN ('cancelled')),
			(SELECT COUNT(*) FROM tasks WHERE plan_id=p.id AND status NOT IN ('cancelled', 'skipped'))
		FROM plans p WHERE p.status='todo' ORDER BY p.created_at DESC
	" | while IFS='|' read -r pid pname pcreated pproject pdescription wave_count task_count; do
		[ -z "$pid" ] && continue
		# Days since created
		if [ -n "$pcreated" ]; then
			create_date=$(echo "$pcreated" | cut -d' ' -f1)
			days_old=$((($(date +%s) - $(date_only_to_epoch "$create_date")) / 86400))
			if [ "$days_old" -eq 0 ]; then
				age_info="${GREEN}oggi${NC}"
			elif [ "$days_old" -eq 1 ]; then
				age_info="${YELLOW}ieri${NC}"
			elif [ "$days_old" -gt 7 ]; then
				age_info="${RED}${days_old}g fa${NC}"
			else
				age_info="${GRAY}${days_old}g fa${NC}"
			fi
		else
			age_info=""
		fi

		short_name=$(echo "$pname" | cut -c1-50)
		[ ${#pname} -gt 50 ] && short_name="${short_name}..."
		project_display=""
		[ -n "$pproject" ] && project_display="${BLUE}[$pproject]${NC} "

		echo -e "${GRAY}├─${NC} ${BLUE}◯${NC} ${YELLOW}[#$pid]${NC} ${project_display}${WHITE}$short_name${NC} ${GRAY}(creato: ${age_info}${GRAY})${NC}"
		[ -n "$pdescription" ] && echo -e "${GRAY}│  ${NC}${GRAY}$(truncate_desc "$pdescription")${NC}"
		echo -e "${GRAY}│  └─${NC} ${GRAY}${wave_count} waves,${NC} ${BOLD}${WHITE}${task_count} tasks${NC}"
	done

	echo -e "${GRAY}└─${NC}"
	echo ""
}
