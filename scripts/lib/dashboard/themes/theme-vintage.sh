#!/bin/bash
# Theme: Vintage — amber phosphor CRT, 1980s computing aesthetic
# Inspired by VT-100 terminals and early home computers

_theme_vintage() {
	TH_NAME="VINTAGE CRT"
	TH_PRIMARY=$'\033[38;5;172m'  # amber
	TH_SECONDARY=$'\033[38;5;208m' # orange
	TH_ACCENT=$'\033[38;5;214m'  # bright amber
	TH_MUTED=$'\033[38;5;94m'    # dark amber/brown
	TH_SUCCESS=$'\033[38;5;178m' # warm yellow-green
	TH_WARNING=$'\033[38;5;214m' # bright amber
	TH_ERROR=$'\033[38;5;160m'   # red
	TH_INFO=$'\033[38;5;172m'    # amber
	TH_HIGHLIGHT=$'\033[38;5;214m'
	TH_BAR_FILL='#'
	TH_BAR_EMPTY='.'
	TH_BAR_MID='='
	TH_SCANLINE='▄'
	TH_SECTION_L='[[ '
	TH_SECTION_R=' ]]'
	TH_HEADER_TOP="${TH_PRIMARY}${DIM}"
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
	TH_NODE_ONLINE="${TH_SUCCESS}"
	TH_NODE_OFFLINE="${TH_ERROR}"
	TH_BACKBONE='SERIAL LINK'
	TH_FOOTER_L="VT-100 TERMINAL v1.0"
	TH_FOOTER_R="READY."
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_SECONDARY}>${NC}"
	TH_DIAMOND="${TH_PRIMARY}*${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
