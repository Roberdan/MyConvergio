#!/bin/bash
# Active plans rendering — grid layout
# Version: 3.0.0

_render_active_plans() {
	local active_count
	active_count=$(dbq "SELECT COUNT(*) FROM plans WHERE status IN ('doing','in_progress')")

	_grid_section "ACTIVE MISSIONS" "${active_count} plan(s) running"

	if [[ "$active_count" -eq 0 ]]; then
		_grid_box_start
		_grid_row "${TH_MUTED}No active plans${TH_RST}"
		_grid_box_end
		return
	fi

	dbq "
		SELECT p.id, p.name, p.status, p.updated_at, p.started_at, p.created_at, p.project_id,
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND status NOT IN ('cancelled')),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND tasks_done=tasks_total AND tasks_total>0),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND status='in_progress'),
			(SELECT COUNT(*) FROM tasks WHERE plan_id=p.id AND status NOT IN ('cancelled', 'skipped')),
			(SELECT COUNT(*) FROM tasks WHERE plan_id=p.id AND status='done'),
			COALESCE((SELECT SUM(input_tokens + output_tokens) FROM token_usage WHERE project_id=p.project_id), 0),
			COALESCE(p.execution_host, ''),
			COALESCE(p.human_summary, REPLACE(REPLACE(COALESCE(p.description, ''), char(10), ' '), char(13), '')),
			COALESCE((SELECT id FROM waves WHERE plan_id=p.id AND status='in_progress' ORDER BY position LIMIT 1), ''),
			COALESCE((SELECT wave_id FROM waves WHERE plan_id=p.id AND status='in_progress' ORDER BY position LIMIT 1), '')
		FROM plans p WHERE p.status IN ('doing', 'in_progress') ORDER BY p.id
	" | while IFS='|' read -r pid pname pstatus pupdated pstarted pcreated pproject wave_total wave_done wave_doing task_total task_done total_tokens exec_host pdescription active_wave_id active_wave_name; do
		[ -z "$pid" ] && continue

		# --- Elapsed time ---
		if [ -n "$pstarted" ]; then
			start_ts=$(date_to_epoch "$pstarted")
		else
			start_ts=$(date_to_epoch "$pcreated")
		fi
		elapsed_time=$(format_elapsed $(($(date +%s) - start_ts)))

		# --- Tokens ---
		tokens_formatted=$(format_tokens "$total_tokens")

		# --- Weighted progress ---
		local wp_data wp_done_w wp_total_w task_progress
		wp_data=$(calc_weighted_progress "plan_id = $pid")
		wp_done_w=$(echo "$wp_data" | cut -d'|' -f1)
		wp_total_w=$(echo "$wp_data" | cut -d'|' -f2)
		if [ "${wp_total_w:-0}" -gt 0 ]; then
			task_progress=$((wp_done_w * 100 / wp_total_w))
		else
			task_progress=0
		fi

		# --- Wave progress ---
		local wave_progress=0
		[ "${wave_total:-0}" -gt 0 ] && wave_progress=$((wave_done * 100 / wave_total))

		# --- Last-update age ---
		local time_info=""
		if [ -n "$pupdated" ]; then
			local update_date days_ago
			update_date=$(echo "$pupdated" | cut -d' ' -f1)
			days_ago=$((($(date +%s) - $(date_only_to_epoch "$update_date")) / 86400))
			if [ "$days_ago" -eq 0 ]; then
				time_info="${TH_SUCCESS}oggi${TH_RST}"
			elif [ "$days_ago" -eq 1 ]; then
				time_info="${TH_WARNING}ieri${TH_RST}"
			elif [ "$days_ago" -gt 7 ]; then
				time_info="${TH_ERROR}${days_ago}g fa${TH_RST}"
			else
				time_info="${TH_MUTED}${days_ago}g fa${TH_RST}"
			fi
		fi

		# --- Project + name display ---
		local proj_label=""
		[ -n "$pproject" ] && proj_label="${TH_INFO}[${pproject}]${TH_RST} "
		local short_name
		short_name=$(echo "$pname" | cut -c1-50)
		[ "${#pname}" -gt 50 ] && short_name="${short_name}..."

		# --- Host badge ---
		local local_host host_badge
		local_host="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
		local_host="${local_host%.local}"
		local is_remote=0
		if [ -n "$exec_host" ] && [ "$exec_host" != "$local_host" ]; then
			is_remote=1
			if [ "${REMOTE_ONLINE:-0}" -eq 1 ]; then
				host_badge="${TH_SUCCESS}LNX${TH_RST}"
			else
				host_badge="${TH_ERROR}LNX${TH_RST} ${TH_MUTED}(offline)${TH_RST}"
			fi
		else
			host_badge="${TH_SUCCESS}MAC${TH_RST}"
		fi

		# --- Git branch / worktree ---
		local branch_line=""
		if [ -n "$pproject" ]; then
			local project_dir="$HOME/GitHub/$pproject"
			if [ -d "$project_dir/.git" ] || [ -f "$project_dir/.git" ]; then
				local cur_branch
				cur_branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
				if [ -n "$cur_branch" ]; then
					if [ -f "$project_dir/.git" ]; then
						branch_line="${TH_INFO}⎇ ${cur_branch}${TH_RST} ${TH_MUTED}(worktree)${TH_RST}"
					else
						branch_line="${TH_INFO}⎇ ${cur_branch}${TH_RST}"
					fi
				fi
			fi
		fi

		# --- PR status (inline summary for metrics line) ---
		local pr_col=""
		local pr_count
		pr_count=$(dbq "SELECT COUNT(*) FROM waves WHERE plan_id=$pid AND pr_number IS NOT NULL AND pr_number > 0")
		if [ "${pr_count:-0}" -gt 0 ]; then
			pr_col="${TH_INFO}PRs:${pr_count}${TH_RST}"
		fi

		# === Box per plan ===
		local box_label
		box_label="${TH_WARNING}#${pid}${TH_RST}  ${proj_label}${TH_RST}${short_name}  ${host_badge}"
		_grid_box_start "$box_label"

		# Time info row
		if [ -n "$time_info" ]; then
			_grid_row "${TH_MUTED}Updated: ${TH_RST}${time_info}"
		fi

		# Description (if present)
		if [ -n "$pdescription" ]; then
			local short_desc
			short_desc=$(truncate_desc "$pdescription")
			[ -n "$short_desc" ] && _grid_row "${TH_MUTED}${short_desc}${TH_RST}"
		fi

		# Branch line
		[ -n "$branch_line" ] && _grid_row "$branch_line"

		# Remote git status
		if [ "$is_remote" -eq 1 ] && [ "${REMOTE_ONLINE:-0}" -eq 1 ] && [ -f "${REMOTE_GIT_CACHE:-}" ]; then
			local r_ahead r_behind r_clean r_branch r_git_line
			r_ahead=$(_get_remote_git "$pproject" "ahead")
			r_behind=$(_get_remote_git "$pproject" "behind")
			r_clean=$(_get_remote_git "$pproject" "clean")
			r_branch=$(_get_remote_git "$pproject" "branch")
			if [ -n "$r_branch" ]; then
				r_git_line="${TH_MUTED}git:${TH_RST} ${TH_INFO}${r_branch}${TH_RST}"
				[ "${r_ahead:-0}" -gt 0 ] && r_git_line+=" ${TH_WARNING}↑${r_ahead}${TH_RST}"
				[ "${r_behind:-0}" -gt 0 ] && r_git_line+=" ${TH_ERROR}↓${r_behind}${TH_RST}"
				if [ "$r_clean" = "false" ]; then
					r_git_line+=" ${TH_ERROR}dirty${TH_RST}"
				elif [ "${r_ahead:-0}" -eq 0 ] && [ "${r_behind:-0}" -eq 0 ]; then
					r_git_line+=" ${TH_SUCCESS}clean${TH_RST}"
				fi
				_grid_row "$r_git_line"
			fi
		fi

		# Progress bar
		local progress_label
		progress_label="${TH_MUTED}(${task_done}/${task_total} tasks)${TH_RST}"
		_grid_row "$(_grid_progress_bar "$task_progress" 24 "$progress_label")"

		# Wave status row
		local wave_active_label=""
		[ -n "$active_wave_name" ] && wave_active_label=" ${TH_WARNING}⚡${active_wave_name}${TH_RST}"
		_grid_row "Waves: ${TH_SUCCESS}${wave_done}${TH_RST}/${wave_total} done${wave_active_label}  ${TH_MUTED}(${wave_progress}%)${TH_RST}"

		# Metrics: runtime + tokens + PR
		local metrics_line
		metrics_line="${TH_MUTED}Runtime:${TH_RST} ${TH_INFO}${elapsed_time}${TH_RST}  ${TH_MUTED}Tokens:${TH_RST} ${TH_INFO}${tokens_formatted}${TH_RST}"
		[ -n "$pr_col" ] && metrics_line+="  ${pr_col}"
		_grid_row "$metrics_line"

		# Verbose: non-done wave names
		if [ "${VERBOSE:-0}" -eq 1 ]; then
			dbq "SELECT wave_id, name, status FROM waves WHERE plan_id = $pid AND status != 'done' ORDER BY position LIMIT 3" |
				while IFS='|' read -r wid wname wstatus; do
					local icon
					case "$wstatus" in
					in_progress) icon="${TH_WARNING}⚡${TH_RST}" ;;
					blocked) icon="${TH_ERROR}⏸${TH_RST}" ;;
					*) icon="${TH_MUTED}◯${TH_RST}" ;;
					esac
					local swn
					swn=$(echo "$wname" | cut -c1-50)
					[ "${#wname}" -gt 50 ] && swn="${swn}..."
					_grid_row "  $icon ${TH_INFO}${wid}${TH_RST} ${TH_MUTED}${swn}${TH_RST}"
				done
		fi

		# Active tasks
		local running_tasks
		running_tasks=$(dbq "SELECT t.task_id, REPLACE(REPLACE(t.title, char(10), ' '), char(13), ''), w.wave_id FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE t.plan_id = $pid AND t.status = 'in_progress' ORDER BY t.id" 2>/dev/null)
		if [ -n "$running_tasks" ]; then
			_grid_row "${TH_WARNING}Active tasks:${TH_RST}"
			while IFS='|' read -r tid ttitle twid; do
				local stt
				stt=$(echo "$ttitle" | cut -c1-55)
				[ "${#ttitle}" -gt 55 ] && stt="${stt}..."
				_grid_row "  ${TH_WARNING}▶${TH_RST} ${TH_INFO}${tid}${TH_RST} ${stt} ${TH_MUTED}[${twid}]${TH_RST}"
			done <<<"$running_tasks"
		fi

		_grid_box_end

		# PR detail block (below box — uses legacy tree-style output from _render_plan_prs)
		_render_plan_prs "$pid" "$pproject"

	done
}
