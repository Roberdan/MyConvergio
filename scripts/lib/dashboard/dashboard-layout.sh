#!/bin/bash
# Dashboard grid layout engine — terminal rendering primitives
# Version: 1.1.0
# GRID_MODE: compact (<80) | standard (80-120) | expanded (>120)
_grid_width() {
	GRID_W=$(tput cols 2>/dev/null || echo 80)
	[[ "$GRID_W" -lt 40 ]] && GRID_W=40
	[[ "$GRID_W" -gt 220 ]] && GRID_W=220
	if [[ "$GRID_W" -lt 80 ]]; then
		GRID_MODE="compact"
	elif [[ "$GRID_W" -gt 120 ]]; then
		GRID_MODE="expanded"
	else
		GRID_MODE="standard"
	fi
	return 0
}

_grid_repeat() {
	local char="$1" count="$2" out="" i
	for ((i = 0; i < count; i++)); do out+="$char"; done
	printf '%s' "$out"
}

_grid_fit() {
	local str="$1" width="$2" plain
	plain=$(printf '%s' "$str" | sed 's/\x1b\[[0-9;]*m//g')
	local len=${#plain}
	if [[ $len -ge $width ]]; then
		printf '%s' "${plain:0:$width}"
	else
		printf '%s%*s' "$str" $((width - len)) ""
	fi
}

_grid_header() {
	local title="${1:-CONTROL CENTER}"
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local inner=$((GRID_W - 2))
	local top_line=$(_grid_repeat "${TH_BORDER_H}" "$inner")
	printf "${TH_PRIMARY}${TH_CORNER_TL}%s${TH_CORNER_TR}${TH_RST}\n" "$top_line"
	local title_len=${#title} pad_total=$((inner - title_len - 2))
	local pad_l=$((pad_total / 2))
	local pad_r=$((pad_total - pad_l))
	printf "${TH_PRIMARY}${TH_BORDER_V}${TH_RST} ${TH_HEADER_MID}${BOLD}"
	printf "%*s%s%*s" "$pad_l" "" "$title" "$pad_r" ""
	printf "${TH_RST} ${TH_PRIMARY}${TH_BORDER_V}${TH_RST}\n"
	local bot_line=$(_grid_repeat "${TH_BORDER_H}" "$inner")
	printf "${TH_PRIMARY}${TH_CORNER_BL}%s${TH_CORNER_BR}${TH_RST}\n" "$bot_line"
}

_grid_status_cards() {
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local -a cards=("$@")
	local count=${#cards[@]}
	[[ $count -eq 0 ]] && return

	if [[ "${GRID_MODE:-standard}" == "compact" && $count -gt 2 ]]; then
		_grid_status_cards_compact "${cards[@]}"
		return
	fi

	local card_w=$(((GRID_W - count - 1) / count))
	[[ $card_w -lt 8 ]] && card_w=8

	local i label value top inner bot
	printf "${TH_PRIMARY}"
	for ((i = 0; i < count; i++)); do
		top=$(_grid_repeat "${TH_INNER_H}" $((card_w - 2)))
		printf "${TH_INNER_TL}%s${TH_INNER_TR}" "$top"
		[[ $i -lt $((count - 1)) ]] && printf " "
	done
	printf "${TH_RST}\n"

	for ((i = 0; i < count; i++)); do
		IFS=':' read -r label value <<<"${cards[$i]}"
		value="${value:-0}"
		local vlen=${#value}
		local vpad_l=$(((card_w - 2 - vlen) / 2)) vpad_r=$((card_w - 2 - vlen - (card_w - 2 - vlen) / 2))
		printf "${TH_PRIMARY}${TH_INNER_V}${TH_RST}"
		printf "${TH_ACCENT}${BOLD}%*s%s%*s${TH_RST}" "$vpad_l" "" "$value" "$vpad_r" ""
		printf "${TH_PRIMARY}${TH_INNER_V}${TH_RST}"
		[[ $i -lt $((count - 1)) ]] && printf " "
	done
	printf "\n"

	for ((i = 0; i < count; i++)); do
		IFS=':' read -r label value <<<"${cards[$i]}"
		local llen=${#label} lpad_l=$(((card_w - 2 - llen) / 2)) lpad_r=$((card_w - 2 - llen - (card_w - 2 - llen) / 2))
		printf "${TH_PRIMARY}${TH_INNER_V}${TH_RST}"
		printf "${TH_MUTED}%*s%s%*s${TH_RST}" "$lpad_l" "" "$label" "$lpad_r" ""
		printf "${TH_PRIMARY}${TH_INNER_V}${TH_RST}"
		[[ $i -lt $((count - 1)) ]] && printf " "
	done
	printf "\n"

	printf "${TH_PRIMARY}"
	for ((i = 0; i < count; i++)); do
		bot=$(_grid_repeat "${TH_INNER_H}" $((card_w - 2)))
		printf "${TH_INNER_BL}%s${TH_INNER_BR}" "$bot"
		[[ $i -lt $((count - 1)) ]] && printf " "
	done
	printf "${TH_RST}\n"
}

_grid_section() {
	local title="$1" subtitle="${2:-}"
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local sep=$(_grid_repeat "${TH_INNER_H}" "$GRID_W")
	printf "${TH_PRIMARY}%s${TH_RST}\n" "$sep"
	if [[ -n "$subtitle" ]]; then
		printf " ${TH_HEADER_MID}${BOLD}%s${TH_RST}  ${TH_MUTED}%s${TH_RST}\n" "$title" "$subtitle"
	else
		printf " ${TH_PRIMARY}${BOLD}%s${TH_RST}\n" "$title"
	fi
}

_grid_box_start() {
	local label="${1:-}" width="${2:-}"
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local w="${width:-$GRID_W}"
	local inner=$((w - 2))
	local top=$(_grid_repeat "${TH_INNER_H}" "$inner")
	if [[ -n "$label" ]]; then
		local llen=${#label} after=$((inner - llen - 2))
		[[ $after -lt 0 ]] && after=0
		local after_line=$(_grid_repeat "${TH_INNER_H}" "$after")
		printf "${TH_PRIMARY}${TH_INNER_TL}${TH_INNER_H} ${TH_ACCENT}${BOLD}%s${TH_RST} ${TH_PRIMARY}%s${TH_INNER_TR}${TH_RST}\n" \
			"$label" "$after_line"
	else
		printf "${TH_PRIMARY}${TH_INNER_TL}%s${TH_INNER_TR}${TH_RST}\n" "$top"
	fi
}

_grid_box_end() {
	local width="${1:-}"
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local w="${width:-$GRID_W}"
	local bot=$(_grid_repeat "${TH_INNER_H}" $((w - 2)))
	printf "${TH_PRIMARY}${TH_INNER_BL}%s${TH_INNER_BR}${TH_RST}\n" "$bot"
}

_grid_progress_bar() {
	local pct="${1:-0}" width="${2:-20}" label="${3:-}"
	[[ $pct -lt 0 ]] && pct=0
	[[ $pct -gt 100 ]] && pct=100
	local filled=$((pct * width / 100))
	local empty=$((width - filled))
	local bar ebar fill_color
	if [[ $pct -ge 80 ]]; then
		fill_color="${TH_SUCCESS}"
	elif [[ $pct -ge 40 ]]; then
		fill_color="${TH_WARNING}"
	else
		fill_color="${TH_ERROR}"
	fi
	bar=$(_grid_repeat "${TH_BAR_FILL}" "$filled")
	ebar=$(_grid_repeat "${TH_BAR_EMPTY}" "$empty")
	if [[ -n "$label" ]]; then
		printf "${fill_color}%s${TH_MUTED}%s${TH_RST} ${TH_ACCENT}%3d%%${TH_RST} %s\n" \
			"$bar" "$ebar" "$pct" "$label"
	else
		printf "${fill_color}%s${TH_MUTED}%s${TH_RST} ${TH_ACCENT}%3d%%${TH_RST}\n" \
			"$bar" "$ebar" "$pct"
	fi
}

_grid_row() {
	local content="$1" width="${2:-}"
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local w="${width:-$GRID_W}"
	local fitted=$(_grid_fit "$content" $((w - 4)))
	printf "${TH_PRIMARY}${TH_INNER_V}${TH_RST} %s ${TH_PRIMARY}${TH_INNER_V}${TH_RST}\n" "$fitted"
}

_grid_footer() {
	local left="${1:-${TH_FOOTER_L:-CONTROL CENTER}}"
	local right="${2:-${TH_FOOTER_R:-TERMINAL}}"
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local sep=$(_grid_repeat "${TH_BORDER_H}" "$GRID_W")
	printf "\n${TH_PRIMARY}%s${TH_RST}\n" "$sep"
	printf "  ${TH_SECONDARY}%s${TH_RST}  ${TH_MUTED}│${TH_RST}  ${TH_MUTED}q:quit  r:refresh  t:theme${TH_RST}  ${TH_MUTED}│${TH_RST}  ${TH_SECONDARY}%s${TH_RST}\n" "$left" "$right"
	printf "${TH_PRIMARY}%s${TH_RST}\n" "$sep"
}

_grid_separator() {
	local width="${1:-}" char="${2:-}"
	[[ -z "${GRID_W:-}" ]] && _grid_width
	local w="${width:-$GRID_W}" c="${char:-${TH_BORDER_H}}"
	local line=$(_grid_repeat "$c" "$w")
	printf "${TH_PRIMARY}%s${TH_RST}\n" "$line"
}

_grid_status_cards_compact() {
	local -a cards=("$@")
	local count=${#cards[@]} per_row=2
	local card_w=$(((GRID_W - 3) / per_row))
	[[ $card_w -lt 8 ]] && card_w=8
	local i row_start label value top bot
	for ((row_start = 0; row_start < count; row_start += per_row)); do
		local row_end=$((row_start + per_row))
		[[ $row_end -gt $count ]] && row_end=$count
		printf "${TH_PRIMARY}"
		for ((i = row_start; i < row_end; i++)); do
			top=$(_grid_repeat "${TH_INNER_H}" $((card_w - 2)))
			printf "${TH_INNER_TL}%s${TH_INNER_TR}" "$top"
			[[ $i -lt $((row_end - 1)) ]] && printf " "
		done
		printf "${TH_RST}\n"
		for ((i = row_start; i < row_end; i++)); do
			IFS=':' read -r label value <<<"${cards[$i]}"
			local cpad=$((card_w - 2 - ${#value} - ${#label} - 1))
			[[ $cpad -lt 0 ]] && cpad=0
			printf "${TH_PRIMARY}${TH_INNER_V}${TH_RST}${TH_ACCENT}${BOLD}%s${TH_RST}${TH_MUTED} %s%*s${TH_RST}${TH_PRIMARY}${TH_INNER_V}${TH_RST}" "${value:-0}" "$label" "$cpad" ""
			[[ $i -lt $((row_end - 1)) ]] && printf " "
		done
		printf "\n${TH_PRIMARY}"
		for ((i = row_start; i < row_end; i++)); do
			bot=$(_grid_repeat "${TH_INNER_H}" $((card_w - 2)))
			printf "${TH_INNER_BL}%s${TH_INNER_BR}" "$bot"
			[[ $i -lt $((row_end - 1)) ]] && printf " "
		done
		printf "${TH_RST}\n"
	done
}
