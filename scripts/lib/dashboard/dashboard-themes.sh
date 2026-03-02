#!/bin/bash
# Dashboard design system — skinnable theme engine
# Version: 5.0.0
# Themes loaded from individual files in themes/ directory

_THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/themes"
_THEME_PERSIST="${HOME}/.claude/config/dashboard-theme"

# Source all theme files
for _tf in "$_THEME_DIR"/theme-*.sh; do
	[[ -f "$_tf" ]] && . "$_tf"
done
unset _tf

# Build THEME_LIST dynamically from discovered _theme_* functions
THEME_LIST=()
while IFS= read -r _fn; do
	_fn="${_fn#_theme_}"
	[[ -n "$_fn" ]] && THEME_LIST+=("$_fn")
done < <(declare -F | sed -n 's/^declare -f _theme_//p' | sort)
unset _fn

# Read persisted theme (if no override set)
_theme_read_persisted() {
	[[ -f "$_THEME_PERSIST" ]] && cat "$_THEME_PERSIST" 2>/dev/null || echo ""
}

# Save selected theme to persistence file
_theme_save() {
	mkdir -p "$(dirname "$_THEME_PERSIST")"
	echo "$1" > "$_THEME_PERSIST"
}

# Alias map: friendly names → internal theme function names
_theme_load() {
	local name="${1:-neon_grid}"
	# Check persistence if default
	if [[ "$name" == "neon_grid" || -z "$name" ]]; then
		local persisted
		persisted="$(_theme_read_persisted)"
		[[ -n "$persisted" ]] && name="$persisted"
	fi
	# Resolve aliases to canonical theme names
	case "$name" in
	neon* | cyber* | grid)   name="neon_grid" ;;
	synth* | retro* | wave)  name="synthwave" ;;
	ghost* | gits | shell)   name="ghost" ;;
	muthur | alien)          name="neon_grid" ;;
	nexus* | blade*)         name="synthwave" ;;
	hal* | 2001)             name="ghost" ;;
	matrix | neo)            name="matrix" ;;
	dark | minimal)          name="dark" ;;
	light | clean)           name="light" ;;
	vintage | crt | vt100 | amber) name="vintage" ;;
	tron | legacy)           name="tron" ;;
	fallout | pipboy | vault*) name="fallout" ;;
	convergio)               name="convergio" ;;
	neumorph* | soft* | neu) name="neumorph" ;;
	esac
	# Call the theme function if it exists
	if declare -f "_theme_${name}" &>/dev/null; then
		"_theme_${name}"
	else
		_theme_neon_grid
	fi
	TH_RST="${NC}"
}

# --- Themed render helpers ---

_th_scanline() {
	local w="${1:-65}" line=""
	for ((i = 0; i < w; i++)); do line+="$TH_SCANLINE"; done
	printf '%s%s%s\n' "${TH_HEADER_TOP}" "${line}" "${NC}"
}

_th_header() {
	local title="$1" subtitle="${2:-}" w=65
	_th_scanline $w
	if [[ -n "$subtitle" ]]; then
		printf " %s%s%s%s  %s%s%s\n" "${TH_HEADER_MID}" "${BOLD}" "$title" "${NC}" "${TH_MUTED}" "$subtitle" "${NC}"
	else
		printf " %s%s%s%s\n" "${TH_HEADER_MID}" "${BOLD}" "$title" "${NC}"
	fi
	_th_scanline $w
}

_th_section() {
	printf '%s%s%s%s%s%s%s%s%s %s\n' \
		"${TH_PRIMARY}" "${TH_SECTION_L}" "${BOLD}" "${WHITE}" "$1" "${NC}" \
		"${TH_PRIMARY}" "${TH_SECTION_R}" "${NC}" "${2:-}"
}

_th_box_top() {
	local w="${1:-57}" color="${2:-$TH_SECONDARY}" line=""
	for ((i = 0; i < w - 2; i++)); do line+="${TH_BORDER_H}"; done
	printf '%s%s%s%s%s\n' "${color}" "${TH_CORNER_TL}" "${line}" "${TH_CORNER_TR}" "${NC}"
}

_th_box_bot() {
	local w="${1:-57}" color="${2:-$TH_SECONDARY}" line=""
	for ((i = 0; i < w - 2; i++)); do line+="${TH_BORDER_H}"; done
	printf '%s%s%s%s%s\n' "${color}" "${TH_CORNER_BL}" "${line}" "${TH_CORNER_BR}" "${NC}"
}

_th_box_row() {
	local content="$1" w="${2:-57}" color="${3:-$TH_SECONDARY}"
	printf '%s%s%s %s %s%s%s\n' "${color}" "${TH_BORDER_V}" "${NC}" "${content}" "${color}" "${TH_BORDER_V}" "${NC}"
}

_th_bar() {
	local pct="${1:-0}" width="${2:-20}"
	local filled=$((pct * width / 100)) empty=$((width - filled))
	local bar="" ebar="" fill_color
	if [[ $pct -ge 80 ]]; then
		fill_color="${TH_SUCCESS}"
	elif [[ $pct -ge 40 ]]; then
		fill_color="${TH_WARNING}"
	else fill_color="${TH_ERROR}"; fi
	for ((i = 0; i < filled; i++)); do bar+="$TH_BAR_FILL"; done
	for ((i = 0; i < empty; i++)); do ebar+="$TH_BAR_EMPTY"; done
	printf '%s%s%s%s%s\n' "${fill_color}" "${bar}" "${GRAY}" "${ebar}" "${NC}"
}

_th_sparkline() {
	local values="$1" color="${2:-$TH_PRIMARY}"
	local chars="${TH_SPARK_CHARS:-▁▂▃▄▅▆▇█}"
	local max=1 arr=()
	IFS=',' read -ra arr <<<"$values"
	for v in "${arr[@]}"; do [[ ${v:-0} -gt $max ]] && max=$v; done
	printf '%s' "$color"
	for v in "${arr[@]}"; do
		local idx=$((${v:-0} * 7 / max))
		[[ $idx -gt 7 ]] && idx=7
		printf '%s' "${chars:$idx:1}"
	done
	printf '%s' "${NC}"
}

_th_footer() {
	local w=65
	echo ""
	_th_scanline $w
	printf '  %s%s%s  %s|%s  %spiani -h%s  %s|%s  %s%s%s\n' \
		"${TH_SECONDARY}" "${TH_FOOTER_L}" "${NC}" "${TH_MUTED}" "${NC}" \
		"${TH_MUTED}" "${NC}" "${TH_MUTED}" "${NC}" \
		"${TH_SECONDARY}" "${TH_FOOTER_R}" "${NC}"
	_th_scanline $w
}
