#!/bin/bash
# Dashboard rendering functions
# Version: 2.0.0
# This module contains all display/rendering logic

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

	# Status icon
	local status_display
	case $pstatus in
	done) status_display="${GREEN}DONE${NC}" ;;
	doing) status_display="${YELLOW}IN PROGRESS${NC}" ;;
	cancelled) status_display="${RED}CANCELLED${NC}" ;;
	archived) status_display="${GRAY}ARCHIVED${NC}" ;;
	*) status_display="${BLUE}TODO${NC}" ;;
	esac

	# Pre-compute metrics (single query instead of 5)
	local task_total task_done task_validated wave_total wave_done
	local metrics_data
	metrics_data=$(dbq "
		SELECT
			(SELECT COUNT(*) FROM tasks WHERE plan_id = $pid),
			(SELECT COUNT(*) FROM tasks WHERE plan_id = $pid AND status='done'),
			(SELECT COUNT(*) FROM tasks WHERE plan_id = $pid AND status='done' AND validated_at IS NOT NULL),
			(SELECT COUNT(*) FROM waves WHERE plan_id = $pid),
			(SELECT COUNT(*) FROM waves WHERE plan_id = $pid AND tasks_done = tasks_total AND tasks_total > 0)
	")
	task_total=$(echo "$metrics_data" | cut -d'|' -f1)
	task_done=$(echo "$metrics_data" | cut -d'|' -f2)
	task_validated=$(echo "$metrics_data" | cut -d'|' -f3)
	wave_total=$(echo "$metrics_data" | cut -d'|' -f4)
	wave_done=$(echo "$metrics_data" | cut -d'|' -f5)

	# Elapsed time
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

	# ─── HEADER ───
	echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}${WHITE}Piano #$pid: $pname${NC}  $status_display"
	echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
	echo ""

	# ─── DESCRIPTION (full, not truncated) ───
	local desc_to_show="${phuman_summary:-$pdescription}"
	if [ -n "$desc_to_show" ]; then
		echo -e "${BOLD}${WHITE}Scopo${NC}"
		echo "$desc_to_show" | fold -s -w 80 | while IFS= read -r line; do
			echo -e "${GRAY}│${NC}  ${WHITE}$line${NC}"
		done
		echo ""
	fi

	# ─── AT-A-GLANCE METRICS ───
	echo -e "${BOLD}${WHITE}Metriche${NC}"
	echo -e "${GRAY}├─${NC} Status: $status_display  ${GRAY}│${NC}  Project: ${BLUE}$pproject${NC}"

	# Tasks + waves
	local task_line="${BOLD}${GREEN}${task_done}${NC}/${BOLD}${WHITE}${task_total}${NC} ${GRAY}task${NC}"
	[ "$task_validated" -lt "$task_done" ] && task_line+="  ${GRAY}(${NC}${GREEN}${task_validated}${NC} ${GRAY}Thor-validated)${NC}"
	echo -e "${GRAY}├─${NC} $task_line  ${GRAY}│${NC}  ${GREEN}${wave_done}${NC}/${WHITE}${wave_total}${NC} ${GRAY}waves${NC}"

	# Duration + git lines
	local metrics_line=""
	if [ -n "$elapsed_time" ]; then
		if [ -n "$pcompleted" ]; then
			metrics_line="Duration: ${BOLD}${YELLOW}${elapsed_time}${NC}"
		else
			metrics_line="Running: ${BOLD}${YELLOW}${elapsed_time}${NC}"
		fi
	fi
	if [ "${plines_added:-0}" -gt 0 ] || [ "${plines_removed:-0}" -gt 0 ]; then
		[ -n "$metrics_line" ] && metrics_line+="  ${GRAY}│${NC}  "
		metrics_line+="${GREEN}+$(format_lines ${plines_added:-0})${NC} ${RED}-$(format_lines ${plines_removed:-0})${NC} ${GRAY}lines${NC}"
	fi
	[ -n "$metrics_line" ] && echo -e "${GRAY}├─${NC} $metrics_line"

	# Tokens
	local total_tokens tokens_formatted
	total_tokens=$(dbq "SELECT COALESCE(SUM(total_tokens), 0) FROM token_usage WHERE project_id = '$pproject'")
	tokens_formatted=$(format_tokens $total_tokens)
	echo -e "${GRAY}├─${NC} Tokens: ${CYAN}$tokens_formatted${NC} ${GRAY}(progetto)${NC}"

	# Thor validation
	if [ -n "$pvalidated" ]; then
		echo -e "${GRAY}├─${NC} Thor: ${GREEN}✓ $pvalidator${NC} ${GRAY}($pvalidated)${NC}"
	fi
	echo -e "${GRAY}└─${NC} Created: ${GRAY}$pcreated${NC}$([ -n "$pstarted" ] && echo -e "  ${GRAY}│${NC}  Started: ${GRAY}$pstarted${NC}")$([ -n "$pcompleted" ] && echo -e "  ${GRAY}│${NC}  Completed: ${GRAY}$pcompleted${NC}")"
	echo ""

	# ─── FILES & ADRs ───
	_render_plan_references "$pmarkdown" "$psource" "$pworktree" "$pparallel" "$pproject"

	# ─── PROGRESS BAR ───
	_render_plan_progress "$pid" "$task_total" "$task_done" "$task_validated" "$wave_total" "$wave_done"

	# Tree view: Waves with nested tasks
	_render_plan_waves "$pid"

	# Human action required summary
	_render_human_actions "$pid"

	# Legend
	echo ""
	echo -e "${BOLD}${WHITE}Legenda${NC}"
	echo -e "${GRAY}├─${NC} ${GREEN}✓${NC} done  ${YELLOW}⚡${NC} in progress  ${GRAY}◯${NC} pending  ${YELLOW}⏸${NC} blocked  ${CYAN}👤${NC} richiede azione tua"
	echo -e "${GRAY}├─${NC} Effort: ${RED}E3${NC}=alto  ${YELLOW}E2${NC}=medio  ${GRAY}E1${NC}=basso  ${GRAY}-- peso nella progress bar${NC}"
	echo -e "${GRAY}├─${NC} Thor: ${GREEN}T✓${NC}=validato  ${RED}T!${NC}=non validato  ${GRAY}-- solo T✓ conta come done${NC}"
	echo -e "${GRAY}└─${NC} Progress pesata: effort x validazione Thor. Task non validati non contano"

	return 0
}

# Render plan references (ADRs, files, etc)
_render_plan_references() {
	local pmarkdown="$1" psource="$2" pworktree="$3" pparallel="$4" pproject="$5"
	local has_refs=0
	if [ -n "$pmarkdown" ] || [ -n "$psource" ]; then
		has_refs=1
	fi
	# Scan plan markdown for ADR references
	local adr_list="" pmarkdown_expanded="$pmarkdown"
	[ -n "$pmarkdown_expanded" ] && pmarkdown_expanded=$(echo "$pmarkdown_expanded" | sed "s|^~|$HOME|")
	if [ -n "$pmarkdown_expanded" ] && [ -f "$pmarkdown_expanded" ]; then
		adr_list=$(grep -oE '(docs/adr/|ADR )([A-Za-z0-9_-]+)' "$pmarkdown_expanded" 2>/dev/null | sed 's/docs\/adr\///; s/ADR //' | sort -u | head -10 || true)
	fi
	[ -n "$adr_list" ] && has_refs=1

	if [ "$has_refs" -eq 1 ]; then
		echo -e "${BOLD}${WHITE}Riferimenti${NC}"
		[ -n "$pmarkdown" ] && echo -e "${GRAY}├─${NC} Piano: ${CYAN}$pmarkdown${NC}"
		[ -n "$psource" ] && echo -e "${GRAY}├─${NC} Source: ${CYAN}$psource${NC}"
		[ -n "$pworktree" ] && echo -e "${GRAY}├─${NC} Worktree: ${CYAN}$pworktree${NC}"
		[ -n "$pparallel" ] && echo -e "${GRAY}├─${NC} Mode: ${GRAY}$pparallel${NC}"
		if [ -n "$adr_list" ]; then
			echo -e "${GRAY}├─${NC} ${BOLD}${WHITE}ADR referenziate:${NC}"
			echo "$adr_list" | while IFS= read -r adr; do
				[ -z "$adr" ] && continue
				local adr_file=""
				if [ -n "$pproject" ]; then
					local proj_dir
					proj_dir=$(find ~/GitHub -maxdepth 1 -iname "$pproject" -type d 2>/dev/null | head -1)
					if [ -n "$proj_dir" ]; then
						adr_file=$(find "$proj_dir/docs/adr" -iname "${adr}*" -type f 2>/dev/null | head -1)
					fi
				fi
				if [ -n "$adr_file" ]; then
					echo -e "${GRAY}│  ├─${NC} ${CYAN}$adr${NC} ${GRAY}→ $adr_file${NC}"
				else
					echo -e "${GRAY}│  ├─${NC} ${CYAN}$adr${NC}"
				fi
			done
		fi
		echo -e "${GRAY}└─${NC}"
		echo ""
	fi
}

# Render plan progress bar
_render_plan_progress() {
	local pid="$1" task_total="$2" task_done="$3" task_validated="$4" wave_total="$5" wave_done="$6"
	local wp_data wp_done wp_total task_progress
	wp_data=$(calc_weighted_progress "plan_id = $pid")
	wp_done=$(echo "$wp_data" | cut -d'|' -f1)
	wp_total=$(echo "$wp_data" | cut -d'|' -f2)
	if [ "$wp_total" -gt 0 ]; then
		task_progress=$((wp_done * 100 / wp_total))
	else
		task_progress=0
	fi
	local bar
	bar=$(render_bar "$task_progress" 30)

	local wave_progress
	if [ "$wave_total" -gt 0 ]; then
		wave_progress=$((wave_done * 100 / wave_total))
	else
		wave_progress=0
	fi

	local unvalidated=$((task_done - task_validated))

	echo -e "${BOLD}${WHITE}Progress${NC} ${GRAY}(Thor-gated: solo task validati contano)${NC}"
	echo -e "${GRAY}├─${NC} $bar ${WHITE}${task_progress}%${NC} ${GRAY}(weighted by effort)${NC}"
	echo -e "${GRAY}├─${NC} Executor: ${GREEN}${task_done}${NC}/${WHITE}${task_total}${NC} done  ${GRAY}│${NC}  Thor: ${GREEN}${task_validated}${NC}/${WHITE}${task_done}${NC} validated"
	if [ "$unvalidated" -gt 0 ]; then
		echo -e "${GRAY}│  ${NC}${YELLOW}${unvalidated} task done ma non validati da Thor${NC}"
	fi
	echo -e "${GRAY}└─${NC} Waves: ${GREEN}${wave_done}${NC}/${WHITE}${wave_total}${NC} complete ${GRAY}(${wave_progress}%)${NC}"
	echo ""
}

# Main dashboard rendering function
render_dashboard() {
	# Single plan mode
	if [ -n "$PLAN_ID" ]; then
		_render_single_plan
		return $?
	fi

	# Multi-plan overview mode
	_render_dashboard_overview
}
