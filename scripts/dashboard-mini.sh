#!/bin/bash
# Version: 3.0.0
set -o pipefail
DASHBOARD_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/dashboard"

# Source modules in dependency order
. "$(dirname "${BASH_SOURCE[0]}")/lib/dashboard-delegation.sh"
. "$DASHBOARD_LIB/dashboard-config.sh"
. "$DASHBOARD_LIB/dashboard-themes.sh"
. "$DASHBOARD_LIB/dashboard-layout.sh"
. "$DASHBOARD_LIB/dashboard-db.sh"
. "$DASHBOARD_LIB/dashboard-sync.sh"
. "$DASHBOARD_LIB/dashboard-render-prs.sh"
. "$DASHBOARD_LIB/dashboard-render-waves.sh"
. "$DASHBOARD_LIB/dashboard-render.sh"
. "$DASHBOARD_LIB/dashboard-render-active-plans.sh"
. "$DASHBOARD_LIB/dashboard-render-pipeline-plans.sh"
. "$DASHBOARD_LIB/dashboard-render-completed-plans.sh"
. "$DASHBOARD_LIB/dashboard-render-overview.sh"
. "$DASHBOARD_LIB/dashboard-render-mesh.sh"
. "$DASHBOARD_LIB/dashboard-render-mesh-detail.sh" 2>/dev/null || true
. "$DASHBOARD_LIB/dashboard-mesh-actions.sh"
[[ -f "$DASHBOARD_LIB/dashboard-render-tokens.sh" ]] && . "$DASHBOARD_LIB/dashboard-render-tokens.sh"
. "$DASHBOARD_LIB/dashboard-navigation.sh"

cmd_waves() {
	local plan_id="${1:?plan_id required}"
	local live_prs=0
	shift
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--prs) live_prs=1 ;;
		esac
		shift
	done

	local DB_FILE="$HOME/.claude/data/dashboard.db"
	echo "=== Wave Worktrees — Plan $plan_id ==="
	echo ""

	local rows
	rows=$(sqlite3 -separator '|' "$DB_FILE" \
		"SELECT w.wave_id, w.name, w.status, w.tasks_done||'/'||w.tasks_total,
                COALESCE(w.branch_name, '-'), COALESCE(CAST(w.pr_number AS TEXT), '-'),
                COALESCE(w.pr_url, '-'),
                COALESCE(w.worktree_path, '-')
         FROM waves w WHERE w.plan_id = $plan_id ORDER BY w.position;" 2>/dev/null)

	if [[ -z "$rows" ]]; then
		echo "No waves found for plan $plan_id"
		return 0
	fi

	printf "%-6s %-12s %-6s %-24s %-8s %-30s %s\n" \
		"Wave" "Status" "Tasks" "Branch" "PR" "Worktree" "Clean"
	printf "%-6s %-12s %-6s %-24s %-8s %-30s %s\n" \
		"------" "------------" "------" "------------------------" "--------" "------------------------------" "-----"

	while IFS='|' read -r wid name status tasks branch pr pr_url wt_path; do
		local clean="-"
		if [[ "$wt_path" != "-" ]]; then
			local expanded="${wt_path/#\~/$HOME}"
			if [[ -d "$expanded" ]]; then
				local dirty
				dirty=$(git -C "$expanded" status --porcelain 2>/dev/null | head -1 || true)
				[[ -z "$dirty" ]] && clean="Clean" || clean="Dirty"
			else
				clean="Gone"
			fi
		fi

		local pr_display="$pr"
		local pr_extra=""
		if [[ "$pr" != "-" && "$pr_url" == https://* ]]; then
			pr_display="#${pr}"
			pr_extra=" $pr_url"
			if [[ "$status" == "in_progress" || "$status" == "merging" ]]; then
				if [[ "$live_prs" -eq 1 ]]; then
					local ci_state
					ci_state=$(gh api "repos/{owner}/{repo}/pulls/${pr}" \
						--jq '.mergeable_state' 2>/dev/null || echo "?")
					pr_extra="${pr_extra} [${ci_state}]"
				fi
			fi
		fi

		printf "%-6s %-12s %-6s %-24s %-8s %-30s %s%s\n" \
			"$wid" "$status" "$tasks" "$branch" "$pr_display" "$wt_path" "$clean" "$pr_extra"
	done <<<"$rows"
}

# Subcommand dispatch
case "${1:-}" in
waves)
	shift
	cmd_waves "$@"
	exit 0
	;;
esac

# Parse arguments
VERBOSE=0
PLAN_ID=""
SHOW_BLOCKED=0
REFRESH_INTERVAL=300
EXPAND_COMPLETED=0
DASHBOARD_THEME="${DASHBOARD_THEME:-neon_grid}"
USE_TUI=0
USE_WEB=1
USE_BASH=0
WEB_PORT=8420

while [[ $# -gt 0 ]]; do
	case $1 in
	-v | --verbose)
		VERBOSE=1
		shift
		;;
	-p | --plan)
		PLAN_ID="$2"
		shift 2
		;;
	-b | --blocked)
		SHOW_BLOCKED=1
		shift
		;;
	-r | --refresh)
		REFRESH_INTERVAL="$2"
		shift 2
		;;
	-n | --no-refresh)
		REFRESH_INTERVAL=0
		shift
		;;
	-e | --expand)
		EXPAND_COMPLETED=1
		shift
		;;
	-t | --theme)
		DASHBOARD_THEME="$2"
		shift 2
		;;
	--tui | --textual)
		USE_TUI=1
		USE_WEB=0
		shift
		;;
	--web)
		USE_WEB=1
		shift
		;;
	--web-port)
		USE_WEB=1
		WEB_PORT="$2"
		shift 2
		;;
	--bash | --terminal)
		USE_WEB=0
		USE_BASH=1
		shift
		;;
	-h | --help)
		echo "Usage: piani [OPTIONS]"
		echo "       piani waves <plan_id> [--prs]"
		echo ""
		echo "Subcommands:"
		echo "  waves <plan_id> [--prs]   Show wave worktrees; --prs fetches live CI state"
		echo ""
		echo "Options:"
		echo "  -v, --verbose        Show extra details (wave names, task priorities)"
		echo "  -p, --plan ID        Show specific plan only"
		echo "  -b, --blocked        Show blocked tasks"
		echo "  -e, --expand         Expand completed task details"
		echo "  -t, --theme THEME    Theme (default: neon_grid, or persisted)"
		echo "  -r, --refresh SEC    Auto-refresh every SEC seconds (default: 300)"
		echo "  -n, --no-refresh     Disable auto-refresh (single render)"
		echo "  --tui                Launch Textual TUI (requires Python)"
		echo "  --web                Launch web dashboard — DEFAULT (http://localhost:8420)"
		echo "  --web-port PORT      Web dashboard on custom port"
		echo "  --bash, --terminal   Classic bash terminal dashboard"
		echo "  -h, --help           Show this help"
		echo ""
		echo "Themes (9 skins):"
		echo "  neon_grid (alias: muthur, alien, cyberpunk)  — Cyberpunk neon cyan/magenta"
		echo "  synthwave (alias: nexus6, blade, retro)      — Synthwave purple/pink"
		echo "  ghost     (alias: hal9000, gits, 2001)       — Ghost in the Shell green"
		echo "  matrix    (alias: neo)                       — The Matrix digital rain"
		echo "  dark      (alias: minimal)                   — Minimal dark mode"
		echo "  light     (alias: clean)                     — Light mode for bright terminals"
		echo "  vintage   (alias: crt, vt100, amber)         — Amber CRT 80s terminal"
		echo "  tron      (alias: legacy)                    — TRON Legacy blue/orange"
		echo "  fallout   (alias: pipboy, vault)             — Pip-Boy post-apocalyptic"
		echo "  convergio                                    — Convergio brand gradient"
		echo ""
		echo "Navigation:"
		echo "  R=refresh  C=completed  M=mesh  B=back  Q=quit"
		echo "  T=cycle theme  A=token analytics  P=push  L=linux"
		echo "  <num>+Enter = drill-down plan"
		echo ""
		echo "Examples:"
		echo "  piani                 # Dashboard with auto-refresh"
		echo "  piani --tui           # Textual TUI mode"
		echo "  piani --web           # Web dashboard (browser)"
		echo "  piani -t matrix       # Matrix digital rain style"
		echo "  piani -t vintage      # Amber CRT 80s terminal"
		echo "  piani -t tron         # TRON Legacy style"
		echo "  piani -t fallout      # Pip-Boy Vault-Tec style"
		echo "  piani -n              # Single render, no refresh"
		echo "  piani -p 62           # Plan #62 detail"
		echo "  piani -r 60           # Refresh every minute"
		exit 0
		;;
	*)
		echo "Unknown option: $1"
		exit 1
		;;
	esac
done

# Validate PLAN_ID
if [ -n "$PLAN_ID" ] && ! [[ "$PLAN_ID" =~ ^[0-9]+$ ]]; then
	echo "Error: plan ID must be numeric" >&2
	exit 1
fi

# TUI mode: delegate to Python Textual app
if [[ "$USE_TUI" -eq 1 ]]; then
	SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	PYTHONPATH="$SCRIPTS_DIR:${PYTHONPATH:-}" exec /opt/homebrew/bin/python3 -m dashboard_textual ${PLAN_ID:+--plan "$PLAN_ID"}
fi

# Web mode: launch terminal server + web server + open browser
if [[ "$USE_WEB" -eq 1 ]]; then
	SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	/opt/homebrew/bin/python3 "$SCRIPTS_DIR/dashboard_web/terminal_server.py" --port 8421 &
	TERM_PID=$!
	trap "kill $TERM_PID 2>/dev/null" EXIT
	open "http://localhost:${WEB_PORT}"
	exec /opt/homebrew/bin/python3 "$SCRIPTS_DIR/dashboard_web/server.py" --port "$WEB_PORT"
fi

# terminui theme: delegate to TypeScript renderer
if [[ "$DASHBOARD_THEME" == "terminui" ]]; then
	DASHBOARD_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib/dashboard"
	. "$DASHBOARD_LIB_DIR/dashboard-data-json.sh"
	_extract_dashboard_json | npx tsx "$(dirname "${BASH_SOURCE[0]}")/dashboard-terminui.tsx"
	exit $?
fi

# Load theme
_theme_load "$DASHBOARD_THEME"

# Single plan detail mode: always expand tasks
if [ -n "$PLAN_ID" ]; then
	EXPAND_COMPLETED=1
fi

# Interactive or single-shot
if [ "$REFRESH_INTERVAL" -gt 0 ]; then
	_run_interactive_loop
else
	if [ -n "$PLAN_ID" ]; then
		VIEW_MODE="detail"
		VIEW_PLAN_ID="$PLAN_ID"
	fi
	quick_sync
	_render_current_view
fi
