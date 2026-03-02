#!/bin/bash
# Completed plans rendering — grid layout
# Version: 3.0.0

_render_completed_plans() {
	local completed_week_count
	completed_week_count=$(dbq "SELECT COUNT(*) FROM plans WHERE status = 'done' AND datetime(COALESCE(completed_at, updated_at, created_at)) >= datetime('now', '-1 day')")

	_grid_section "COMPLETED (24h)" "${completed_week_count} plans done"

	if [ "$completed_week_count" -eq 0 ]; then
		_grid_box_start
		_grid_row "${TH_MUTED}No plans completed in the last 24 hours${TH_RST}"
		_grid_box_end
		return
	fi

	# Decide row limit: full list view (C key) shows all, main view shows last 7
	local row_limit=7
	[[ "${EXPAND_COMPLETED:-0}" -eq 1 ]] && row_limit=999

	_grid_box_start

	# Table header
	local hdr
	hdr=$(printf "${TH_ACCENT}${BOLD}%-6s %-12s %-26s %-10s %-12s %-10s %s${TH_RST}" \
		"" "PROJECT" "NAME" "TASKS" "GIT" "TIME" "THOR")
	_grid_row "$hdr"

	local sep_line
	sep_line=$(_grid_repeat "${TH_INNER_H}" $((GRID_W - 4)))
	printf "${TH_PRIMARY}${TH_INNER_V}${TH_RST} ${TH_MUTED}%s${TH_RST} ${TH_PRIMARY}${TH_INNER_V}${TH_RST}\n" \
		"${sep_line:0:$((GRID_W - 4))}"

	local row_num=0
	dbq "SELECT id, name, updated_at, validated_at, validated_by, completed_at, started_at, created_at,
		project_id,
		COALESCE(human_summary, REPLACE(REPLACE(COALESCE(description, ''), char(10), ' '), char(13), '')),
		COALESCE(lines_added, 0), COALESCE(lines_removed, 0)
		FROM plans
		WHERE status = 'done'
		  AND datetime(COALESCE(completed_at, updated_at, created_at)) >= datetime('now', '-1 day')
		ORDER BY COALESCE(completed_at, updated_at, created_at) DESC
		LIMIT $row_limit
	" | while IFS='|' read -r plan_id name updated validated_at validated_by completed started created \
		done_project pdescription lines_added lines_removed; do
		[ -z "$plan_id" ] && continue

		# Elapsed time
		local elapsed_seconds=0
		if [ -n "$completed" ] && [ -n "$started" ]; then
			elapsed_seconds=$(($(date_to_epoch "$completed") - $(date_to_epoch "$started")))
		elif [ -n "$completed" ] && [ -n "$created" ]; then
			elapsed_seconds=$(($(date_to_epoch "$completed") - $(date_to_epoch "$created")))
		fi
		local elapsed_time
		elapsed_time=$(format_elapsed "$elapsed_seconds")

		# Thor validation
		local thor_col
		if [ -n "$validated_at" ] && [ -n "$validated_by" ]; then
			thor_col="${TH_SUCCESS}PASS${TH_RST}"
		else
			thor_col="${TH_MUTED}none${TH_RST}"
		fi

		# Task counts (done/total)
		local task_done_count task_total_count
		task_done_count=$(dbq "SELECT COUNT(*) FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id=$plan_id AND status!='cancelled')")
		task_total_count=$(dbq "SELECT COUNT(*) FROM tasks WHERE status NOT IN ('cancelled','skipped') AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id=$plan_id AND status!='cancelled')")

		# Git stats
		local git_col=""
		if [ "${lines_added:-0}" -gt 0 ] || [ "${lines_removed:-0}" -gt 0 ]; then
			git_col="${TH_SUCCESS}+$(format_lines "${lines_added:-0}")${TH_RST}${TH_ERROR}-$(format_lines "${lines_removed:-0}")${TH_RST}"
		else
			git_col="${TH_MUTED}—${TH_RST}"
		fi

		# Plan icon: check if truly done (PRs merged, no stale worktree)
		local has_unmerged
		has_unmerged=$(dbq "SELECT COUNT(*) FROM waves WHERE plan_id=$plan_id AND pr_number IS NOT NULL AND pr_number>0 AND status NOT IN ('done','cancelled')")
		local plan_icon
		if [ "${has_unmerged:-0}" -gt 0 ]; then
			plan_icon="${TH_WARNING}⚠${TH_RST}"
		else
			plan_icon="${TH_SUCCESS}✓${TH_RST}"
		fi

		# Completion time (HH:MM from completed_at)
		local comp_time="${completed:-${updated:-$created}}"
		local comp_hm
		comp_hm=$(echo "$comp_time" | cut -d' ' -f2 | cut -c1-5)

		# Truncate columns
		local proj_col name_col task_col time_col
		proj_col=$(echo "${done_project:-—}" | cut -c1-12)
		name_col=$(echo "$name" | cut -c1-26)
		[ ${#name} -gt 26 ] && name_col="${name_col:0:25}…"
		task_col="${task_done_count}/${task_total_count}"
		time_col="${elapsed_time} ${TH_MUTED}${comp_hm}${TH_RST}"

		local row_content
		row_content=$(printf "%s ${TH_INFO}%-12s${TH_RST} %-26s %-10s %-12s %-10s %s" \
			"$plan_icon" "$proj_col" "$name_col" "$task_col" "$git_col" "$time_col" "$thor_col")
		_grid_row "$row_content"
	done

	_grid_box_end

	# Footer hint when not in expanded view
	if [[ "${EXPAND_COMPLETED:-0}" -eq 0 ]] && [[ "$completed_week_count" -gt 7 ]]; then
		printf " ${TH_MUTED}Showing last 7 of %d — press C for full list${TH_RST}\n" "$completed_week_count"
	fi
}
