#!/bin/bash
# Dashboard rendering functions — plan detail view
# Version: 3.0.0

# Render single plan detail view
_render_single_plan() {
	local plan_info
	plan_info=$(dbq "SELECT id, name, status, project_id, source_file, created_at, started_at, completed_at, validated_at, validated_by, worktree_path, parallel_mode, COALESCE(human_summary, ''), REPLACE(REPLACE(COALESCE(description, ''), char(10), ' '), char(13), ''), markdown_path, COALESCE(lines_added, 0), COALESCE(lines_removed, 0) FROM plans WHERE id = $PLAN_ID")
	if [ -z "$plan_info" ]; then
		echo -e "${RED}Piano #$PLAN_ID non trovato${NC}"
		return 1
	fi

	local pid pname pstatus pproject psource pcreated pstarted pcompleted pvalidated pvalidator pworktree pparallel phuman_summary pdescription pmarkdown plines_added plines_removed
	pid=$(echo "$plan_info" | cut -d'|' -f1)
	pname=$(echo "$plan_info" | cut -d'|' -f2)
	pstatus=$(echo "$plan_info" | cut -d'|' -f3)
	pproject=$(echo "$plan_info" | cut -d'|' -f4)
	psource=$(echo "$plan_info" | cut -d'|' -f5)
	pcreated=$(echo "$plan_info" | cut -d'|' -f6)
	pstarted=$(echo "$plan_info" | cut -d'|' -f7)
	pcompleted=$(echo "$plan_info" | cut -d'|' -f8)
	pvalidated=$(echo "$plan_info" | cut -d'|' -f9)
	pvalidator=$(echo "$plan_info" | cut -d'|' -f10)
	pworktree=$(echo "$plan_info" | cut -d'|' -f11)
	pparallel=$(echo "$plan_info" | cut -d'|' -f12)
	phuman_summary=$(echo "$plan_info" | cut -d'|' -f13)
	pdescription=$(echo "$plan_info" | cut -d'|' -f14)
	pmarkdown=$(echo "$plan_info" | cut -d'|' -f15)
	plines_added=$(echo "$plan_info" | cut -d'|' -f16)
	plines_removed=$(echo "$plan_info" | cut -d'|' -f17)

	local status_display
	case $pstatus in
	done) status_display="${GREEN}DONE${NC}" ;;
	doing) status_display="${YELLOW}IN PROGRESS${NC}" ;;
	cancelled) status_display="${RED}CANCELLED${NC}" ;;
	archived) status_display="${GRAY}ARCHIVED${NC}" ;;
	*) status_display="${BLUE}TODO${NC}" ;;
	esac

	local task_total task_done task_validated wave_total wave_done metrics_data
	metrics_data=$(dbq "
		SELECT
			(SELECT COUNT(*) FROM tasks WHERE plan_id = $pid AND status NOT IN ('cancelled', 'skipped')),
			(SELECT COUNT(*) FROM tasks WHERE plan_id = $pid AND status='done'),
			(SELECT COUNT(*) FROM tasks WHERE plan_id = $pid AND status='done' AND validated_at IS NOT NULL),
			(SELECT COUNT(*) FROM waves WHERE plan_id = $pid AND status NOT IN ('cancelled')),
			(SELECT COUNT(*) FROM waves WHERE plan_id = $pid AND tasks_done = tasks_total AND tasks_total > 0)
	")
	task_total=$(echo "$metrics_data" | cut -d'|' -f1)
	task_done=$(echo "$metrics_data" | cut -d'|' -f2)
	task_validated=$(echo "$metrics_data" | cut -d'|' -f3)
	wave_total=$(echo "$metrics_data" | cut -d'|' -f4)
	wave_done=$(echo "$metrics_data" | cut -d'|' -f5)

	local elapsed_time=""
	if [ -n "$pcompleted" ] && [ -n "$pstarted" ]; then
		local start_ts end_ts
		start_ts=$(date_to_epoch "$pstarted")
		end_ts=$(date_to_epoch "$pcompleted")
		elapsed_time=$(format_elapsed $((end_ts - start_ts)))
	elif [ -n "$pstarted" ]; then
		local start_ts
		start_ts=$(date_to_epoch "$pstarted")
		elapsed_time=$(format_elapsed $(($(date +%s) - start_ts)))
	fi

	_grid_width
	_grid_header "PLAN #${pid}: ${pname}  $(echo -e "$status_display")"

	# Description box
	local desc_to_show="${phuman_summary:-$pdescription}"
	if [ -n "$desc_to_show" ]; then
		_grid_box_start "SCOPE"
		echo "$desc_to_show" | fold -s -w $((GRID_W - 6)) | while IFS= read -r line; do
			_grid_row "  ${WHITE}${line}${NC}"
		done
		_grid_box_end
		echo ""
	fi

	# Metadata grid box
	_grid_box_start "METRICS"
	_grid_row "  Status: $(echo -e "$status_display")    Project: ${BLUE}${pproject}${NC}"
	local task_line="${GREEN}${task_done}${NC}/${WHITE}${task_total}${NC} tasks"
	[ "$task_validated" -lt "$task_done" ] && task_line+="  ${GRAY}(${task_validated} Thor-validated)${NC}"
	_grid_row "  Tasks: $(echo -e "$task_line")    Waves: ${GREEN}${wave_done}${NC}/${WHITE}${wave_total}${NC}"
	if [ -n "$elapsed_time" ]; then
		local dur_label="Duration"
		[ -z "$pcompleted" ] && dur_label="Running"
		_grid_row "  ${dur_label}: ${YELLOW}${elapsed_time}${NC}"
	fi
	if [ "${plines_added:-0}" -gt 0 ] || [ "${plines_removed:-0}" -gt 0 ]; then
		_grid_row "  Git: ${GREEN}+$(format_lines "${plines_added:-0}")${NC}  ${RED}-$(format_lines "${plines_removed:-0}")${NC} lines"
	fi
	local total_tokens tokens_formatted
	total_tokens=$(dbq "SELECT COALESCE(SUM(input_tokens + output_tokens), 0) FROM token_usage WHERE project_id = '$pproject'")
	tokens_formatted=$(format_tokens "$total_tokens")
	_grid_row "  Tokens: ${CYAN}${tokens_formatted}${NC} (project)"
	[ -n "$pvalidated" ] && _grid_row "  Thor: ${GREEN}✓ ${pvalidator}${NC}  ${GRAY}${pvalidated}${NC}"
	_grid_row "  Created: ${GRAY}${pcreated}${NC}$([ -n "$pstarted" ] && printf '  Started: %s' "${pstarted}")"
	_grid_box_end
	echo ""

	_render_plan_references "$pmarkdown" "$psource" "$pworktree" "$pparallel" "$pproject"
	_render_plan_progress "$pid" "$task_total" "$task_done" "$task_validated" "$wave_total" "$wave_done"
	_render_plan_waves "$pid"
	_render_human_actions "$pid"

	echo ""
	_grid_section "LEGEND"
	_grid_row "  ${GREEN}✓${NC} done  ${YELLOW}⚡${NC} in_progress  ${GRAY}◯${NC} pending  ${YELLOW}⏸${NC} blocked  ${CYAN}👤${NC} needs action"
	_grid_row "  Effort: ${RED}E3${NC}=high  ${YELLOW}E2${NC}=med  ${GRAY}E1${NC}=low    Thor: ${GREEN}T✓${NC}=validated  ${RED}T!${NC}=pending"
	return 0
}

# Render plan references (ADRs, files, etc)
_render_plan_references() {
	local pmarkdown="$1" psource="$2" pworktree="$3" pparallel="$4" pproject="$5"
	local has_refs=0
	{ [ -n "$pmarkdown" ] || [ -n "$psource" ]; } && has_refs=1
	local adr_list="" pmarkdown_expanded="$pmarkdown"
	[ -n "$pmarkdown_expanded" ] && pmarkdown_expanded=$(echo "$pmarkdown_expanded" | sed "s|^~|$HOME|")
	if [ -n "$pmarkdown_expanded" ] && [ -f "$pmarkdown_expanded" ]; then
		adr_list=$(grep -oE '(docs/adr/|ADR )([A-Za-z0-9_-]+)' "$pmarkdown_expanded" 2>/dev/null | sed 's/docs\/adr\///; s/ADR //' | sort -u | head -10 || true)
	fi
	[ -n "$adr_list" ] && has_refs=1
	[ "$has_refs" -eq 0 ] && return 0

	_grid_box_start "REFERENCES"
	[ -n "$pmarkdown" ] && _grid_row "  Plan:     ${CYAN}${pmarkdown}${NC}"
	[ -n "$psource" ] && _grid_row "  Source:   ${CYAN}${psource}${NC}"
	[ -n "$pworktree" ] && _grid_row "  Worktree: ${CYAN}${pworktree}${NC}"
	[ -n "$pparallel" ] && _grid_row "  Mode:     ${GRAY}${pparallel}${NC}"
	if [ -n "$adr_list" ]; then
		_grid_row "  ADRs referenced:"
		echo "$adr_list" | while IFS= read -r adr; do
			[ -z "$adr" ] && continue
			local adr_file=""
			if [ -n "$pproject" ]; then
				local proj_dir
				proj_dir=$(find ~/GitHub -maxdepth 1 -iname "$pproject" -type d 2>/dev/null | head -1)
				[ -n "$proj_dir" ] && adr_file=$(find "$proj_dir/docs/adr" -iname "${adr}*" -type f 2>/dev/null | head -1)
			fi
			if [ -n "$adr_file" ]; then
				_grid_row "    ${CYAN}${adr}${NC}  ${GRAY}→ ${adr_file}${NC}"
			else
				_grid_row "    ${CYAN}${adr}${NC}"
			fi
		done
	fi
	_grid_box_end
	echo ""
}

# Render full-width weighted progress bar
_render_plan_progress() {
	local pid="$1" task_total="$2" task_done="$3" task_validated="$4" wave_total="$5" wave_done="$6"
	local wp_data wp_done wp_total task_progress
	wp_data=$(calc_weighted_progress "plan_id = $pid")
	wp_done=$(echo "$wp_data" | cut -d'|' -f1)
	wp_total=$(echo "$wp_data" | cut -d'|' -f2)
	task_progress=$((wp_total > 0 ? wp_done * 100 / wp_total : 0))
	local wave_progress
	wave_progress=$((wave_total > 0 ? wave_done * 100 / wave_total : 0))
	local unvalidated=$((task_done - task_validated))
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local bar_width=$((GRID_W - 14))
	[[ $bar_width -lt 10 ]] && bar_width=10

	_grid_section "PROGRESS" "(Thor-gated: only validated tasks count)"
	_grid_progress_bar "$task_progress" "$bar_width" "(weighted by effort)"
	_grid_row "  Executor: ${GREEN}${task_done}${NC}/${WHITE}${task_total}${NC} done    Thor: ${GREEN}${task_validated}${NC}/${WHITE}${task_done}${NC} validated"
	[ "$unvalidated" -gt 0 ] && _grid_row "  ${YELLOW}${unvalidated} done but not Thor-validated${NC}"
	_grid_row "  Waves: ${GREEN}${wave_done}${NC}/${WHITE}${wave_total}${NC} complete ${GRAY}(${wave_progress}%)${NC}"
	echo ""
}

# Main dashboard rendering function
render_dashboard() {
	if [ -n "$PLAN_ID" ]; then
		_render_single_plan
		return $?
	fi
	_render_dashboard_overview
}
