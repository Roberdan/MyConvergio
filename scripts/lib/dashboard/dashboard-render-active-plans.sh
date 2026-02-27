#!/bin/bash
# Active plans rendering
# Version: 2.0.0

_render_active_plans() {
	echo -e "${BOLD}${WHITE}🚀 Piani Attivi${NC}"
	dbq "
		SELECT p.id, p.name, p.status, p.updated_at, p.started_at, p.created_at, p.project_id,
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND tasks_done=tasks_total AND tasks_total>0),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND status='in_progress'),
			(SELECT COUNT(*) FROM tasks WHERE plan_id=p.id),
			(SELECT COUNT(*) FROM tasks WHERE plan_id=p.id AND status='done'),
			COALESCE((SELECT SUM(total_tokens) FROM token_usage WHERE project_id=p.project_id), 0),
			COALESCE(p.execution_host, ''),
			COALESCE(p.human_summary, REPLACE(REPLACE(COALESCE(p.description, ''), char(10), ' '), char(13), '')),
			COALESCE((SELECT id FROM waves WHERE plan_id=p.id AND status='in_progress' ORDER BY position LIMIT 1), ''),
			COALESCE((SELECT wave_id FROM waves WHERE plan_id=p.id AND status='in_progress' ORDER BY position LIMIT 1), '')
		FROM plans p WHERE p.status IN ('doing', 'in_progress') ORDER BY p.id
	" | while IFS='|' read -r pid pname pstatus pupdated pstarted pcreated pproject wave_total wave_done wave_doing task_total task_done total_tokens exec_host pdescription active_wave_id active_wave_name; do
		[ -z "$pid" ] && continue

		# Elapsed time (running time)
		if [ -n "$pstarted" ]; then
			start_ts=$(date_to_epoch "$pstarted")
		else
			start_ts=$(date_to_epoch "$pcreated")
		fi
		now_ts=$(date +%s)
		elapsed_seconds=$((now_ts - start_ts))
		elapsed_time=$(format_elapsed $elapsed_seconds)

		tokens_formatted=$(format_tokens $total_tokens)

		# Weighted task progress (model-based complexity)
		local wp_data wp_done_w wp_total_w
		wp_data=$(calc_weighted_progress "plan_id = $pid")
		wp_done_w=$(echo "$wp_data" | cut -d'|' -f1)
		wp_total_w=$(echo "$wp_data" | cut -d'|' -f2)
		if [ "$wp_total_w" -gt 0 ]; then
			task_progress=$((wp_done_w * 100 / wp_total_w))
		else
			task_progress=0
		fi
		bar=$(render_bar "$task_progress" 20)

		# Wave progress
		if [ "$wave_total" -gt 0 ]; then
			wave_progress=$((wave_done * 100 / wave_total))
		else
			wave_progress=0
		fi

		# Time since last update
		if [ -n "$pupdated" ]; then
			update_date=$(echo "$pupdated" | cut -d' ' -f1)
			days_ago=$((($(date +%s) - $(date_only_to_epoch "$update_date")) / 86400))
			if [ "$days_ago" -eq 0 ]; then
				time_info="${GREEN}oggi${NC}"
			elif [ "$days_ago" -eq 1 ]; then
				time_info="${YELLOW}ieri${NC}"
			elif [ "$days_ago" -gt 7 ]; then
				time_info="${RED}${days_ago}g fa${NC}"
			else
				time_info="${GRAY}${days_ago}g fa${NC}"
			fi
		else
			time_info=""
		fi

		# Truncate long names
		short_name=$(echo "$pname" | cut -c1-50)
		if [ ${#pname} -gt 50 ]; then
			short_name="${short_name}..."
		fi

		# Project display
		project_display=""
		[ -n "$pproject" ] && project_display="${BLUE}[$pproject]${NC} "

		# Git branch/worktree detection
		branch_display=""
		if [ -n "$pproject" ]; then
			project_dir="$HOME/GitHub/$pproject"
			if [ -d "$project_dir/.git" ] || [ -f "$project_dir/.git" ]; then
				current_branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
				if [ -n "$current_branch" ]; then
					# Check if it's a worktree
					if [ -f "$project_dir/.git" ]; then
						branch_display="${CYAN}⎇ ${current_branch}${NC} ${GRAY}(worktree)${NC}"
					else
						branch_display="${CYAN}⎇ ${current_branch}${NC}"
					fi
				fi
			fi
		fi

		# Host tag: LINUX for remote (green if synced, red+OFFLINE if not), MAC for local
		local_host="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
		local_host="${local_host%.local}"
		host_tag=""
		is_remote=0
		if [ -n "$exec_host" ] && [ "$exec_host" != "$local_host" ]; then
			is_remote=1
			if [ "$REMOTE_ONLINE" -eq 1 ]; then
				host_tag=" ${GREEN}LINUX${NC}"
			else
				host_tag=" ${RED}LINUX${NC} ${GRAY}(offline)${NC}"
			fi
		else
			host_tag=" ${GREEN}MAC${NC}"
		fi

		echo -e "${GRAY}├─${NC} ${YELLOW}[#$pid]${NC} ${project_display}${WHITE}$short_name${NC}${host_tag} $([ -n "$time_info" ] && echo -e "${GRAY}(${time_info}${GRAY})${NC}")"
		[ -n "$pdescription" ] && echo -e "${GRAY}│  ${NC}${GRAY}$(truncate_desc "$pdescription")${NC}"
		[ -n "$branch_display" ] && echo -e "${GRAY}│  ├─${NC} $branch_display"
		# Remote git status inline (only for LINUX plans when online)
		if [ "$is_remote" -eq 1 ] && [ "$REMOTE_ONLINE" -eq 1 ] && [ -f "$REMOTE_GIT_CACHE" ]; then
			local r_ahead r_behind r_clean r_branch r_git_line
			r_ahead=$(_get_remote_git "$pproject" "ahead")
			r_behind=$(_get_remote_git "$pproject" "behind")
			r_clean=$(_get_remote_git "$pproject" "clean")
			r_branch=$(_get_remote_git "$pproject" "branch")
			r_git_line=""
			if [ -n "$r_branch" ]; then
				r_git_line="${GRAY}git:${NC} ${CYAN}${r_branch}${NC}"
				if [ "${r_ahead:-0}" -gt 0 ]; then
					r_git_line+=" ${YELLOW}↑${r_ahead} unpushed${NC}"
				fi
				if [ "${r_behind:-0}" -gt 0 ]; then
					r_git_line+=" ${RED}↓${r_behind} behind${NC}"
				fi
				if [ "$r_clean" = "false" ]; then
					r_git_line+=" ${RED}dirty${NC}"
				elif [ "${r_ahead:-0}" -eq 0 ] && [ "${r_behind:-0}" -eq 0 ]; then
					r_git_line+=" ${GREEN}clean${NC}"
				fi
				echo -e "${GRAY}│  ├─${NC} ${r_git_line}"
			fi
		fi
		echo -e "${GRAY}│  ├─${NC} Progress: $bar ${WHITE}${task_progress}%${NC} ${GRAY}(${task_done}/${task_total} tasks)${NC}"
		echo -e "${GRAY}│  ├─${NC} Waves: ${GREEN}${wave_done}${NC}/${WHITE}${wave_total}${NC} complete ${GRAY}(${wave_progress}%)${NC}"
		echo -e "${GRAY}│  └─${NC} Runtime: ${CYAN}${elapsed_time}${NC} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"

		# Verbose: show wave names
		if [ "$VERBOSE" -eq 1 ]; then
			dbq "SELECT wave_id, name, status FROM waves WHERE plan_id = $pid AND status != 'done' ORDER BY position LIMIT 3" | while IFS='|' read -r wid wname wstatus; do
				case $wstatus in
				in_progress) icon="${YELLOW}⚡${NC}" ;;
				blocked) icon="${YELLOW}⏸${NC}" ;;
				*) icon="${GRAY}◯${NC}" ;;
				esac
				short_wname=$(echo "$wname" | cut -c1-45)
				[ ${#wname} -gt 45 ] && short_wname="${short_wname}..."
				echo -e "${GRAY}│     └─${NC} $icon ${CYAN}$wid${NC} ${GRAY}$short_wname${NC}"
			done
		fi

		# Tasks della wave attiva (in_progress + pending) — active_wave_id/name from main query
		if [ -n "$active_wave_id" ]; then
			running_tasks=$(dbq "SELECT t.task_id, REPLACE(REPLACE(t.title, char(10), ' '), char(13), ''), t.status FROM tasks t WHERE t.wave_id_fk = $active_wave_id AND t.status IN ('in_progress', 'pending') ORDER BY CASE t.status WHEN 'in_progress' THEN 0 ELSE 1 END, t.id" 2>/dev/null)
			if [ -n "$running_tasks" ]; then
				echo -e "${GRAY}│  ${NC}${YELLOW}⚡ Wave ${active_wave_name:-?}:${NC}"
				echo "$running_tasks" | while IFS='|' read -r tid ttitle tstatus; do
					short_ttitle=$(echo "$ttitle" | cut -c1-48)
					[ ${#ttitle} -gt 48 ] && short_ttitle="${short_ttitle}..."
					if [ "$tstatus" = "in_progress" ]; then
						icon="${YELLOW}▶${NC}"
					else
						icon="${GRAY}◯${NC}"
					fi
					echo -e "${GRAY}│  ├─${NC} $icon ${CYAN}$tid${NC} ${WHITE}$short_ttitle${NC}"
				done
			fi
		fi

		# PR rendering from waves DB
		_render_plan_prs "$pid" "$pproject"

		echo ""
	done

	# Piani in Pipeline (todo - non ancora lanciati)
}
