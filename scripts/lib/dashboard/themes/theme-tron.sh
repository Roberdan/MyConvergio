#!/bin/bash
# Theme: TRON — electric blue and orange, TRON Legacy aesthetic
# Inspired by TRON: Legacy (2010)

_theme_tron() {
	TH_NAME="TRON SYSTEM"
	TH_PRIMARY=$'\033[38;5;33m'   # electric blue
	TH_SECONDARY=$'\033[38;5;208m' # tron orange
	TH_ACCENT=$'\033[38;5;45m'   # bright cyan
	TH_MUTED=$'\033[38;5;236m'   # very dark gray
	TH_SUCCESS=$'\033[38;5;33m'  # electric blue
	TH_WARNING=$'\033[38;5;208m' # tron orange
	TH_ERROR=$'\033[38;5;196m'   # red
	TH_INFO=$'\033[38;5;45m'     # bright cyan
	TH_HIGHLIGHT=$'\033[38;5;208m'
	TH_BAR_FILL='▓'
	TH_BAR_EMPTY='░'
	TH_BAR_MID='▒'
	TH_SCANLINE='▀'
	TH_SECTION_L='◆ '
	TH_SECTION_R=' ◆'
	TH_HEADER_TOP="${TH_PRIMARY}"
	TH_HEADER_MID="${TH_ACCENT}${BOLD}"
	TH_BORDER_H='═'
	TH_BORDER_V='║'
	TH_CORNER_TL='╔'
	TH_CORNER_TR='╗'
	TH_CORNER_BL='╚'
	TH_CORNER_BR='╝'
	TH_INNER_H='─'
	TH_INNER_V='│'
	TH_INNER_TL='╭'
	TH_INNER_TR='╮'
	TH_INNER_BL='╰'
	TH_INNER_BR='╯'
	TH_NODE_ONLINE="${TH_PRIMARY}"
	TH_NODE_OFFLINE="${TH_ERROR}"
	TH_BACKBONE='GRID LINK'
	TH_FOOTER_L="TRON SYSTEM v4.0"
	TH_FOOTER_R="END OF LINE"
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_SECONDARY}◆${NC}"
	TH_DIAMOND="${TH_ACCENT}◆${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
