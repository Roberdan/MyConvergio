#!/bin/bash
# Theme: Matrix — digital rain, green-on-black hacker aesthetic
# Inspired by The Matrix (1999)

_theme_matrix() {
	TH_NAME="THE MATRIX"
	TH_PRIMARY=$'\033[38;5;46m'  # bright green
	TH_SECONDARY=$'\033[38;5;34m' # dark green
	TH_ACCENT=$'\033[38;5;82m'   # lime green
	TH_MUTED=$'\033[38;5;22m'    # very dark green
	TH_SUCCESS=$'\033[38;5;46m'  # bright green
	TH_WARNING=$'\033[38;5;226m' # yellow
	TH_ERROR=$'\033[38;5;196m'   # red
	TH_INFO=$'\033[38;5;40m'     # medium green
	TH_HIGHLIGHT=$'\033[38;5;46m'
	TH_BAR_FILL='█'
	TH_BAR_EMPTY='·'
	TH_BAR_MID='▓'
	TH_SCANLINE='░'
	TH_SECTION_L='> '
	TH_SECTION_R=' <'
	TH_HEADER_TOP="${TH_PRIMARY}${DIM}"
	TH_HEADER_MID="${TH_PRIMARY}${BOLD}"
	TH_BORDER_H='-'
	TH_BORDER_V='|'
	TH_CORNER_TL='+'
	TH_CORNER_TR='+'
	TH_CORNER_BL='+'
	TH_CORNER_BR='+'
	TH_INNER_H='-'
	TH_INNER_V='|'
	TH_INNER_TL='+'
	TH_INNER_TR='+'
	TH_INNER_BL='+'
	TH_INNER_BR='+'
	TH_NODE_ONLINE="${TH_PRIMARY}"
	TH_NODE_OFFLINE=$'\033[38;5;88m'
	TH_BACKBONE='MATRIX LINK'
	TH_FOOTER_L="THE MATRIX v4.0"
	TH_FOOTER_R="FOLLOW THE WHITE RABBIT"
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_SECONDARY}▸${NC}"
	TH_DIAMOND="${TH_PRIMARY}◈${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
