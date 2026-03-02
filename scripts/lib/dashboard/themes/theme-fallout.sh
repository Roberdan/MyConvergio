#!/bin/bash
# Theme: Fallout — Pip-Boy green/amber, post-apocalyptic aesthetic
# Inspired by Fallout series Pip-Boy 3000

_theme_fallout() {
	TH_NAME="PIP-BOY 3000"
	TH_PRIMARY=$'\033[38;5;118m'  # pip-boy green
	TH_SECONDARY=$'\033[38;5;148m' # sage green
	TH_ACCENT=$'\033[38;5;178m'  # amber
	TH_MUTED=$'\033[38;5;58m'    # dark olive
	TH_SUCCESS=$'\033[38;5;118m' # pip-boy green
	TH_WARNING=$'\033[38;5;178m' # amber
	TH_ERROR=$'\033[38;5;160m'   # red
	TH_INFO=$'\033[38;5;114m'    # light green
	TH_HIGHLIGHT=$'\033[38;5;178m'
	TH_BAR_FILL='█'
	TH_BAR_EMPTY='░'
	TH_BAR_MID='▒'
	TH_SCANLINE='▓'
	TH_SECTION_L='>> '
	TH_SECTION_R=' <<'
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
	TH_NODE_ONLINE="${TH_PRIMARY}"
	TH_NODE_OFFLINE="${TH_ERROR}"
	TH_BACKBONE='VAULT-TEC NET'
	TH_FOOTER_L="ROBCO INDUSTRIES v4.0"
	TH_FOOTER_R="VAULT-TEC TERMINAL"
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_SECONDARY}▸${NC}"
	TH_DIAMOND="${TH_ACCENT}◈${NC}"
	TH_SPARK_CHARS='▁▂▃▄▅▆▇█'
}
