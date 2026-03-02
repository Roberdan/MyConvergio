#!/bin/bash
# Dashboard overview rendering — grid-based control center
# Version: 3.0.0

_render_overview() {
	[[ -z "${GRID_W:-}" ]] && _grid_width

	# Header: full-width title bar with theme + version
	local theme_label="${TH_NAME:-TERMINAL}"
	_grid_header "CONVERGIO CONTROL CENTER  |  ${theme_label}  |  v2.4"
	echo ""

	# DB overview — single query, no nested wave subqueries
	local overview
	overview=$(dbq "
SELECT
(SELECT COUNT(*) FROM plans),
(SELECT COUNT(*) FROM plans WHERE status='done'),
(SELECT COUNT(*) FROM plans WHERE status='doing'),
(SELECT COUNT(*) FROM plans WHERE status='todo'),
(SELECT COUNT(*) FROM tasks WHERE plan_id IN (SELECT id FROM plans WHERE status='doing')),
(SELECT COUNT(*) FROM tasks WHERE status='done' AND plan_id IN (SELECT id FROM plans WHERE status='doing')),
(SELECT COUNT(*) FROM tasks WHERE status='in_progress' AND plan_id IN (SELECT id FROM plans WHERE status='doing')),
(SELECT COUNT(*) FROM plans WHERE status='cancelled');
")
	local total plan_done doing todo total_tasks done_tasks in_progress_tasks cancelled
	total=$(printf '%s' "$overview" | cut -d'|' -f1)
	plan_done=$(printf '%s' "$overview" | cut -d'|' -f2)
	doing=$(printf '%s' "$overview" | cut -d'|' -f3)
	todo=$(printf '%s' "$overview" | cut -d'|' -f4)
	total_tasks=$(printf '%s' "$overview" | cut -d'|' -f5)
	done_tasks=$(printf '%s' "$overview" | cut -d'|' -f6)
	in_progress_tasks=$(printf '%s' "$overview" | cut -d'|' -f7)
	cancelled=$(printf '%s' "$overview" | cut -d'|' -f8)

	# 4 status cards: PLANS | ACTIVE | DONE | PIPELINE
	# Color injected via TH_ACCENT override per card is not directly supported;
	# use the accent color from the theme and annotate labels with ANSI prefix
	_grid_status_cards \
		"PLANS:${total:-0}" \
		"ACTIVE:${doing:-0}" \
		"DONE:${plan_done:-0}" \
		"PIPELINE:${todo:-0}"
	echo ""

	# Task counts summary line
	printf "  ${TH_MUTED}tasks (active plans):${TH_RST}  "
	printf "${TH_SUCCESS}${done_tasks:-0} done${TH_RST}  "
	printf "${TH_WARNING}${in_progress_tasks:-0} in_progress${TH_RST}  "
	printf "${TH_MUTED}${total_tasks:-0} total${TH_RST}\n"
	echo ""

	# Mesh mini-preview (if available)
	if type _render_mesh_mini &>/dev/null; then
		_render_mesh_mini
	fi

	# Active plans
	_render_active_plans

	# Pipeline plans
	_render_pipeline_plans

	# Blocked tasks (if requested)
	if [[ "${SHOW_BLOCKED:-0}" -eq 1 ]]; then
		local blocked_count
		blocked_count=$(dbq "SELECT COUNT(*) FROM tasks WHERE status='blocked'" 2>/dev/null)
		if [[ "${blocked_count:-0}" -gt 0 ]]; then
			_grid_section "BLOCKED TASKS" "(${blocked_count})"
			dbq "SELECT t.task_id, REPLACE(REPLACE(t.title, char(10), ' '), char(13), ''), p.id, p.project_id FROM tasks t JOIN waves w ON t.wave_id_fk = w.id JOIN plans p ON w.plan_id = p.id WHERE t.status = 'blocked' ORDER BY p.id" 2>/dev/null | while IFS='|' read -r task_id title plan_id blocked_project; do
				local short_title
				short_title=$(printf '%s' "$title" | cut -c1-45)
				[[ ${#title} -gt 45 ]] && short_title="${short_title}..."
				local proj_tag=""
				[[ -n "$blocked_project" ]] && proj_tag="${TH_INFO}[$blocked_project]${TH_RST} "
				printf "  ${TH_ERROR}%s${TH_RST}  %s${proj_tag}${TH_MUTED}[#%s]${TH_RST}\n" \
					"$task_id" "$short_title  " "$plan_id"
			done
			echo ""
		fi
	fi

	# Completed plans section
	_render_completed_plans

	# Warn about active/pipeline plans missing descriptions
	local missing_desc
	missing_desc=$(dbq "SELECT GROUP_CONCAT('#' || id, ', ') FROM plans WHERE status IN ('doing', 'todo') AND (description IS NULL OR description = '' OR description = '{')")
	if [[ -n "$missing_desc" ]]; then
		printf "${TH_WARNING}  missing description: ${TH_RST}${missing_desc}\n"
		printf "${TH_MUTED}  plan-db.sh update-desc <id> \"desc\"${TH_RST}\n"
		echo ""
	fi

	printf "${TH_MUTED}  piani -h for options${TH_RST}\n"
	echo ""
}

# Backward-compat alias
_render_dashboard_overview() { _render_overview "$@"; }
