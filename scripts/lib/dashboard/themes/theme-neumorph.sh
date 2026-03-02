#!/bin/bash
# Theme: Neumorph — soft UI, muted blues/purples, no hard borders
# Neumorphic design: soft shadows, rounded, subtle depth

_theme_neumorph() {
	TH_NAME="NEUMORPH"
	TH_PRIMARY=$'\033[38;5;111m'   # soft blue
	TH_SECONDARY=$'\033[38;5;141m' # soft purple
	TH_ACCENT=$'\033[38;5;222m'    # warm gold
	TH_MUTED=$'\033[38;5;60m'      # slate
	TH_SUCCESS=$'\033[38;5;114m'   # soft green
	TH_WARNING=$'\033[38;5;222m'   # warm gold
	TH_ERROR=$'\033[38;5;174m'     # soft coral
	TH_INFO=$'\033[38;5;111m'      # soft blue
	TH_HIGHLIGHT=$'\033[38;5;141m'
	TH_BAR_FILL='━'
	TH_BAR_EMPTY='╌'
	TH_BAR_MID='─'
	TH_SCANLINE='─'
	TH_SECTION_L='◌ '
	TH_SECTION_R=' ◌'
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
	TH_BACKBONE='SOFT LINK'
	TH_FOOTER_L="NEUMORPH v4.0"
	TH_FOOTER_R="SOFT UI TERMINAL"
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_SECONDARY}▸${NC}"
	TH_DIAMOND="${TH_ACCENT}◌${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
