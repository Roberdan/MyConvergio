#!/bin/bash
# Dashboard design system — theme engine
# Version: 2.0.0
# Themes: muthur (Alien), nexus6 (Blade Runner), hal9000 (2001)
# Usage: source this file, then call _theme_load <name>

# --- Theme variables set by _theme_load ---
# TH_NAME           — display name
# TH_PRIMARY        — main accent color
# TH_SECONDARY      — secondary accent
# TH_ACCENT         — highlight color
# TH_MUTED          — dim text
# Semantic (consistent meaning across themes):
# TH_SUCCESS        — green (done/online)
# TH_WARNING        — yellow (in_progress/warning)
# TH_ERROR          — red (error/offline)
# TH_INFO           — cyan (info)
# Outer frame (double-line for nexus6):
# TH_BORDER_H/V, TH_CORNER_{TL,TR,BL,BR}
# Inner boxes (single-line):
# TH_INNER_H/V, TH_INNER_{TL,TR,BL,BR}
# Bar/scanline chars:
# TH_BAR_FILL, TH_BAR_EMPTY, TH_SCANLINE
# Section decorators:
# TH_SECTION_L, TH_SECTION_R
# Header:
# TH_HEADER_TOP, TH_HEADER_MID
# Mesh:
# TH_NODE_ONLINE, TH_NODE_OFFLINE, TH_BACKBONE
# Footer:
# TH_FOOTER_L, TH_FOOTER_R
# Status:
# TH_STATUS_PREFIX, TH_PLAN_BULLET

_theme_muthur() {
	TH_NAME="MUTHUR 6000"
	# Green phosphor CRT (Alien 1979)
	TH_PRIMARY='\033[38;5;46m'   # bright green phosphor
	TH_SECONDARY='\033[38;5;22m' # dark green borders
	TH_ACCENT='\033[1;33m'       # yellow for coordinator
	TH_MUTED='\033[0;90m'        # gray
	# Semantic colors (consistent across all themes)
	TH_SUCCESS='\033[0;32m' # green = done/online
	TH_WARNING='\033[1;33m' # yellow = in_progress/warning
	TH_ERROR='\033[0;31m'   # red = error/offline
	TH_INFO='\033[0;36m'    # cyan = info
	# Bar + scanline
	TH_BAR_FILL='▓'
	TH_BAR_EMPTY='░'
	TH_SCANLINE='░'
	# Section decorators
	TH_SECTION_L='▐ '
	TH_SECTION_R=' ▌'
	# Header
	TH_HEADER_TOP="${TH_PRIMARY}\033[2m"
	TH_HEADER_MID="${TH_PRIMARY}\033[1m"
	# Outer border (single-line for muthur)
	TH_BORDER_H='─'
	TH_BORDER_V='│'
	TH_CORNER_TL='┌'
	TH_CORNER_TR='┐'
	TH_CORNER_BL='└'
	TH_CORNER_BR='┘'
	# Inner border (same single-line style)
	TH_INNER_H='─'
	TH_INNER_V='│'
	TH_INNER_TL='┌'
	TH_INNER_TR='┐'
	TH_INNER_BL='└'
	TH_INNER_BR='┘'
	# Mesh
	TH_NODE_ONLINE="$TH_PRIMARY"
	TH_NODE_OFFLINE='\033[0;31m'
	TH_BACKBONE='MESH BACKBONE'
	# Footer
	TH_FOOTER_L="MUTHUR INTERFACE"
	TH_FOOTER_R="NOSTROMO-CLASS TERMINAL"
	# Status display
	TH_STATUS_PREFIX="${TH_PRIMARY}\033[2m"
	TH_PLAN_BULLET="${TH_MUTED}"
}

_theme_nexus6() {
	TH_NAME="NEXUS-6"
	# Amber/orange + cyan (Blade Runner 1982)
	TH_PRIMARY='\033[38;5;214m' # amber
	TH_SECONDARY='\033[1;36m'   # bright cyan
	TH_ACCENT='\033[38;5;208m'  # orange
	TH_MUTED='\033[0;90m'       # gray
	# Semantic colors
	TH_SUCCESS='\033[0;32m'
	TH_WARNING='\033[1;33m'
	TH_ERROR='\033[0;31m'
	TH_INFO='\033[0;36m'
	# Bar + scanline
	TH_BAR_FILL='▰'
	TH_BAR_EMPTY='▱'
	TH_SCANLINE='═'
	# Section decorators
	TH_SECTION_L=''
	TH_SECTION_R=''
	# Header
	TH_HEADER_TOP="${TH_PRIMARY}"
	TH_HEADER_MID="${TH_PRIMARY}\033[1m"
	# Outer border (double-line)
	TH_BORDER_H='═'
	TH_BORDER_V='║'
	TH_CORNER_TL='╔'
	TH_CORNER_TR='╗'
	TH_CORNER_BL='╚'
	TH_CORNER_BR='╝'
	# Inner border (single-line contrast)
	TH_INNER_H='─'
	TH_INNER_V='│'
	TH_INNER_TL='┌'
	TH_INNER_TR='┐'
	TH_INNER_BL='└'
	TH_INNER_BR='┘'
	# Mesh
	TH_NODE_ONLINE="${TH_PRIMARY}"
	TH_NODE_OFFLINE='\033[0;31m'
	TH_BACKBONE='BACKBONE LINK'
	# Footer
	TH_FOOTER_L="NEXUS-6 INTERFACE"
	TH_FOOTER_R="VOIGHT-KAMPFF TERMINAL"
	# Status display
	TH_STATUS_PREFIX="${TH_PRIMARY}"
	TH_PLAN_BULLET="${TH_PRIMARY}▸${NC}"
}

_theme_hal9000() {
	TH_NAME="HAL 9000"
	# Clinical red + steel (2001: A Space Odyssey)
	TH_PRIMARY='\033[38;5;196m'   # HAL red
	TH_SECONDARY='\033[38;5;248m' # steel gray
	TH_ACCENT='\033[38;5;196m'    # red accent
	TH_MUTED='\033[38;5;244m'     # light gray
	# Semantic colors
	TH_SUCCESS='\033[0;32m'
	TH_WARNING='\033[1;33m'
	TH_ERROR='\033[0;31m'
	TH_INFO='\033[0;36m'
	# Bar + scanline
	TH_BAR_FILL='█'
	TH_BAR_EMPTY='░'
	TH_SCANLINE='━'
	# Section decorators
	TH_SECTION_L=''
	TH_SECTION_R=''
	# Header
	TH_HEADER_TOP="${TH_PRIMARY}"
	TH_HEADER_MID="${TH_SECONDARY}"
	# Outer border (single-line thin)
	TH_BORDER_H='─'
	TH_BORDER_V='│'
	TH_CORNER_TL='┌'
	TH_CORNER_TR='┐'
	TH_CORNER_BL='└'
	TH_CORNER_BR='┘'
	# Inner border (heavy line for clinical look)
	TH_INNER_H='━'
	TH_INNER_V='┃'
	TH_INNER_TL='┏'
	TH_INNER_TR='┓'
	TH_INNER_BL='┗'
	TH_INNER_BR='┛'
	# Mesh
	TH_NODE_ONLINE="${TH_SECONDARY}"
	TH_NODE_OFFLINE='\033[38;5;88m' # dark red
	TH_BACKBONE='BBK'
	# Footer
	TH_FOOTER_L="HAL 9000 INTERFACE"
	TH_FOOTER_R="DISCOVERY ONE TERMINAL"
	# Status display
	TH_STATUS_PREFIX="${TH_SECONDARY}"
	TH_PLAN_BULLET="${TH_PRIMARY}▸${NC}"
}

_theme_load() {
	local name="${1:-muthur}"
	case "$name" in
	muthur | alien) _theme_muthur ;;
	nexus6 | nexus | blade*) _theme_nexus6 ;;
	hal9000 | hal | 2001) _theme_hal9000 ;;
	*) _theme_muthur ;;
	esac
}

# --- Themed render helpers ---

_th_scanline() {
	local w="${1:-65}" line=""
	for ((i = 0; i < w; i++)); do line+="$TH_SCANLINE"; done
	echo -e "${TH_HEADER_TOP}${line}${NC}"
}

_th_header() {
	local title="$1" subtitle="${2:-}" w=65
	_th_scanline $w
	if [[ -n "$subtitle" ]]; then
		printf " ${TH_HEADER_MID}${BOLD}%s${NC}  ${TH_MUTED}%s${NC}\n" "$title" "$subtitle"
	else
		printf " ${TH_HEADER_MID}${BOLD}%s${NC}\n" "$title"
	fi
	_th_scanline $w
}

_th_section() {
	echo -e "${TH_PRIMARY}${TH_SECTION_L}${BOLD}${WHITE}$1${NC}${TH_PRIMARY}${TH_SECTION_R}${NC} ${2:-}"
}

_th_box_top() {
	local w="${1:-57}" color="${2:-$TH_SECONDARY}" line=""
	for ((i = 0; i < w - 2; i++)); do line+="${TH_BORDER_H}"; done
	echo -e "${color}${TH_CORNER_TL}${line}${TH_CORNER_TR}${NC}"
}

_th_box_bot() {
	local w="${1:-57}" color="${2:-$TH_SECONDARY}" line=""
	for ((i = 0; i < w - 2; i++)); do line+="${TH_BORDER_H}"; done
	echo -e "${color}${TH_CORNER_BL}${line}${TH_CORNER_BR}${NC}"
}

_th_box_row() {
	local content="$1" w="${2:-57}" color="${3:-$TH_SECONDARY}"
	echo -e "${color}${TH_BORDER_V}${NC} ${content} ${color}${TH_BORDER_V}${NC}"
}

_th_bar() {
	local pct="${1:-0}" width="${2:-20}"
	local filled=$((pct * width / 100))
	local empty=$((width - filled))
	local bar="" ebar="" fill_color
	if [[ $pct -ge 80 ]]; then
		fill_color="${TH_SUCCESS:-$GREEN}"
	elif [[ $pct -ge 40 ]]; then
		fill_color="${TH_WARNING:-$YELLOW}"
	else fill_color="${TH_ERROR:-$RED}"; fi
	for ((i = 0; i < filled; i++)); do bar+="$TH_BAR_FILL"; done
	for ((i = 0; i < empty; i++)); do ebar+="$TH_BAR_EMPTY"; done
	echo -e "${fill_color}${bar}${GRAY}${ebar}${NC}"
}

_th_footer() {
	local w=65
	echo ""
	_th_scanline $w
	echo -e "  ${TH_SECONDARY}${TH_FOOTER_L}${NC}  ${TH_MUTED}│${NC}  ${TH_MUTED}piani -h${NC}  ${TH_MUTED}│${NC}  ${TH_SECONDARY}${TH_FOOTER_R} v2.4${NC}"
	_th_scanline $w
}
