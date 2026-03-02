#!/bin/bash
# Theme: Convergio — brand gradient purple→pink→orange→gold on dark navy
# Inspired by Convergio CLI branding

_theme_convergio() {
	TH_NAME="CONVERGIO"
	TH_PRIMARY=$'\033[38;5;141m'   # lavender purple
	TH_SECONDARY=$'\033[38;5;212m' # hot pink
	TH_ACCENT=$'\033[38;5;215m'    # peach orange
	TH_MUTED=$'\033[38;5;60m'      # dark navy gray
	TH_SUCCESS=$'\033[38;5;220m'   # golden yellow
	TH_WARNING=$'\033[38;5;215m'   # peach orange
	TH_ERROR=$'\033[38;5;197m'     # hot pink-red
	TH_INFO=$'\033[38;5;141m'      # lavender
	TH_HIGHLIGHT=$'\033[38;5;212m'
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
	TH_BACKBONE='CONVERGIO NET'
	TH_FOOTER_L="CONVERGIO v6.4"
	TH_FOOTER_R="HUMAN PURPOSE · AI MOMENTUM"
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_SECONDARY}▸${NC}"
	TH_DIAMOND="${TH_ACCENT}◈${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
