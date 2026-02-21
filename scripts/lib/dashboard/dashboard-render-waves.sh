#!/bin/bash
# Dashboard wave and task rendering
# Version: 1.4.0

# Render waves and tasks tree for a plan
_render_plan_waves() {
	local pid="$1"
	echo -e "${BOLD}${WHITE}Waves & Tasks${NC}"
	local wave_count=0
	wave_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM waves WHERE plan_id = $pid")
	local wave_idx=0
	sqlite3 "$DB" "SELECT id, wave_id, name, status, tasks_done, tasks_total FROM waves WHERE plan_id = $pid ORDER BY position" | while IFS='|' read -r wdb_id wid wname wstatus wdone wtotal; do
		wave_idx=$((wave_idx + 1))
		local is_last_wave=0
		[ "$wave_idx" -eq "$wave_count" ] && is_last_wave=1

		local wave_prefix="${GRAY}├─${NC}"
		local child_prefix="${GRAY}│  ${NC}"
		if [ "$is_last_wave" -eq 1 ]; then
			wave_prefix="${GRAY}└─${NC}"
			child_prefix="${GRAY}   ${NC}"
		fi

		# Derive visual status from actual task counts
		local effective_wstatus="$wstatus"
		if [ "$wdone" -eq "$wtotal" ] && [ "$wtotal" -gt 0 ]; then
			effective_wstatus="done"
		elif [ "$wdone" -gt 0 ] && [ "$wdone" -lt "$wtotal" ]; then
			local non_done_non_human
			non_done_non_human=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wdb_id AND status <> 'done' AND NOT (status = 'blocked' AND (notes LIKE '%Human-only%' OR notes LIKE '%human%' OR notes LIKE '%user acceptance%'))")
			if [ "$non_done_non_human" -eq 0 ]; then
				effective_wstatus="waiting_human"
			else
				effective_wstatus="in_progress"
			fi
		fi

		local icon
		case $effective_wstatus in
		done) icon="${GREEN}✓${NC}" ;;
		in_progress) icon="${YELLOW}⚡${NC}" ;;
		waiting_human) icon="${CYAN}👤${NC}" ;;
		blocked) icon="${YELLOW}⏸${NC}" ;;
		*) icon="${GRAY}◯${NC}" ;;
		esac

		echo -e "${wave_prefix} $icon ${CYAN}$wid${NC} ${WHITE}$wname${NC} ${GRAY}($wdone/$wtotal)${NC}"

		# Nested tasks under this wave
		local task_lines task_count_w=0
		task_lines=$(sqlite3 "$DB" "SELECT t.task_id, REPLACE(REPLACE(t.title, char(10), ' '), char(13), ''), t.status, t.priority, COALESCE(t.model, ''), REPLACE(REPLACE(COALESCE(t.notes, ''), char(10), ' '), char(13), ''), t.validated_at, COALESCE(t.effort_level, 1) FROM tasks t WHERE t.wave_id_fk = $wdb_id ORDER BY t.task_id")
		task_count_w=$(echo "$task_lines" | grep -c '|' 2>/dev/null || echo 0)

		if [ -z "$task_lines" ]; then
			continue
		fi

		# For done waves with EXPAND_COMPLETED=0, show compressed with validation count
		if [ "$effective_wstatus" = "done" ] && [ "$EXPAND_COMPLETED" -eq 0 ]; then
			local w_validated
			w_validated=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wdb_id AND validated_at IS NOT NULL")
			if [ "$w_validated" -eq "$wtotal" ]; then
				echo -e "${child_prefix}${GRAY}└─ ${wdone} tasks completati${NC} ${GREEN}T✓${NC}"
			else
				echo -e "${child_prefix}${GRAY}└─ ${wdone} tasks completati${NC} ${YELLOW}T:${w_validated}/${wtotal}${NC}"
			fi
			continue
		fi

		local tidx=0
		echo "$task_lines" | while IFS='|' read -r tid ttitle tstatus tprio tmodel tnotes tvalidated teffort; do
			[ -z "$tid" ] && continue
			tidx=$((tidx + 1))
			local is_last_task=0
			[ "$tidx" -eq "$task_count_w" ] && is_last_task=1

			local task_connector="${child_prefix}${GRAY}├─${NC}"
			[ "$is_last_task" -eq 1 ] && task_connector="${child_prefix}${GRAY}└─${NC}"

			# Detect human-action-required tasks
			local is_human=0
			if [[ "$tnotes" == *"Human-only"* ]] || [[ "$tnotes" == *"human"* ]] || [[ "$tnotes" == *"user acceptance"* ]]; then
				is_human=1
			fi

			# Thor validation badge
			local thor_badge=""
			if [ "$tstatus" = "done" ]; then
				if [ -n "$tvalidated" ]; then
					thor_badge="${GREEN}T✓${NC}"
				else
					thor_badge="${RED}T!${NC}"
				fi
			fi

			local icon
			case $tstatus in
			done) icon="${GREEN}✓${NC}" ;;
			in_progress) icon="${YELLOW}⚡${NC}" ;;
			blocked)
				if [ "$is_human" -eq 1 ]; then
					icon="${CYAN}👤${NC}"
				else
					icon="${YELLOW}⏸${NC}"
				fi
				;;
			*) icon="${GRAY}◯${NC}" ;;
			esac

			# Effort + model badge
			local effort_badge=""
			case $teffort in
			3) effort_badge="${RED}E3${NC}" ;;
			2) effort_badge="${YELLOW}E2${NC}" ;;
			*) effort_badge="${GRAY}E1${NC}" ;;
			esac
			local model_badge=""
			[ -n "$tmodel" ] && model_badge="${GRAY}${tmodel}${NC}"

			local short_title=$(echo "$ttitle" | cut -c1-45)
			[ ${#ttitle} -gt 45 ] && short_title="${short_title}..."
			echo -e "${task_connector} $icon ${CYAN}$tid${NC} ${WHITE}$short_title${NC} ${GRAY}[$tprio]${NC} $effort_badge $model_badge $thor_badge"
		done
	done
}

# Render human action required section
_render_human_actions() {
	local pid="$1"
	local human_tasks
	human_tasks=$(sqlite3 "$DB" "SELECT t.task_id, t.title, w.wave_id, REPLACE(REPLACE(COALESCE(t.description, t.title), char(10), ' '), char(13), '') FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE w.plan_id = $pid AND t.status = 'blocked' AND (t.notes LIKE '%Human-only%' OR t.notes LIKE '%human%' OR t.notes LIKE '%user acceptance%')" 2>/dev/null)
	if [ -n "$human_tasks" ]; then
		echo ""
		local human_count
		human_count=$(echo "$human_tasks" | wc -l | tr -d ' ')
		echo -e "${BOLD}${CYAN}👤 Action Required ($human_count)${NC}"
		local hidx=0
		echo "$human_tasks" | while IFS='|' read -r tid ttitle twid tdesc; do
			[ -z "$tid" ] && continue
			hidx=$((hidx + 1))
			local is_last=0
			[ "$hidx" -eq "$human_count" ] && is_last=1
			local hprefix="${GRAY}├─${NC}"
			local hchild="${GRAY}│  ${NC}"
			if [ "$is_last" -eq 1 ]; then
				hprefix="${GRAY}└─${NC}"
				hchild="${GRAY}   ${NC}"
			fi
			echo -e "${hprefix} ${CYAN}👤${NC} ${CYAN}$tid${NC} ${WHITE}$ttitle${NC} ${GRAY}($twid)${NC}"
			# Show actionable description
			if [ -n "$tdesc" ] && [ "$tdesc" != "$ttitle" ]; then
				local desc_line
				desc_line=$(echo "$tdesc" | cut -c1-70)
				echo -e "${hchild}${YELLOW}→ $desc_line${NC}"
				if [ ${#tdesc} -gt 70 ]; then
					desc_line=$(echo "$tdesc" | cut -c71-140)
					[ -n "$desc_line" ] && echo -e "${hchild}${YELLOW}  $desc_line${NC}"
				fi
			fi
		done
	fi
}
