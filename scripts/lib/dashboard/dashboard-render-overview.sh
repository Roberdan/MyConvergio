#!/bin/bash
# Dashboard overview — cyberpunk agentic control room
# Version: 4.0.0

_render_overview() {
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local theme_label="${TH_NAME:-NEON GRID}"
	_grid_header "C O N T R O L   C E N T E R  ${TH_MUTED}│${NC}  ${theme_label}"
	echo ""

	# DB overview
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
(SELECT COUNT(*) FROM plans WHERE status='cancelled'),
(SELECT COUNT(*) FROM tasks WHERE status='blocked' AND plan_id IN (SELECT id FROM plans WHERE status='doing')),
(SELECT COUNT(*) FROM tasks WHERE status='submitted' AND plan_id IN (SELECT id FROM plans WHERE status='doing'));
")
	local total plan_done doing todo total_tasks done_tasks running cancelled blocked submitted
	total=$(printf '%s' "$overview" | cut -d'|' -f1)
	plan_done=$(printf '%s' "$overview" | cut -d'|' -f2)
	doing=$(printf '%s' "$overview" | cut -d'|' -f3)
	todo=$(printf '%s' "$overview" | cut -d'|' -f4)
	total_tasks=$(printf '%s' "$overview" | cut -d'|' -f5)
	done_tasks=$(printf '%s' "$overview" | cut -d'|' -f6)
	running=$(printf '%s' "$overview" | cut -d'|' -f7)
	cancelled=$(printf '%s' "$overview" | cut -d'|' -f8)
	blocked=$(printf '%s' "$overview" | cut -d'|' -f9)
	submitted=$(printf '%s' "$overview" | cut -d'|' -f10)

	# Status cards with color-coded values
	_grid_status_cards \
		"PLANS:${total:-0}:${TH_ACCENT}" \
		"ACTIVE:${doing:-0}:${TH_SUCCESS}" \
		"DONE:${plan_done:-0}:${TH_INFO}" \
		"PIPELINE:${todo:-0}:${TH_WARNING}" \
		"BLOCKED:${blocked:-0}:${TH_ERROR}"
	echo ""

	# Agent activity bar — live task distribution
	_render_agent_activity "$total_tasks" "$done_tasks" "$running" "$blocked" "$submitted"

	# Mesh mini-preview
	if type _render_mesh_mini &>/dev/null; then
		_render_mesh_mini
		echo ""
	fi

	# Active plans
	_render_active_plans

	# Token burn chart (if expanded mode)
	if [[ "${GRID_MODE:-standard}" != "compact" ]] && type _render_token_chart &>/dev/null; then
		_render_token_chart
		echo ""
	elif type _render_token_mini &>/dev/null; then
		_render_token_mini
		echo ""
	fi

	# Pipeline plans
	_render_pipeline_plans

	# Completed plans
	_render_completed_plans

	printf "\n  ${TH_MUTED}piani -h for options${TH_RST}\n\n"
}

# Agent activity visualization — shows task distribution as colored segments
_render_agent_activity() {
	local total="${1:-0}" done="${2:-0}" running="${3:-0}" blocked="${4:-0}" submitted="${5:-0}"
	local pending=$((total - done - running - blocked - submitted))
	[[ $pending -lt 0 ]] && pending=0
	[[ $total -eq 0 ]] && return

	local bar_w=$((GRID_W - 4))
	[[ $bar_w -lt 20 ]] && bar_w=20

	# Calculate segment widths proportionally
	local done_w=$((done * bar_w / total))
	local run_w=$((running * bar_w / total))
	local sub_w=$((submitted * bar_w / total))
	local blk_w=$((blocked * bar_w / total))
	local pend_w=$((bar_w - done_w - run_w - sub_w - blk_w))
	[[ $pend_w -lt 0 ]] && pend_w=0
	# Ensure at least 1 char for non-zero segments
	[[ $running -gt 0 && $run_w -eq 0 ]] && run_w=1 && pend_w=$((pend_w - 1))
	[[ $blocked -gt 0 && $blk_w -eq 0 ]] && blk_w=1 && pend_w=$((pend_w - 1))
	[[ $submitted -gt 0 && $sub_w -eq 0 ]] && sub_w=1 && pend_w=$((pend_w - 1))
	[[ $pend_w -lt 0 ]] && pend_w=0

	printf "  "
	[[ $done_w -gt 0 ]] && printf "${TH_SUCCESS}%s${TH_RST}" "$(_grid_repeat "█" "$done_w")"
	[[ $run_w -gt 0 ]] && printf "${TH_WARNING}%s${TH_RST}" "$(_grid_repeat "▓" "$run_w")"
	[[ $sub_w -gt 0 ]] && printf "${TH_INFO}%s${TH_RST}" "$(_grid_repeat "▒" "$sub_w")"
	[[ $blk_w -gt 0 ]] && printf "${TH_ERROR}%s${TH_RST}" "$(_grid_repeat "░" "$blk_w")"
	[[ $pend_w -gt 0 ]] && printf "${TH_MUTED}%s${TH_RST}" "$(_grid_repeat "·" "$pend_w")"
	printf "\n"

	# Legend line
	printf "  ${TH_SUCCESS}█${TH_RST}${TH_MUTED}done:${TH_RST}${done}"
	printf "  ${TH_WARNING}▓${TH_RST}${TH_MUTED}run:${TH_RST}${running}"
	printf "  ${TH_INFO}▒${TH_RST}${TH_MUTED}submit:${TH_RST}${submitted}"
	printf "  ${TH_ERROR}░${TH_RST}${TH_MUTED}block:${TH_RST}${blocked}"
	printf "  ${TH_MUTED}·pend:${TH_RST}${pending}"
	printf "  ${TH_MUTED}│${TH_RST}  ${TH_ACCENT}${total}${TH_RST}${TH_MUTED} total${TH_RST}\n\n"
}

_render_dashboard_overview() { _render_overview "$@"; }
