#!/bin/bash
# test-dashboard-themes.sh — Verify all dashboard themes load correctly
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_DIR="$SCRIPT_DIR/scripts/lib/dashboard/themes"
PASS=0 FAIL=0

ok() { echo "  ✓ $*"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL + 1)); }

echo "=== Dashboard Theme Tests ==="
echo ""

# Source config (needed for $BOLD, $NC, $DIM)
source "$SCRIPT_DIR/scripts/lib/dashboard/dashboard-config.sh"
source "$SCRIPT_DIR/scripts/lib/dashboard/dashboard-themes.sh"

# T1: Theme files exist
echo "--- Theme files ---"
for name in neon-grid synthwave ghost matrix dark light vintage tron fallout convergio; do
	f="$THEME_DIR/theme-${name}.sh"
	[[ -f "$f" ]] && ok "$f exists" || fail "$f MISSING"
done

# T2: Each theme defines all required TH_ variables
echo ""
echo "--- TH_ variable completeness ---"
REQUIRED_VARS="TH_NAME TH_PRIMARY TH_SECONDARY TH_ACCENT TH_MUTED TH_SUCCESS TH_WARNING TH_ERROR TH_INFO TH_HIGHLIGHT TH_BAR_FILL TH_BAR_EMPTY TH_BAR_MID TH_SCANLINE TH_SECTION_L TH_SECTION_R TH_HEADER_TOP TH_HEADER_MID TH_BORDER_H TH_BORDER_V TH_CORNER_TL TH_CORNER_TR TH_CORNER_BL TH_CORNER_BR TH_INNER_H TH_INNER_V TH_INNER_TL TH_INNER_TR TH_INNER_BL TH_INNER_BR TH_NODE_ONLINE TH_NODE_OFFLINE TH_BACKBONE TH_FOOTER_L TH_FOOTER_R TH_STATUS_PREFIX TH_PLAN_BULLET TH_DIAMOND TH_SPARK_CHARS"

for theme in "${THEME_LIST[@]}"; do
	_theme_load "$theme"
	missing=0
	for var in $REQUIRED_VARS; do
		[[ -z "${!var:-}" ]] && { missing=$((missing + 1)); echo "    MISSING: $var in $theme"; }
	done
	[[ $missing -eq 0 ]] && ok "$theme: all 39 TH_ vars defined" || fail "$theme: $missing vars missing"
done

# T3: Aliases resolve correctly
echo ""
echo "--- Alias resolution ---"
_check_alias() {
	local alias="$1" expected="$2"
	_theme_load "$alias"
	[[ "$TH_NAME" == "$expected" ]] && ok "alias $alias → $TH_NAME" \
		|| fail "alias $alias: expected $expected, got $TH_NAME"
}
_check_alias muthur "NEON GRID"
_check_alias alien "NEON GRID"
_check_alias nexus6 "SYNTHWAVE"
_check_alias blade "SYNTHWAVE"
_check_alias hal9000 "GHOST IN SHELL"
_check_alias gits "GHOST IN SHELL"
_check_alias matrix "THE MATRIX"
_check_alias neo "THE MATRIX"
_check_alias dark "DARK MODE"
_check_alias minimal "DARK MODE"
_check_alias light "LIGHT MODE"
_check_alias clean "LIGHT MODE"
_check_alias vintage "VINTAGE CRT"
_check_alias crt "VINTAGE CRT"
_check_alias vt100 "VINTAGE CRT"
_check_alias amber "VINTAGE CRT"
_check_alias tron "TRON SYSTEM"
_check_alias legacy "TRON SYSTEM"
_check_alias fallout "PIP-BOY 3000"
_check_alias pipboy "PIP-BOY 3000"
_check_alias convergio "CONVERGIO"

# T4: THEME_LIST has all 10 themes
echo ""
echo "--- THEME_LIST ---"
[[ ${#THEME_LIST[@]} -eq 10 ]] && ok "THEME_LIST has 10 themes" || fail "THEME_LIST has ${#THEME_LIST[@]} (expected 10)"

# T5: Persistence read/write
echo ""
echo "--- Persistence ---"
_PERSIST_FILE="${HOME}/.claude/config/dashboard-theme-test"
_THEME_PERSIST="$_PERSIST_FILE"
_theme_save "tron"
got=$(_theme_read_persisted)
[[ "$got" == "tron" ]] && ok "Persistence write/read" || fail "Persistence: wrote tron, read $got"
rm -f "$_PERSIST_FILE"

# T6: File line counts (max 250)
echo ""
echo "--- Line counts ---"
for f in "$THEME_DIR"/theme-*.sh "$SCRIPT_DIR/scripts/lib/dashboard/dashboard-themes.sh"; do
	lines=$(wc -l < "$f")
	[[ $lines -le 250 ]] && ok "$(basename $f): $lines lines" || fail "$(basename $f): $lines lines (>250!)"
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
