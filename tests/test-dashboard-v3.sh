#!/bin/bash
# Consolidated dashboard v3 test suite
# Version: 1.0.0
# Categories: themes, layout, rendering, Python TUI, entry point, backward compat
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$ROOT_DIR/scripts/lib/dashboard"
PASS=0 FAIL=0

pass() {
	((PASS++))
	printf "  \033[32mPASS\033[0m: %s\n" "$1"
}
fail() {
	((FAIL++))
	printf "  \033[31mFAIL\033[0m: %s\n" "$1"
}

# === 1. Theme loading ===
echo "=== THEMES ==="
source "$LIB/dashboard-config.sh"
source "$LIB/dashboard-themes.sh"
VARS="TH_PRIMARY TH_SECONDARY TH_ACCENT TH_MUTED TH_SUCCESS TH_WARNING TH_ERROR TH_INFO"
VARS+=" TH_BORDER_H TH_BORDER_V TH_INNER_H TH_INNER_V TH_BAR_FILL TH_BAR_EMPTY TH_NAME"
for theme in muthur nexus6 hal9000; do
	_theme_load "$theme"
	all_set=1
	for v in $VARS; do
		[[ -z "${!v:-}" ]] && all_set=0 && break
	done
	[[ $all_set -eq 1 ]] && pass "$theme: all TH_* vars set" || fail "$theme: missing vars"
done

# === 2. Layout helpers ===
echo ""
echo "=== LAYOUT ==="
source "$LIB/dashboard-layout.sh"
_grid_width
[[ "${GRID_W:-0}" -gt 0 ]] && pass "_grid_width GRID_W=$GRID_W" || fail "_grid_width returned 0"
[[ -n "${GRID_MODE:-}" ]] && pass "_grid_width GRID_MODE=$GRID_MODE" || fail "GRID_MODE not set"
# _grid_status_cards renders without error
_theme_load muthur
output=$(_grid_status_cards "A:1" "B:2" "C:3" "D:4" 2>&1)
[[ -n "$output" ]] && pass "_grid_status_cards renders" || fail "_grid_status_cards empty"
output=$(_grid_header "TEST" 2>&1)
[[ -n "$output" ]] && pass "_grid_header renders" || fail "_grid_header empty"
output=$(_grid_progress_bar 50 10 2>&1)
[[ -n "$output" ]] && pass "_grid_progress_bar renders" || fail "_grid_progress_bar empty"

# === 3. Rendering modules: source + function exists ===
echo ""
echo "=== RENDERING MODULES ==="
MODULES=(
	"dashboard-render-overview.sh:_render_overview"
	"dashboard-render-active-plans.sh:_render_active_plans"
	"dashboard-render-pipeline-plans.sh:_render_pipeline_plans"
	"dashboard-render-completed-plans.sh:_render_completed_plans"
	"dashboard-render.sh:render_dashboard"
	"dashboard-render-waves.sh:_render_plan_waves"
	"dashboard-render-prs.sh:_render_plan_prs"
	"dashboard-render-mesh.sh:_render_mesh_mini"
	"dashboard-render-mesh-detail.sh:_render_mesh_detail"
	"dashboard-mesh-actions.sh:_mesh_action_sync"
	"dashboard-render-tokens.sh:_render_token_analytics"
	"dashboard-navigation.sh:_run_interactive_loop"
	"dashboard-db.sh:dbq"
	"../dashboard-delegation.sh:render_delegation_stats"
)
for entry in "${MODULES[@]}"; do
	IFS=':' read -r file func <<<"$entry"
	if [[ -f "$LIB/$file" ]]; then
		bash -n "$LIB/$file" 2>/dev/null && pass "$file syntax OK" || fail "$file syntax error"
		# Source and check function exists (in subshell to avoid pollution)
		(
			source "$LIB/dashboard-config.sh" 2>/dev/null || true
			source "$LIB/dashboard-themes.sh" 2>/dev/null || true
			_theme_load muthur 2>/dev/null || true
			source "$LIB/dashboard-layout.sh" 2>/dev/null || true
			source "$LIB/dashboard-db.sh" 2>/dev/null || true
			source "$LIB/$file" 2>/dev/null || true
			declare -f "$func" >/dev/null 2>&1 && exit 0 || exit 1
		) && pass "$file: $func() exists" || fail "$file: $func() missing"
	else
		fail "$file not found"
	fi
done

# === 4. Python TUI imports ===
echo ""
echo "=== PYTHON TUI ==="
PYTHON="${PYTHON:-/opt/homebrew/bin/python3}"
if command -v "$PYTHON" &>/dev/null; then
	cd "$ROOT_DIR/scripts"
	$PYTHON -c "from dashboard_textual.models import Plan, Wave, Task, Peer, TokenStats" 2>/dev/null &&
		pass "Python models import" || fail "Python models import"
	$PYTHON -c "from dashboard_textual.db import DashboardDB" 2>/dev/null &&
		pass "Python db import" || fail "Python db import"
	$PYTHON -c "from dashboard_textual.app import ControlCenterApp" 2>/dev/null &&
		pass "Python app import" || fail "Python app import"
	$PYTHON -c "
from dashboard_textual.widgets import (
    OverviewWidget, ActivePlansWidget, PlanDetailWidget,
    MeshWidget, TokenSparkline, CostGauge, ModelBreakdown,
    TaskCompletionChart, StatusBar
)" 2>/dev/null && pass "Python widgets import" || fail "Python widgets import"
	cd "$ROOT_DIR"
else
	fail "Python3 not found at $PYTHON"
fi

# === 5. Entry point ===
echo ""
echo "=== ENTRY POINT ==="
grep -q '\-\-tui' "$ROOT_DIR/scripts/dashboard-mini.sh" &&
	pass "dashboard-mini.sh has --tui flag" || fail "dashboard-mini.sh missing --tui"
bash -n "$ROOT_DIR/scripts/dashboard-mini.sh" &&
	pass "dashboard-mini.sh syntax OK" || fail "dashboard-mini.sh syntax error"
[[ -x "$ROOT_DIR/scripts/dashboard-mini.sh" ]] &&
	pass "dashboard-mini.sh is executable" || fail "dashboard-mini.sh not executable"

# === 6. Line count limits ===
echo ""
echo "=== LINE COUNTS ==="
for f in "$ROOT_DIR/scripts/dashboard-mini.sh" "$LIB"/dashboard-*.sh; do
	local_lines=$(wc -l <"$f" | tr -d ' ')
	local_name=$(basename "$f")
	[[ $local_lines -le 250 ]] && pass "$local_name: $local_lines lines" ||
		fail "$local_name: $local_lines lines (>250)"
done

echo ""
echo "=== RESULTS: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
