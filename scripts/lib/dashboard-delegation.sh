#!/bin/bash
# Dashboard delegation stats module
# Version: 2.0.0
# Provides render_delegation_stats() for dashboard-mini.sh
# Uses _grid_* layout helpers when available (sourced by dashboard-mini.sh)

DELEGATION_LOG="${DELEGATION_LOG:-$HOME/.claude/data/delegation_log}"

render_delegation_stats() {
	[[ ! -f "$DELEGATION_LOG" ]] && return

	# Provider distribution
	local providers
	providers=$(awk -F'|' '{print $2}' "$DELEGATION_LOG" | sort | uniq -c | sort -nr)

	if command -v _grid_section &>/dev/null; then
		_grid_section "DELEGATION STATS" "$(wc -l <"$DELEGATION_LOG") total delegations"
		_grid_box_start "Provider Distribution"

		while IFS= read -r line; do
			local count prov
			count=$(echo "$line" | awk '{print $1}')
			prov=$(echo "$line" | awk '{print $2}')
			local pct=0
			local total_lines
			total_lines=$(wc -l <"$DELEGATION_LOG")
			[[ "$total_lines" -gt 0 ]] && pct=$((count * 100 / total_lines))
			local bar
			bar=$(render_bar "$pct" 15 2>/dev/null || printf "%-15s" "")
			_grid_row "$(printf "${TH_ACCENT:-}%-18s${NC:-} %s ${TH_MUTED:-}%3d%%${NC:-}" "$prov" "$bar" "$pct")"
		done <<<"$providers"

		_grid_box_end
		_grid_box_start "Thor Pass Rate by Model"

		local models
		models=$(awk -F'|' '{print $3}' "$DELEGATION_LOG" | sort -u)
		for model in $models; do
			local total pass rate
			total=$(awk -F'|' -v m="$model" '$3==m{c++} END{print c+0}' "$DELEGATION_LOG")
			pass=$(awk -F'|' -v m="$model" '$3==m && $5=="PASS"{c++} END{print c+0}' "$DELEGATION_LOG")
			rate=$((total > 0 ? pass * 100 / total : 0))
			local color="${TH_SUCCESS:-\033[0;32m}"
			[[ $rate -lt 70 ]] && color="${TH_ERROR:-\033[0;31m}"
			local bar
			bar=$(render_bar "$rate" 10 2>/dev/null || printf "%-10s" "")
			_grid_row "$(printf "${TH_INFO:-}%-20s${NC:-} %s ${color}%3d%%${NC:-} ${TH_MUTED:-}(%d/%d)${NC:-}" \
				"$model" "$bar" "$rate" "$pass" "$total")"
			[[ $rate -lt 70 ]] && _grid_row "$(printf "${TH_ERROR:-}  ALERT: %s pass rate <70%%${NC:-}" "$model")"
		done

		_grid_box_end
	else
		# Fallback: plain text output
		echo "Provider distribution:"
		echo "$providers"
		echo ""
		echo "Thor pass rate per model:"
		local models
		models=$(awk -F'|' '{print $3}' "$DELEGATION_LOG" | sort -u)
		for model in $models; do
			local total pass rate color
			total=$(awk -F'|' -v m="$model" '$3==m{c++} END{print c+0}' "$DELEGATION_LOG")
			pass=$(awk -F'|' -v m="$model" '$3==m && $5=="PASS"{c++} END{print c+0}' "$DELEGATION_LOG")
			rate=$((total > 0 ? pass * 100 / total : 0))
			color="\033[0;32m"
			[[ $rate -lt 70 ]] && color="\033[0;31m"
			echo -e "  $model: ${color}${rate}%\033[0m ($pass/$total)"
			[[ $rate -lt 70 ]] && echo -e "  ALERT: $model pass rate <70%"
		done
	fi

	# Cost savings estimate (always shown)
	local savings
	savings=$(awk -F'|' '{s += $6} END{print s+0}' "$DELEGATION_LOG")
	[[ -n "${TH_INFO:-}" ]] && echo -e "${TH_MUTED:-}Estimated savings:${NC:-} ${TH_SUCCESS:-}$(format_tokens "$savings") tokens${NC:-}" ||
		echo "Estimated cost savings: $savings tokens"
}
