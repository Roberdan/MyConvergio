#!/bin/bash
# Token analytics view — total usage, per-model breakdown, daily sparkline
# Version: 1.0.0
# Requires: dashboard-config.sh, dashboard-themes.sh, dashboard-layout.sh, dashboard-db.sh

_render_token_analytics() {
	[[ -z "${GRID_W:-}" ]] && _grid_width

	_grid_section "TOKEN ANALYTICS"
	echo ""

	# Total tokens (all time) + last 7 days
	local stats
	stats=$(dbq "
		SELECT
			COALESCE(SUM(input_tokens + output_tokens), 0),
			COALESCE(SUM(CASE WHEN date(timestamp) >= date('now', '-7 days')
				THEN input_tokens + output_tokens ELSE 0 END), 0)
		FROM token_usage;
	")
	local total_all total_7d
	total_all=$(printf '%s' "$stats" | cut -d'|' -f1)
	total_7d=$(printf '%s' "$stats" | cut -d'|' -f2)

	printf "  ${TH_ACCENT}${BOLD}Total tokens:${TH_RST}  %s" "$(format_tokens "${total_all:-0}")"
	printf "    ${TH_MUTED}Last 7 days:${TH_RST}  %s\n" "$(format_tokens "${total_7d:-0}")"
	echo ""

	# Per-model breakdown
	_grid_box_start "MODEL BREAKDOWN"
	local model_data bar_max=0
	model_data=$(dbq "
		SELECT
			COALESCE(model, 'unknown'),
			SUM(input_tokens + output_tokens)
		FROM token_usage
		GROUP BY model
		ORDER BY SUM(input_tokens + output_tokens) DESC;
	")
	if [[ -z "$model_data" ]]; then
		_grid_row "${TH_MUTED}No token usage data${TH_RST}"
	else
		# Find max for bar scaling
		while IFS='|' read -r _m tokens; do
			[[ ${tokens:-0} -gt $bar_max ]] && bar_max=$tokens
		done <<<"$model_data"
		[[ $bar_max -eq 0 ]] && bar_max=1

		# Render each model
		local bar_w=$(((GRID_W - 40) > 5 ? (GRID_W - 40) : 5))
		while IFS='|' read -r model tokens; do
			[[ -z "$model" ]] && continue
			local pct=$((tokens * 100 / bar_max))
			local filled=$((pct * bar_w / 100))
			[[ $filled -lt 1 ]] && filled=1
			local bar="" color=""
			case "$model" in
			*opus*) color="${TH_ERROR}" ;;
			*sonnet*) color="${TH_INFO}" ;;
			*haiku*) color="${TH_SUCCESS}" ;;
			*codex* | *gpt*) color="${TH_WARNING}" ;;
			*) color="${TH_MUTED}" ;;
			esac
			local i
			for ((i = 0; i < filled; i++)); do bar+="${TH_BAR_FILL:-█}"; done
			local short_model
			short_model=$(printf '%s' "$model" | sed 's/claude-//' | cut -c1-18)
			local cost
			cost=$(format_cost "$tokens" "$model")
			printf "  ${TH_INNER_V} ${color}%-18s${TH_RST} %s${TH_RST} %8s  %s\n" \
				"$short_model" "$bar" "$(format_tokens "$tokens")" "$cost"
		done <<<"$model_data"
	fi
	_grid_box_end
	echo ""

	# Cost summary
	local cost_data total_cost="0"
	cost_data=$(dbq "
		SELECT COALESCE(model, 'unknown'), SUM(input_tokens + output_tokens)
		FROM token_usage GROUP BY model;
	")
	if [[ -n "$cost_data" ]]; then
		while IFS='|' read -r model tokens; do
			local rate=0
			case "$model" in
			*opus*) rate=15 ;;
			*sonnet*) rate=3 ;;
			*haiku*) rate=1 ;;
			esac
			local c
			c=$(awk -v t="${tokens:-0}" -v r="$rate" 'BEGIN{printf "%.4f", t * r / 1000000}')
			total_cost=$(awk -v a="$total_cost" -v b="$c" 'BEGIN{printf "%.2f", a + b}')
		done <<<"$cost_data"
	fi
	printf "  ${TH_ACCENT}${BOLD}Estimated cost:${TH_RST}  \$%s\n" "$total_cost"
	echo ""

	# Daily sparkline (last 14 days) using block chars
	_grid_box_start "DAILY USAGE (14 DAYS)"
	local daily_data daily_max=0
	daily_data=$(dbq "
		SELECT date(timestamp), SUM(input_tokens + output_tokens)
		FROM token_usage
		WHERE date(timestamp) >= date('now', '-14 days')
		GROUP BY date(timestamp)
		ORDER BY date(timestamp);
	")
	if [[ -z "$daily_data" ]]; then
		_grid_row "${TH_MUTED}No data for last 14 days${TH_RST}"
	else
		# Find max day
		while IFS='|' read -r _d tokens; do
			[[ ${tokens:-0} -gt $daily_max ]] && daily_max=$tokens
		done <<<"$daily_data"
		[[ $daily_max -eq 0 ]] && daily_max=1

		# Block chars for vertical bar (height 0-8 eighths)
		local blocks=(" " "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
		local spark_line="" date_line="" count=0
		while IFS='|' read -r day tokens; do
			[[ -z "$day" ]] && continue
			local level=$((tokens * 8 / daily_max))
			[[ $level -gt 8 ]] && level=8
			spark_line+="${blocks[$level]}"
			# Show day label every 3rd or first/last
			if [[ $((count % 3)) -eq 0 ]]; then
				date_line+=$(printf '%s' "$day" | cut -c6-10)
			else
				date_line+="     "
			fi
			count=$((count + 1))
		done <<<"$daily_data"
		printf "  ${TH_INNER_V} ${TH_ACCENT}%s${TH_RST}\n" "$spark_line"
		printf "  ${TH_INNER_V} ${TH_MUTED}%s${TH_RST}\n" "$date_line"
	fi
	_grid_box_end
	echo ""

	printf "  ${TH_MUTED}Press B to go back${TH_RST}\n"
}
