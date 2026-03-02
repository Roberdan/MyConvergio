#!/bin/bash
# Tests for dashboard design system (themes + config)
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

pass() {
	((PASS++))
	((TOTAL++))
	printf "  PASS: %s\n" "$1"
}
fail() {
	((FAIL++))
	((TOTAL++))
	printf "  FAIL: %s\n" "$1"
}

assert_set() {
	local var_name="$1" label="${2:-$1}"
	if [[ -n "${!var_name:-}" ]]; then pass "$label"; else fail "$label (empty)"; fi
}

assert_eq() {
	local actual="$1" expected="$2" label="$3"
	if [[ "$actual" == "$expected" ]]; then pass "$label"; else fail "$label: got '$actual', want '$expected'"; fi
}

# --- dashboard-config.sh tests ---
echo "=== dashboard-config.sh ==="

source "$ROOT_DIR/scripts/lib/dashboard/dashboard-config.sh"

assert_set "DB" "DB path defined"
assert_set "RED" "RED color defined"
assert_set "GREEN" "GREEN color defined"
assert_set "YELLOW" "YELLOW color defined"
assert_set "CYAN" "CYAN color defined"
assert_set "WHITE" "WHITE color defined"
assert_set "GRAY" "GRAY color defined"
assert_set "NC" "NC reset defined"
assert_set "BOLD" "BOLD defined"
assert_set "DASHBOARD_LIB" "DASHBOARD_LIB path defined"

# --- dashboard-themes.sh tests ---
echo ""
echo "=== dashboard-themes.sh ==="

source "$ROOT_DIR/scripts/lib/dashboard/dashboard-themes.sh"

# Semantic color vars per theme
THEMES="muthur nexus6 hal9000"
SEMANTIC_VARS="TH_PRIMARY TH_SECONDARY TH_ACCENT TH_MUTED TH_SUCCESS TH_WARNING TH_ERROR TH_INFO"
BORDER_VARS="TH_BORDER_H TH_BORDER_V TH_CORNER_TL TH_CORNER_TR TH_CORNER_BL TH_CORNER_BR"
INNER_BORDER_VARS="TH_INNER_H TH_INNER_V TH_INNER_TL TH_INNER_TR TH_INNER_BL TH_INNER_BR"
BAR_VARS="TH_BAR_FILL TH_BAR_EMPTY TH_SCANLINE"
META_VARS="TH_NAME TH_NODE_ONLINE TH_NODE_OFFLINE TH_BACKBONE TH_FOOTER_L TH_FOOTER_R"

for theme in $THEMES; do
	echo ""
	echo "--- Theme: $theme ---"
	_theme_load "$theme"

	for v in $SEMANTIC_VARS; do assert_set "$v" "$theme: $v"; done
	for v in $BORDER_VARS; do assert_set "$v" "$theme: $v (outer)"; done
	for v in $INNER_BORDER_VARS; do assert_set "$v" "$theme: $v (inner)"; done
	for v in $BAR_VARS; do assert_set "$v" "$theme: $v"; done
	for v in $META_VARS; do assert_set "$v" "$theme: $v"; done
done

# Semantic color consistency: green=success, yellow=warning, red=error, cyan=info
echo ""
echo "--- Semantic color consistency ---"

_theme_load muthur
# TH_SUCCESS should contain green ANSI (32 or 38;5;46 etc)
[[ "$TH_SUCCESS" == *"32"* || "$TH_SUCCESS" == *"46"* ]] && pass "muthur: TH_SUCCESS is green" || fail "muthur: TH_SUCCESS not green"
[[ "$TH_WARNING" == *"33"* || "$TH_WARNING" == *"214"* || "$TH_WARNING" == *"208"* ]] && pass "muthur: TH_WARNING is yellow" || fail "muthur: TH_WARNING not yellow"
[[ "$TH_ERROR" == *"31"* || "$TH_ERROR" == *"196"* ]] && pass "muthur: TH_ERROR is red" || fail "muthur: TH_ERROR not red"
[[ "$TH_INFO" == *"36"* || "$TH_INFO" == *"39"* || "$TH_INFO" == *"51"* ]] && pass "muthur: TH_INFO is cyan" || fail "muthur: TH_INFO not cyan"

_theme_load nexus6
[[ "$TH_SUCCESS" == *"32"* || "$TH_SUCCESS" == *"46"* ]] && pass "nexus6: TH_SUCCESS is green" || fail "nexus6: TH_SUCCESS not green"
[[ "$TH_ERROR" == *"31"* || "$TH_ERROR" == *"196"* ]] && pass "nexus6: TH_ERROR is red" || fail "nexus6: TH_ERROR not red"

_theme_load hal9000
[[ "$TH_SUCCESS" == *"32"* || "$TH_SUCCESS" == *"46"* ]] && pass "hal9000: TH_SUCCESS is green" || fail "hal9000: TH_SUCCESS not green"
[[ "$TH_ERROR" == *"31"* || "$TH_ERROR" == *"196"* ]] && pass "hal9000: TH_ERROR is red" || fail "hal9000: TH_ERROR not red"

# Theme aliases
echo ""
echo "--- Theme aliases ---"
_theme_load alien
assert_eq "$TH_NAME" "MUTHUR 6000" "alias 'alien' loads muthur"
_theme_load nexus
assert_eq "$TH_NAME" "NEXUS-6" "alias 'nexus' loads nexus6"
_theme_load hal
assert_eq "$TH_NAME" "HAL 9000" "alias 'hal' loads hal9000"
_theme_load 2001
assert_eq "$TH_NAME" "HAL 9000" "alias '2001' loads hal9000"

# Outer vs inner border chars differ for nexus6 (double vs single)
echo ""
echo "--- Border differentiation ---"
_theme_load nexus6
[[ "$TH_BORDER_H" != "$TH_INNER_H" || "$TH_BORDER_V" != "$TH_INNER_V" ]] && pass "nexus6: outer != inner borders" || fail "nexus6: outer == inner borders"

# Helper functions exist
echo ""
echo "--- Helper functions ---"
declare -f _th_scanline >/dev/null && pass "_th_scanline exists" || fail "_th_scanline missing"
declare -f _th_header >/dev/null && pass "_th_header exists" || fail "_th_header missing"
declare -f _th_section >/dev/null && pass "_th_section exists" || fail "_th_section missing"
declare -f _th_box_top >/dev/null && pass "_th_box_top exists" || fail "_th_box_top missing"
declare -f _th_box_bot >/dev/null && pass "_th_box_bot exists" || fail "_th_box_bot missing"
declare -f _th_box_row >/dev/null && pass "_th_box_row exists" || fail "_th_box_row missing"
declare -f _th_bar >/dev/null && pass "_th_bar exists" || fail "_th_bar missing"
declare -f _th_footer >/dev/null && pass "_th_footer exists" || fail "_th_footer missing"

# File size < 250 lines
echo ""
echo "--- File constraints ---"
themes_lines=$(wc -l <"$ROOT_DIR/scripts/lib/dashboard/dashboard-themes.sh")
config_lines=$(wc -l <"$ROOT_DIR/scripts/lib/dashboard/dashboard-config.sh")
[[ $themes_lines -le 250 ]] && pass "themes.sh <= 250 lines ($themes_lines)" || fail "themes.sh > 250 lines ($themes_lines)"
[[ $config_lines -le 250 ]] && pass "config.sh <= 250 lines ($config_lines)" || fail "config.sh > 250 lines ($config_lines)"

# Syntax check
bash -n "$ROOT_DIR/scripts/lib/dashboard/dashboard-themes.sh" && pass "themes.sh syntax OK" || fail "themes.sh syntax error"
bash -n "$ROOT_DIR/scripts/lib/dashboard/dashboard-config.sh" && pass "config.sh syntax OK" || fail "config.sh syntax error"

echo ""
echo "=== RESULTS: $PASS/$TOTAL passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
