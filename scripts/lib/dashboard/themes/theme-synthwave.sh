#!/bin/bash
# Theme: Synthwave (Retrowave) — migrated from dashboard-themes.sh
# Purple + pink palette, 80s retro aesthetic

_theme_synthwave() {
	TH_NAME="SYNTHWAVE"
	TH_PRIMARY=$'\033[38;5;135m'   # purple
	TH_SECONDARY=$'\033[38;5;213m' # pink
	TH_ACCENT=$'\033[38;5;229m'    # warm yellow
	TH_MUTED=$'\033[38;5;242m'
	TH_SUCCESS=$'\033[38;5;48m'  # mint green
	TH_WARNING=$'\033[38;5;215m' # peach
	TH_ERROR=$'\033[38;5;197m'   # hot pink
	TH_INFO=$'\033[38;5;117m'    # light blue
	TH_HIGHLIGHT=$'\033[38;5;213m'
	TH_BAR_FILL='█'
	TH_BAR_EMPTY='░'
	TH_BAR_MID='▒'
	TH_SCANLINE='─'
	TH_SECTION_L='▸ '
	TH_SECTION_R=' ◂'
	TH_HEADER_TOP="${TH_PRIMARY}"
	TH_HEADER_MID="${TH_SECONDARY}${BOLD}"
	TH_BORDER_H='─'
	TH_BORDER_V='│'
	TH_CORNER_TL='┌'
	TH_CORNER_TR='┐'
	TH_CORNER_BL='└'
	TH_CORNER_BR='┘'
	TH_INNER_H='─'
	TH_INNER_V='│'
	TH_INNER_TL='╭'
	TH_INNER_TR='╮'
	TH_INNER_BL='╰'
	TH_INNER_BR='╯'
	TH_NODE_ONLINE="${TH_SUCCESS}"
	TH_NODE_OFFLINE="${TH_ERROR}"
	TH_BACKBONE='SYNTH LINK'
	TH_FOOTER_L="SYNTHWAVE v4.0"
	TH_FOOTER_R="RETROWAVE TERMINAL"
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_SECONDARY}▸${NC}"
	TH_DIAMOND="${TH_SECONDARY}◆${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
