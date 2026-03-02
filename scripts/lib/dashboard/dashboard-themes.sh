#!/bin/bash
# Dashboard design system — theme engine
# Version: 2.1.0
# Fix: use $'\033[...]' (real ESC bytes) instead of '\033[...]' (literal strings)

_theme_muthur() {
	TH_NAME="MUTHUR 6000"
	TH_PRIMARY=$'\033[38;5;46m'
	TH_SECONDARY=$'\033[38;5;22m'
	TH_ACCENT=$'\033[1;33m'
	TH_MUTED=$'\033[0;90m'
	TH_SUCCESS=$'\033[0;32m'
	TH_WARNING=$'\033[1;33m'
	TH_ERROR=$'\033[0;31m'
	TH_INFO=$'\033[0;36m'
	TH_BAR_FILL='▓'
	TH_BAR_EMPTY='░'
	TH_SCANLINE='░'
	TH_SECTION_L='▐ '
	TH_SECTION_R=' ▌'
	TH_HEADER_TOP="${TH_PRIMARY}${DIM}"
	TH_HEADER_MID="${TH_PRIMARY}${BOLD}"
	TH_BORDER_H='─'
	TH_BORDER_V='│'
	TH_CORNER_TL='┌'
	TH_CORNER_TR='┐'
	TH_CORNER_BL='└'
	TH_CORNER_BR='┘'
	TH_INNER_H='─'
	TH_INNER_V='│'
	TH_INNER_TL='┌'
	TH_INNER_TR='┐'
	TH_INNER_BL='└'
	TH_INNER_BR='┘'
	TH_NODE_ONLINE="$TH_PRIMARY"
	TH_NODE_OFFLINE=$'\033[0;31m'
	TH_BACKBONE='MESH BACKBONE'
	TH_FOOTER_L="MUTHUR INTERFACE"
	TH_FOOTER_R="NOSTROMO-CLASS TERMINAL"
	TH_STATUS_PREFIX="${TH_PRIMARY}${DIM}"
	TH_PLAN_BULLET="${TH_MUTED}"
}

_theme_nexus6() {
	TH_NAME="NEXUS-6"
	TH_PRIMARY=$'\033[38;5;214m'
	TH_SECONDARY=$'\033[1;36m'
	TH_ACCENT=$'\033[38;5;208m'
	TH_MUTED=$'\033[0;90m'
	TH_SUCCESS=$'\033[0;32m'
	TH_WARNING=$'\033[1;33m'
	TH_ERROR=$'\033[0;31m'
	TH_INFO=$'\033[0;36m'
	TH_BAR_FILL='▰'
	TH_BAR_EMPTY='▱'
	TH_SCANLINE='═'
	TH_SECTION_L=''
	TH_SECTION_R=''
	TH_HEADER_TOP="${TH_PRIMARY}"
	TH_HEADER_MID="${TH_PRIMARY}${BOLD}"
	TH_BORDER_H='═'
	TH_BORDER_V='║'
	TH_CORNER_TL='╔'
	TH_CORNER_TR='╗'
	TH_CORNER_BL='╚'
	TH_CORNER_BR='╝'
	TH_INNER_H='─'
	TH_INNER_V='│'
	TH_INNER_TL='┌'
	TH_INNER_TR='┐'
	TH_INNER_BL='└'
	TH_INNER_BR='┘'
	TH_NODE_ONLINE="${TH_PRIMARY}"
	TH_NODE_OFFLINE=$'\033[0;31m'
	TH_BACKBONE='BACKBONE LINK'
	TH_FOOTER_L="NEXUS-6 INTERFACE"
	TH_FOOTER_R="VOIGHT-KAMPFF TERMINAL"
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_PRIMARY}▸${NC}"
}

_theme_hal9000() {
	TH_NAME="HAL 9000"
	TH_PRIMARY=$'\033[38;5;196m'
	TH_SECONDARY=$'\033[38;5;248m'
	TH_ACCENT=$'\033[38;5;196m'
	TH_MUTED=$'\033[38;5;244m'
	TH_SUCCESS=$'\033[0;32m'
	TH_WARNING=$'\033[1;33m'
	TH_ERROR=$'\033[0;31m'
	TH_INFO=$'\033[0;36m'
	TH_BAR_FILL='█'
	TH_BAR_EMPTY='░'
	TH_SCANLINE='━'
	TH_SECTION_L=''
	TH_SECTION_R=''
	TH_HEADER_TOP="${TH_PRIMARY}"
	TH_HEADER_MID="${TH_SECONDARY}"
	TH_BORDER_H='─'
	TH_BORDER_V='│'
	TH_CORNER_TL='┌'
	TH_CORNER_TR='┐'
	TH_CORNER_BL='└'
	TH_CORNER_BR='┘'
	TH_INNER_H='━'
	TH_INNER_V='┃'
	TH_INNER_TL='┏'
	TH_INNER_TR='┓'
	TH_INNER_BL='┗'
	TH_INNER_BR='┛'
	TH_NODE_ONLINE="${TH_SECONDARY}"
	TH_NODE_OFFLINE=$'\033[38;5;88m'
	TH_BACKBONE='BBK'
	TH_FOOTER_L="HAL 9000 INTERFACE"
	TH_FOOTER_R="DISCOVERY ONE TERMINAL"
	TH_STATUS_PREFIX="${TH_SECONDARY}"
	TH_PLAN_BULLET="${TH_PRIMARY}▸${NC}"
}

_theme_load() {
	local name="${1:-muthur}"
	case "$name" in
	muthur | alien) _theme_muthur ;;
	nexus6 | nexus | blade*) _theme_nexus6 ;;
	hal9000 | hal | 2001) _theme_hal9000 ;;
	*) _theme_muthur ;;
	esac
	TH_RST="${NC}"
}

# --- Themed render helpers ---

_th_scanline() {
	local w="${1:-65}" line=""
	for ((i = 0; i < w; i++)); do line+="$TH_SCANLINE"; done
	printf '%s%s%s\n' "${TH_HEADER_TOP}" "${line}" "${NC}"
}

_th_header() {
	local title="$1" subtitle="${2:-}" w=65
	_th_scanline $w
	if [[ -n "$subtitle" ]]; then
		printf " %s%s%s%s  %s%s%s\n" "${TH_HEADER_MID}" "${BOLD}" "$title" "${NC}" "${TH_MUTED}" "$subtitle" "${NC}"
	else
		printf " %s%s%s%s\n" "${TH_HEADER_MID}" "${BOLD}" "$title" "${NC}"
	fi
	_th_scanline $w
}

_th_section() {
	printf '%s%s%s%s%s%s%s%s%s %s\n' \
		"${TH_PRIMARY}" "${TH_SECTION_L}" "${BOLD}" "${WHITE}" "$1" "${NC}" \
		"${TH_PRIMARY}" "${TH_SECTION_R}" "${NC}" "${2:-}"
}

_th_box_top() {
	local w="${1:-57}" color="${2:-$TH_SECONDARY}" line=""
	for ((i = 0; i < w - 2; i++)); do line+="${TH_BORDER_H}"; done
	printf '%s%s%s%s%s\n' "${color}" "${TH_CORNER_TL}" "${line}" "${TH_CORNER_TR}" "${NC}"
}

_th_box_bot() {
	local w="${1:-57}" color="${2:-$TH_SECONDARY}" line=""
	for ((i = 0; i < w - 2; i++)); do line+="${TH_BORDER_H}"; done
	printf '%s%s%s%s%s\n' "${color}" "${TH_CORNER_BL}" "${line}" "${TH_CORNER_BR}" "${NC}"
}

_th_box_row() {
	local content="$1" w="${2:-57}" color="${3:-$TH_SECONDARY}"
	printf '%s%s%s %s %s%s%s\n' "${color}" "${TH_BORDER_V}" "${NC}" "${content}" "${color}" "${TH_BORDER_V}" "${NC}"
}

_th_bar() {
	local pct="${1:-0}" width="${2:-20}"
	local filled=$((pct * width / 100)) empty=$((width - filled))
	local bar="" ebar="" fill_color
	if [[ $pct -ge 80 ]]; then
		fill_color="${TH_SUCCESS:-$GREEN}"
	elif [[ $pct -ge 40 ]]; then
		fill_color="${TH_WARNING:-$YELLOW}"
	else fill_color="${TH_ERROR:-$RED}"; fi
	for ((i = 0; i < filled; i++)); do bar+="$TH_BAR_FILL"; done
	for ((i = 0; i < empty; i++)); do ebar+="$TH_BAR_EMPTY"; done
	printf '%s%s%s%s%s\n' "${fill_color}" "${bar}" "${GRAY}" "${ebar}" "${NC}"
}

_th_footer() {
	local w=65
	echo ""
	_th_scanline $w
	printf '  %s%s%s  %s|%s  %spiani -h%s  %s|%s  %s%s v2.4%s\n' \
		"${TH_SECONDARY}" "${TH_FOOTER_L}" "${NC}" "${TH_MUTED}" "${NC}" \
		"${TH_MUTED}" "${NC}" "${TH_MUTED}" "${NC}" \
		"${TH_SECONDARY}" "${TH_FOOTER_R}" "${NC}"
	_th_scanline $w
}
