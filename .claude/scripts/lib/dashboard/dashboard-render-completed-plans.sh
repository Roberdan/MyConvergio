#!/bin/bash
# Completed plans rendering
# Version: 1.6.0

_render_completed_plans() {
	local completed_week_count
	completed_week_count=$(dbq "SELECT COUNT(*) FROM plans WHERE status = 'done' AND datetime(COALESCE(completed_at, updated_at, created_at)) >= datetime('now', '-1 day')")
	echo -e "${BOLD}${WHITE}✅ Completati ultime 24h ($completed_week_count)${NC}"
	if [ "$completed_week_count" -eq 0 ]; then
		echo -e "${GRAY}└─${NC} Nessun piano completato nelle ultime 24 ore"
	fi
	if [ "$EXPAND_COMPLETED" -eq 0 ] && [ "$completed_week_count" -gt 0 ]; then
		echo -e "${GRAY}│  ${NC}${GRAY}Usa ${WHITE}piani -e${GRAY} per vedere dettagli task${NC}"
	fi

	dbq "SELECT id, name, updated_at, validated_at, validated_by, completed_at, started_at, created_at, project_id, COALESCE(human_summary, REPLACE(REPLACE(COALESCE(description, ''), char(10), ' '), char(13), '')), COALESCE(lines_added, 0), COALESCE(lines_removed, 0), COALESCE(worktree_path, '') FROM plans WHERE status = 'done' AND datetime(COALESCE(completed_at, updated_at, created_at)) >= datetime('now', '-1 day') ORDER BY COALESCE(completed_at, updated_at, created_at) DESC" | while IFS='|' read -r plan_id name updated validated_at validated_by completed started created done_project pdescription lines_added lines_removed worktree_path; do
		[ -z "$plan_id" ] && continue
		# Use completed_at or updated_at for display
		display_date="${completed:-${updated:-$created}}"
		date=$(echo "$display_date" | cut -d' ' -f1)
		short_name=$(echo "$name" | cut -c1-50)
		if [ ${#name} -gt 50 ]; then
			short_name="${short_name}..."
		fi

		# Elapsed time (total execution time)
		if [ -n "$completed" ] && [ -n "$started" ]; then
			start_ts=$(date_to_epoch "$started")
			end_ts=$(date_to_epoch "$completed")
			elapsed_seconds=$((end_ts - start_ts))
		elif [ -n "$completed" ] && [ -n "$created" ]; then
			start_ts=$(date_to_epoch "$created")
			end_ts=$(date_to_epoch "$completed")
			elapsed_seconds=$((end_ts - start_ts))
		else
			elapsed_seconds=0
		fi
		elapsed_time=$(format_elapsed $elapsed_seconds)

		# Token usage (usa project_id perché plan_id è sempre NULL nel DB)
		total_tokens=$(dbq "SELECT COALESCE(SUM(total_tokens), 0) FROM token_usage WHERE project_id = '$done_project'")
		tokens_formatted=$(format_tokens $total_tokens)

		# Thor validation status
		if [ -n "$validated_at" ] && [ -n "$validated_by" ]; then
			thor_status="${GREEN}✓ Thor${NC}"
		else
			thor_status="${GRAY}⊘ No Thor${NC}"
		fi

		# Count tasks (done/total)
		task_done_count=$(dbq "SELECT COUNT(*) FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $plan_id)")
		task_total_count=$(dbq "SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $plan_id)")

		# Project display for completed plans
		done_project_display=""
		[ -n "$done_project" ] && done_project_display="${BLUE}[$done_project]${NC} "

		# Git stats display
		local git_stats_display=""
		if [ "${lines_added:-0}" -gt 0 ] || [ "${lines_removed:-0}" -gt 0 ]; then
			git_stats_display=" ${GRAY}│${NC} ${GREEN}+$(format_lines ${lines_added:-0})${NC} ${RED}-$(format_lines ${lines_removed:-0})${NC}"
		fi

		# PR detection with live GitHub state
		local pr_display="" pr_merged=0 pr_num=""
		local has_wave_prs
		has_wave_prs=$(dbq "SELECT COUNT(*) FROM waves WHERE plan_id = $plan_id AND pr_number IS NOT NULL AND pr_number > 0")
		if [ "${has_wave_prs:-0}" -gt 0 ]; then
			pr_display=$(_render_completed_plan_prs "$plan_id")
			# Check if any wave PR is not merged (for truly_done assessment)
			local unmerged_wave_prs
			unmerged_wave_prs=$(dbq "SELECT COUNT(*) FROM waves WHERE plan_id = $plan_id AND pr_number IS NOT NULL AND pr_number > 0 AND status NOT IN ('done', 'cancelled')")
			[ "${unmerged_wave_prs:-0}" -gt 0 ] && pr_merged=0 || pr_merged=1
			pr_num=$(dbq "SELECT pr_number FROM waves WHERE plan_id = $plan_id AND pr_number IS NOT NULL AND pr_number > 0 LIMIT 1")
		else
			pr_display="${GRAY}no PR${NC}"
		fi

		# Worktree check
		local worktree_exists=0 worktree_display=""
		if [ -n "$worktree_path" ]; then
			local wt_expanded
			wt_expanded=$(echo "$worktree_path" | sed "s|^~|$HOME|")
			if [ -d "$wt_expanded" ]; then
				worktree_exists=1
				worktree_display="${RED}WT: esiste${NC}"
			else
				worktree_display="${GREEN}WT: pulito${NC}"
			fi
		fi

		# Plan conclusion assessment
		local truly_done=1
		if [ -n "$pr_num" ] && [ "$pr_merged" -eq 0 ]; then
			truly_done=0
		fi
		if [ "$worktree_exists" -eq 1 ]; then
			truly_done=0
		fi
		local plan_icon="${GREEN}✓${NC}"
		[ "$truly_done" -eq 0 ] && plan_icon="${YELLOW}⚠${NC}"

		# Build closure status line
		local closure_line=""
		if [ -n "$pr_display" ]; then
			closure_line+="$pr_display"
		fi
		if [ -n "$worktree_display" ]; then
			[ -n "$closure_line" ] && closure_line+=" ${GRAY}│${NC} "
			closure_line+="$worktree_display"
		fi

		# Compact view: single line with count
		if [ "$EXPAND_COMPLETED" -eq 0 ]; then
			echo -e "${GRAY}├─${NC} $plan_icon ${YELLOW}[#$plan_id]${NC} ${done_project_display}${WHITE}$short_name${NC} ${GRAY}($date)${NC} $thor_status"
			[ -n "$pdescription" ] && echo -e "${GRAY}│  ${NC}${GRAY}$(truncate_desc "$pdescription")${NC}"
			if [ -n "$closure_line" ]; then
				echo -e "${GRAY}│  ├─${NC} ${BOLD}${GREEN}${task_done_count}${NC}/${BOLD}${WHITE}${task_total_count}${NC} ${GRAY}task${NC} ${GRAY}│${NC} ${BOLD}${YELLOW}${elapsed_time}${NC}${git_stats_display} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"
				echo -e "${GRAY}│  └─${NC} $closure_line"
			else
				echo -e "${GRAY}│  └─${NC} ${BOLD}${GREEN}${task_done_count}${NC}/${BOLD}${WHITE}${task_total_count}${NC} ${GRAY}task${NC} ${GRAY}│${NC} ${BOLD}${YELLOW}${elapsed_time}${NC}${git_stats_display} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"
			fi
		else
			# Expanded view: with task list
			echo -e "${GRAY}├─${NC} $plan_icon ${YELLOW}[#$plan_id]${NC} ${done_project_display}${WHITE}$short_name${NC} ${GRAY}($date)${NC} $thor_status"
			[ -n "$pdescription" ] && echo -e "${GRAY}│  ${NC}${GRAY}$(truncate_desc "$pdescription")${NC}"
			echo -e "${GRAY}│  ├─${NC} ${BOLD}${GREEN}${task_done_count}${NC}/${BOLD}${WHITE}${task_total_count}${NC} ${GRAY}task${NC} ${GRAY}│${NC} ${BOLD}${YELLOW}${elapsed_time}${NC}${git_stats_display} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"

			local has_closure=0
			[ -n "$closure_line" ] && has_closure=1

			if [ "$task_done_count" -gt 0 ]; then
				if [ "$has_closure" -eq 1 ]; then
					echo -e "${GRAY}│  ├─${NC} ${GRAY}Task completati:${NC}"
				else
					echo -e "${GRAY}│  └─${NC} ${GRAY}Task completati:${NC}"
				fi
				# Show all completed tasks (limit to first 10 for readability)
				dbq "SELECT task_id, REPLACE(REPLACE(title, char(10), ' '), char(13), '') FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $plan_id) ORDER BY task_id LIMIT 10" | while IFS='|' read -r tid title; do
					short_title=$(echo "$title" | cut -c1-55)
					if [ ${#title} -gt 55 ]; then
						short_title="${short_title}..."
					fi
					echo -e "${GRAY}│     • ${NC}${CYAN}$tid${NC} ${GRAY}$short_title${NC}"
				done

				# Show count if more than 10
				if [ "$task_done_count" -gt 10 ]; then
					remaining=$((task_done_count - 10))
					echo -e "${GRAY}│     ${NC}${GRAY}... e altri $remaining task${NC}"
				fi
			fi
			if [ "$has_closure" -eq 1 ]; then
				echo -e "${GRAY}│  └─${NC} $closure_line"
			fi
			echo ""
		fi
	done
	echo -e "${GRAY}└─${NC}"
}
