#!/bin/bash
# Theme: Neon Grid (Cyberpunk) — migrated from dashboard-themes.sh
# Original theme, electric cyan + hot magenta palette

_theme_neon_grid() {
	TH_NAME="NEON GRID"
	TH_PRIMARY=$'\033[38;5;51m'    # electric cyan
	TH_SECONDARY=$'\033[38;5;201m' # hot magenta
	TH_ACCENT=$'\033[38;5;220m'    # neon yellow
	TH_MUTED=$'\033[38;5;240m'     # dark gray
	TH_SUCCESS=$'\033[38;5;46m'    # neon green
	TH_WARNING=$'\033[38;5;220m'   # neon yellow
	TH_ERROR=$'\033[38;5;196m'     # hot red
	TH_INFO=$'\033[38;5;51m'       # cyan
	TH_HIGHLIGHT=$'\033[38;5;201m' # magenta for emphasis
	TH_BAR_FILL='▓'
	TH_BAR_EMPTY='░'
	TH_BAR_MID='▒'
	TH_SCANLINE='━'
	TH_SECTION_L='◈ '
	TH_SECTION_R=' ◈'
	TH_HEADER_TOP="${TH_PRIMARY}"
	TH_HEADER_MID="${TH_SECONDARY}${BOLD}"
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
	TH_NODE_ONLINE="${TH_SUCCESS}"
	TH_NODE_OFFLINE="${TH_ERROR}"
	TH_BACKBONE='MESH BACKBONE'
	TH_FOOTER_L="NEON GRID v4.0"
	TH_FOOTER_R="CYBERPUNK TERMINAL"
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_SECONDARY}▸${NC}"
	TH_DIAMOND="${TH_SECONDARY}◈${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
