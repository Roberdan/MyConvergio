#!/bin/bash
# Theme: Ghost in the Shell — migrated from dashboard-themes.sh
# Matrix green palette, cyberpunk hacker aesthetic

_theme_ghost() {
	TH_NAME="GHOST IN SHELL"
	TH_PRIMARY=$'\033[38;5;34m'   # matrix green
	TH_SECONDARY=$'\033[38;5;82m' # bright green
	TH_ACCENT=$'\033[38;5;226m'   # yellow
	TH_MUTED=$'\033[38;5;238m'
	TH_SUCCESS=$'\033[38;5;46m'
	TH_WARNING=$'\033[38;5;226m'
	TH_ERROR=$'\033[38;5;160m'
	TH_INFO=$'\033[38;5;80m'
	TH_HIGHLIGHT=$'\033[38;5;46m'
	TH_BAR_FILL='▰'
	TH_BAR_EMPTY='▱'
	TH_BAR_MID='▰'
	TH_SCANLINE='░'
	TH_SECTION_L='>> '
	TH_SECTION_R=' <<'
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
	TH_NODE_ONLINE="${TH_SECONDARY}"
	TH_NODE_OFFLINE=$'\033[38;5;88m'
	TH_BACKBONE='NET LINK'
	TH_FOOTER_L="GHOST SHELL v4.0"
	TH_FOOTER_R="SECTION 9 TERMINAL"
	TH_STATUS_PREFIX="${TH_SECONDARY}"
	TH_PLAN_BULLET="${TH_PRIMARY}▸${NC}"
	TH_DIAMOND="${TH_SECONDARY}◈${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
