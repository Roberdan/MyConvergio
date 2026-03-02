#!/bin/bash
# Token analytics — cyberpunk burn chart with ASCII graph + sparklines
# Version: 4.0.0

_render_token_chart() {
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local chart_h=7 chart_w=$((GRID_W - 20))
	[[ $chart_w -lt 20 ]] && chart_w=20
	[[ $chart_w -gt 60 ]] && chart_w=60

	local daily_data
	daily_data=$(dbq "
		SELECT date(created_at) AS day,
			COALESCE(SUM(input_tokens + output_tokens), 0) AS tokens,
			COALESCE(SUM(cost_usd), 0.0) AS cost
		FROM token_usage
		WHERE date(created_at) >= date('now', '-6 days')
		GROUP BY day ORDER BY day ASC;
	" 2>/dev/null)

	local -a days=() values=() costs=() day_labels=()
	local max_val=1 total_cost=0

	local d
	for d in 6 5 4 3 2 1 0; do
		local target_day
		if [[ "$(uname)" == "Darwin" ]]; then
			target_day=$(date -j -v-${d}d "+%Y-%m-%d" 2>/dev/null)
		else
			target_day=$(date -d "-${d} days" "+%Y-%m-%d" 2>/dev/null)
		fi
		days+=("$target_day")
		if [[ "$(uname)" == "Darwin" ]]; then
			day_labels+=("$(date -j -v-${d}d "+%a" 2>/dev/null | cut -c1-3)")
		else
			day_labels+=("$(date -d "-${d} days" "+%a" 2>/dev/null | cut -c1-3)")
		fi
		local found=0
		while IFS='|' read -r db_day db_tokens db_cost; do
			if [[ "$db_day" == "$target_day" ]]; then
				values+=("${db_tokens:-0}")
				costs+=("${db_cost:-0}")
				total_cost=$(awk -v a="$total_cost" -v b="${db_cost:-0}" 'BEGIN{print a+b}')
				[[ ${db_tokens:-0} -gt $max_val ]] && max_val=${db_tokens:-0}
				found=1
				break
			fi
		done <<<"$daily_data"
		[[ $found -eq 0 ]] && values+=(0) && costs+=(0)
	done

	_grid_section "TOKEN BURN" "(7-day)"

	local row col val
	for ((row = chart_h; row >= 1; row--)); do
		local y_label=""
		if [[ $row -eq $chart_h ]]; then
			y_label=$(format_tokens "$max_val")
		elif [[ $row -eq 1 ]]; then
			y_label="0"
		elif [[ $row -eq $((chart_h / 2 + 1)) ]]; then
			y_label=$(format_tokens $((max_val / 2)))
		fi
		printf "  ${TH_MUTED}%5s${TH_RST} ${TH_MUTED}│${TH_RST}" "$y_label"
		for ((col = 0; col < 7; col++)); do
			val=${values[$col]:-0}
			local col_h=$((val * chart_h / max_val))
			[[ $max_val -eq 0 ]] && col_h=0
			local seg_w=$((chart_w / 7))
			if [[ $col_h -ge $row ]]; then
				local bar_color
				if [[ $row -ge $((chart_h * 3 / 4)) ]]; then
					bar_color="${TH_ERROR}"
				elif [[ $row -ge $((chart_h / 2)) ]]; then
					bar_color="${TH_WARNING}"
				else bar_color="${TH_SUCCESS}"; fi
				printf "${bar_color}"
				_grid_repeat "${TH_BAR_FILL}" "$seg_w"
				printf "${TH_RST}"
			else
				_grid_repeat " " "$seg_w"
			fi
		done
		printf "\n"
	done

	printf "  ${TH_MUTED}      └"
	_grid_repeat "─" "$chart_w"
	printf "${TH_RST}\n"
	printf "  ${TH_MUTED}       "
	for ((col = 0; col < 7; col++)); do
		local seg_w=$((chart_w / 7)) lbl="${day_labels[$col]:-???}" pad=$((seg_w - 3))
		[[ $pad -lt 0 ]] && pad=0
		printf "${TH_INFO}%s${TH_RST}%*s" "$lbl" "$pad" ""
	done
	printf "\n"

	local today_val=${values[6]:-0} avg_val=0
	for v in "${values[@]}"; do avg_val=$((avg_val + v)); done
	avg_val=$((avg_val / 7))
	printf "\n  ${TH_INFO}today${TH_RST} ${TH_ACCENT}${BOLD}%s${TH_RST}" "$(format_tokens "$today_val")"
	printf "  ${TH_MUTED}│${TH_RST}  ${TH_INFO}avg${TH_RST} ${TH_ACCENT}%s${TH_RST}/day" "$(format_tokens "$avg_val")"
	printf "  ${TH_MUTED}│${TH_RST}  ${TH_INFO}cost${TH_RST} ${TH_WARNING}\$%.2f${TH_RST}/7d" "$total_cost"
	local spark_vals
	spark_vals=$(
		IFS=','
		echo "${values[*]}"
	)
	printf "  ${TH_MUTED}│${TH_RST}  "
	_th_sparkline "$spark_vals" "${TH_SECONDARY}"
	printf "\n"
}

_render_token_analytics() {
	[[ -z "${GRID_W:-}" ]] && _grid_width
	_grid_section "TOKEN ANALYTICS"
	echo ""
	local stats
	stats=$(dbq "
		SELECT COALESCE(SUM(input_tokens + output_tokens), 0),
			COALESCE(SUM(CASE WHEN date(timestamp) >= date('now', '-7 days')
				THEN input_tokens + output_tokens ELSE 0 END), 0)
		FROM token_usage;
	")
	local total_all total_7d
	total_all=$(printf '%s' "$stats" | cut -d'|' -f1)
	total_7d=$(printf '%s' "$stats" | cut -d'|' -f2)
	printf "  ${TH_ACCENT}${BOLD}Total:${TH_RST} %s" "$(format_tokens "${total_all:-0}")"
	printf "    ${TH_MUTED}7d:${TH_RST} %s\n\n" "$(format_tokens "${total_7d:-0}")"

	_grid_box_start "MODEL BREAKDOWN"
	local model_data bar_max=0
	model_data=$(dbq "
		SELECT COALESCE(model, 'unknown'), SUM(input_tokens + output_tokens)
		FROM token_usage GROUP BY model ORDER BY SUM(input_tokens + output_tokens) DESC;
	")
	if [[ -z "$model_data" ]]; then
		_grid_row "${TH_MUTED}No token data${TH_RST}"
	else
		while IFS='|' read -r _m tokens; do
			[[ ${tokens:-0} -gt $bar_max ]] && bar_max=$tokens
		done <<<"$model_data"
		[[ $bar_max -eq 0 ]] && bar_max=1
		local bar_w=$(((GRID_W - 40) > 5 ? (GRID_W - 40) : 5))
		while IFS='|' read -r model tokens; do
			[[ -z "$model" ]] && continue
			local pct=$((tokens * 100 / bar_max)) filled=$((pct * bar_w / 100))
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
			local short_model cost
			short_model=$(printf '%s' "$model" | sed 's/claude-//' | cut -c1-18)
			cost=$(format_cost "$tokens" "$model")
			printf "  ${TH_INNER_V} ${color}%-18s${TH_RST} %s${TH_RST} %8s  %s\n" \
				"$short_model" "$bar" "$(format_tokens "$tokens")" "$cost"
		done <<<"$model_data"
	fi
	_grid_box_end
	echo ""
	printf "  ${TH_MUTED}Press B to go back${TH_RST}\n"
}

_render_token_mini() {
	local all_row today_row
	all_row=$(dbq "SELECT COALESCE(SUM(input_tokens+output_tokens),0), COALESCE(SUM(cost_usd),0) FROM token_usage")
	today_row=$(dbq "SELECT COALESCE(SUM(input_tokens+output_tokens),0), COALESCE(SUM(cost_usd),0) FROM token_usage WHERE date(created_at)=date('now')")
	local total_tok total_cost today_tok today_cost
	total_tok=$(printf '%s' "$all_row" | cut -d'|' -f1)
	total_cost=$(printf '%s' "$all_row" | cut -d'|' -f2)
	today_tok=$(printf '%s' "$today_row" | cut -d'|' -f1)
	today_cost=$(printf '%s' "$today_row" | cut -d'|' -f2)
	printf "  ${TH_INFO}tokens${TH_RST} ${TH_ACCENT}$(format_tokens "${total_tok:-0}")${TH_RST}"
	printf "  ${TH_MUTED}│${TH_RST}  ${TH_INFO}today${TH_RST} ${TH_SUCCESS}$(format_tokens "${today_tok:-0}")${TH_RST}"
	printf "  ${TH_MUTED}│${TH_RST}  ${TH_INFO}cost${TH_RST} ${TH_WARNING}\$${total_cost:-0}${TH_RST}\n"
}
