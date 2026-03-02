#!/bin/bash
# Theme: Dark — minimal dark mode, muted grays and blues
# Clean, professional, easy on the eyes

_theme_dark() {
	TH_NAME="DARK MODE"
	TH_PRIMARY=$'\033[38;5;67m'   # steel blue
	TH_SECONDARY=$'\033[38;5;103m' # muted lavender
	TH_ACCENT=$'\033[38;5;180m'   # muted gold
	TH_MUTED=$'\033[38;5;239m'    # dark gray
	TH_SUCCESS=$'\033[38;5;71m'   # muted green
	TH_WARNING=$'\033[38;5;179m'  # muted amber
	TH_ERROR=$'\033[38;5;131m'    # muted red
	TH_INFO=$'\033[38;5;67m'      # steel blue
	TH_HIGHLIGHT=$'\033[38;5;180m'
	TH_BAR_FILL='━'
	TH_BAR_EMPTY='╌'
	TH_BAR_MID='─'
	TH_SCANLINE='─'
	TH_SECTION_L='● '
	TH_SECTION_R=' ●'
	TH_HEADER_TOP="${TH_PRIMARY}"
	TH_HEADER_MID="${TH_SECONDARY}${BOLD}"
	TH_BORDER_H='─'
	TH_BORDER_V='│'
	TH_CORNER_TL='╭'
	TH_CORNER_TR='╮'
	TH_CORNER_BL='╰'
	TH_CORNER_BR='╯'
	TH_INNER_H='─'
	TH_INNER_V='│'
	TH_INNER_TL='╭'
	TH_INNER_TR='╮'
	TH_INNER_BL='╰'
	TH_INNER_BR='╯'
	TH_NODE_ONLINE="${TH_SUCCESS}"
	TH_NODE_OFFLINE="${TH_ERROR}"
	TH_BACKBONE='NETWORK'
	TH_FOOTER_L="DARK MODE v4.0"
	TH_FOOTER_R="MINIMAL TERMINAL"
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_SECONDARY}▸${NC}"
	TH_DIAMOND="${TH_ACCENT}●${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
