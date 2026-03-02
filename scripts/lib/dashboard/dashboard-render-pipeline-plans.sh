#!/bin/bash
# Pipeline plans rendering — grid layout
# Version: 3.0.0

_render_pipeline_plans() {
	local pipeline_count
	pipeline_count=$(dbq "SELECT COUNT(*) FROM plans WHERE status='todo'")

	_grid_section "PIPELINE" "${pipeline_count} plans queued"

	if [[ "$pipeline_count" -eq 0 ]]; then
		_grid_box_start
		_grid_row "${TH_MUTED}No plans in pipeline${TH_RST}"
		_grid_box_end
		return
	fi

	_grid_box_start

	# Table header row
	local hdr
	hdr=$(printf "${TH_ACCENT}${BOLD}%-5s %-12s %-26s %-8s %-14s %s${TH_RST}" \
		"ID" "PROJECT" "NAME" "AGE" "WAVES/TASKS" "SUMMARY")
	_grid_row "$hdr"

	# Separator under header
	local sep_line
	sep_line=$(_grid_repeat "${TH_INNER_H}" $((GRID_W - 4)))
	printf "${TH_PRIMARY}${TH_INNER_V}${TH_RST} ${TH_MUTED}%s${TH_RST} ${TH_PRIMARY}${TH_INNER_V}${TH_RST}\n" \
		"${sep_line:0:$((GRID_W - 4))}"

	dbq "
		SELECT p.id, p.name, p.created_at, p.project_id,
			COALESCE(p.human_summary, REPLACE(REPLACE(COALESCE(p.description, ''), char(10), ' '), char(13), '')),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND status NOT IN ('cancelled')),
			(SELECT COUNT(*) FROM tasks WHERE plan_id=p.id AND status NOT IN ('cancelled', 'skipped'))
		FROM plans p WHERE p.status='todo' ORDER BY p.created_at DESC
	" | while IFS='|' read -r pid pname pcreated pproject pdescription wave_count task_count; do
		[ -z "$pid" ] && continue

		# Age calculation
		local age_str=""
		if [ -n "$pcreated" ]; then
			local create_date days_old
			create_date=$(echo "$pcreated" | cut -d' ' -f1)
			days_old=$((($(date +%s) - $(date_only_to_epoch "$create_date")) / 86400))
			if [ "$days_old" -eq 0 ]; then
				age_str="today"
			elif [ "$days_old" -eq 1 ]; then
				age_str="1d"
			else
				age_str="${days_old}d"
			fi
		fi

		# Truncate fields to fit columns
		local proj_col name_col summary_col
		proj_col=$(echo "${pproject:-—}" | cut -c1-12)
		name_col=$(echo "$pname" | cut -c1-26)
		[ ${#pname} -gt 26 ] && name_col="${name_col:0:25}…"
		local wt_col="${wave_count}W/${task_count}T"
		local raw_summary="${pdescription:-}"
		summary_col=$(echo "$raw_summary" | cut -c1-30)

		# Age color
		local age_colored
		if [ "$days_old" -eq 0 ]; then
			age_colored="${TH_SUCCESS}${age_str}${TH_RST}"
		elif [ "${days_old:-0}" -gt 7 ]; then
			age_colored="${TH_ERROR}${age_str}${TH_RST}"
		else
			age_colored="${TH_MUTED}${age_str}${TH_RST}"
		fi

		local row_content
		row_content=$(printf "${TH_WARNING}#%-4s${TH_RST} ${TH_INFO}%-12s${TH_RST} ${TH_RST}%-26s${TH_RST} %-8s ${TH_MUTED}%-14s${TH_RST} ${TH_MUTED}%s${TH_RST}" \
			"$pid" "$proj_col" "$name_col" "$age_colored" "$wt_col" "$summary_col")
		_grid_row "$row_content"
	done

	_grid_box_end
}
