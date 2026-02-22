#!/bin/bash
# Pipeline plans rendering
# Version: 1.4.0

_render_pipeline_plans() {
	local pipeline_count
	pipeline_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM plans WHERE status='todo'")
	echo -e "${BOLD}${WHITE}📋 In Pipeline ($pipeline_count)${NC}"
	sqlite3 "$DB" "SELECT id, name, created_at, project_id, COALESCE(human_summary, REPLACE(REPLACE(COALESCE(description, ''), char(10), ' '), char(13), '')) FROM plans WHERE status='todo' ORDER BY created_at DESC" | while IFS='|' read -r pid pname pcreated pproject pdescription; do
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

		# Wave and task counts
		wave_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM waves WHERE plan_id = $pid")
		task_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $pid)")

		# Truncate name
		short_name=$(echo "$pname" | cut -c1-50)
		[ ${#pname} -gt 50 ] && short_name="${short_name}..."

		# Project display
		project_display=""
		[ -n "$pproject" ] && project_display="${BLUE}[$pproject]${NC} "

		echo -e "${GRAY}├─${NC} ${BLUE}◯${NC} ${YELLOW}[#$pid]${NC} ${project_display}${WHITE}$short_name${NC} ${GRAY}(creato: ${age_info}${GRAY})${NC}"
		[ -n "$pdescription" ] && echo -e "${GRAY}│  ${NC}${GRAY}$(truncate_desc "$pdescription")${NC}"
		echo -e "${GRAY}│  └─${NC} ${GRAY}${wave_count} waves,${NC} ${BOLD}${WHITE}${task_count} tasks${NC}"
	done

	echo -e "${GRAY}└─${NC}"
	echo ""
}
