#!/bin/bash
# Dashboard wave and task rendering — grid layout
# Version: 2.0.0

# Render waves and tasks for a plan as bordered sections
_render_plan_waves() {
	local pid="$1"
	[[ -z "${GRID_W:-}" ]] && _grid_width
	_grid_section "WAVES & TASKS"
	dbq "SELECT id, wave_id, name, status, tasks_done, tasks_total FROM waves WHERE plan_id = $pid ORDER BY position" | while IFS='|' read -r wdb_id wid wname wstatus wdone wtotal; do
		[ -z "$wdb_id" ] && continue

		local effective_wstatus="$wstatus"
		if [ "$wdone" -eq "$wtotal" ] && [ "$wtotal" -gt 0 ]; then
			effective_wstatus="done"
		elif [ "$wdone" -gt 0 ] && [ "$wdone" -lt "$wtotal" ]; then
			local non_done_non_human
			non_done_non_human=$(dbq "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wdb_id AND status <> 'done' AND NOT (status = 'blocked' AND (notes LIKE '%Human-only%' OR notes LIKE '%human%' OR notes LIKE '%user acceptance%'))")
			[ "$non_done_non_human" -eq 0 ] && effective_wstatus="waiting_human" || effective_wstatus="in_progress"
		fi

		local icon
		case $effective_wstatus in
		done) icon="✓" ;;
		in_progress) icon="⚡" ;;
		waiting_human) icon="👤" ;;
		blocked) icon="⏸" ;;
		*) icon="◯" ;;
		esac

		_grid_box_start "${icon} ${wid} ${wname} (${wdone}/${wtotal})"

		local task_lines
		task_lines=$(dbq "SELECT t.task_id, REPLACE(REPLACE(t.title, char(10), ' '), char(13), ''), t.status, t.priority, COALESCE(t.model, ''), REPLACE(REPLACE(COALESCE(t.notes, ''), char(10), ' '), char(13), ''), t.validated_at, COALESCE(t.effort_level, 1) FROM tasks t WHERE t.wave_id_fk = $wdb_id ORDER BY t.task_id")

		if [ -z "$task_lines" ]; then
			_grid_row "  (no tasks)"
			_grid_box_end
			continue
		fi

		if [ "$effective_wstatus" = "done" ] && [ "${EXPAND_COMPLETED:-1}" -eq 0 ]; then
			local w_validated
			w_validated=$(dbq "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wdb_id AND validated_at IS NOT NULL")
			if [ "$w_validated" -eq "$wtotal" ]; then
				_grid_row "  ${GREEN}${wdone} tasks complete  T✓ all validated${NC}"
			else
				_grid_row "  ${GREEN}${wdone} tasks complete${NC}  ${YELLOW}T: ${w_validated}/${wtotal} validated${NC}"
			fi
			_grid_box_end
			continue
		fi

		echo "$task_lines" | while IFS='|' read -r tid ttitle tstatus tprio tmodel tnotes tvalidated teffort; do
			[ -z "$tid" ] && continue

			local is_human=0
			{ [[ "$tnotes" == *"Human-only"* ]] || [[ "$tnotes" == *"human"* ]] || [[ "$tnotes" == *"user acceptance"* ]]; } && is_human=1

			local thor_badge=""
			if [ "$tstatus" = "done" ]; then
				[ -n "$tvalidated" ] && thor_badge="${GREEN}T✓${NC}" || thor_badge="${RED}T!${NC}"
			fi

			local task_icon
			case $tstatus in
			done) task_icon="${GREEN}✓${NC}" ;;
			in_progress) task_icon="${YELLOW}⚡${NC}" ;;
			blocked) [ "$is_human" -eq 1 ] && task_icon="${CYAN}👤${NC}" || task_icon="${YELLOW}⏸${NC}" ;;
			*) task_icon="${GRAY}◯${NC}" ;;
			esac

			local effort_badge
			case $teffort in
			3) effort_badge="${RED}E3${NC}" ;;
			2) effort_badge="${YELLOW}E2${NC}" ;;
			*) effort_badge="${GRAY}E1${NC}" ;;
			esac

			local short_title
			short_title=$(echo "$ttitle" | cut -c1-42)
			[ ${#ttitle} -gt 42 ] && short_title="${short_title}..."

			local indicator="  "
			[ "$tstatus" = "in_progress" ] && indicator="${YELLOW}▶ ${NC}"
			[ "$tstatus" = "blocked" ] && indicator="${YELLOW}⏸ ${NC}"
			_grid_row "$(echo -e "$indicator$task_icon") ${CYAN}${tid}${NC} ${WHITE}${short_title}${NC} $(echo -e "$effort_badge $thor_badge")"
		done

		_grid_box_end
	done
}

# Render human action required section
_render_human_actions() {
	local pid="$1"
	local human_tasks
	human_tasks=$(dbq "SELECT t.task_id, t.title, w.wave_id, REPLACE(REPLACE(COALESCE(t.description, t.title), char(10), ' '), char(13), '') FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE w.plan_id = $pid AND t.status = 'blocked' AND (t.notes LIKE '%Human-only%' OR t.notes LIKE '%human%' OR t.notes LIKE '%user acceptance%')" 2>/dev/null)
	[ -z "$human_tasks" ] && return 0

	local human_count
	human_count=$(echo "$human_tasks" | grep -c '|' 2>/dev/null || echo 0)
	[[ -z "${GRID_W:-}" ]] && _grid_width
	echo ""
	_grid_box_start "ACTION REQUIRED (${human_count})"
	echo "$human_tasks" | while IFS='|' read -r tid ttitle twid tdesc; do
		[ -z "$tid" ] && continue
		_grid_row "  ${CYAN}👤 ${tid}${NC} ${WHITE}${ttitle}${NC}  ${GRAY}(${twid})${NC}"
		if [ -n "$tdesc" ] && [ "$tdesc" != "$ttitle" ]; then
			local desc_line
			desc_line=$(echo "$tdesc" | cut -c1-$((GRID_W - 8)))
			_grid_row "    ${YELLOW}→ ${desc_line}${NC}"
		fi
	done
	_grid_box_end
}
