#!/bin/bash
# Version: 2.3.0
set -uo pipefail
# Source all dashboard modules
DASHBOARD_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/dashboard"

# Source delegation module (using BASH_SOURCE-relative path)
. "$(dirname "${BASH_SOURCE[0]}")/lib/dashboard-delegation.sh"
. "$DASHBOARD_LIB/dashboard-config.sh"
. "$DASHBOARD_LIB/dashboard-sync.sh"
. "$DASHBOARD_LIB/dashboard-db.sh"
. "$DASHBOARD_LIB/dashboard-render-prs.sh"
. "$DASHBOARD_LIB/dashboard-render-waves.sh"
. "$DASHBOARD_LIB/dashboard-render.sh"
. "$DASHBOARD_LIB/dashboard-render-active-plans.sh"
. "$DASHBOARD_LIB/dashboard-render-pipeline-plans.sh"
. "$DASHBOARD_LIB/dashboard-render-completed-plans.sh"
. "$DASHBOARD_LIB/dashboard-render-overview.sh"
. "$DASHBOARD_LIB/dashboard-themes.sh"
. "$DASHBOARD_LIB/dashboard-render-mesh.sh"
. "$DASHBOARD_LIB/dashboard-render-mesh-detail.sh" 2>/dev/null || true
. "$DASHBOARD_LIB/dashboard-mesh-actions.sh"
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

		# PR display: plain text with URL (auto-clickable in most terminals)
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

# Subcommand dispatch (must come before flag parsing)
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
DASHBOARD_THEME="${DASHBOARD_THEME:-muthur}"

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
	-h | --help)
		echo "Usage: piani [OPTIONS]"
		echo "       piani waves <plan_id> [--prs]"
		echo ""
		echo "Subcommands:"
		echo "  waves <plan_id> [--prs]   Show wave worktrees; --prs fetches live CI state"
		echo ""
		echo "Options:"
		echo "  -v, --verbose        Mostra dettagli extra (wave names, task priorities)"
		echo "  -p, --plan ID        Mostra solo piano specifico"
		echo "  -b, --blocked        Mostra task bloccati"
		echo "  -e, --expand         Espandi dettagli task completati (default: compressi)"
		echo "  -t, --theme THEME    Tema: muthur|nexus6|hal9000|terminui (default: muthur)"
		echo "  -r, --refresh SEC    Auto-refresh ogni SEC secondi (default: 300)"
		echo "  -n, --no-refresh     Disabilita auto-refresh (vista singola)"
		echo "  -h, --help           Mostra questo help"
		echo ""
		echo "Sezioni mostrate:"
		echo "  - Overview: conteggi totali (todo/doing/done)"
		echo "  - Piani Attivi: in esecuzione con progress e PR"
		echo "  - In Pipeline: piani creati ma non ancora lanciati"
		echo "  - Completamenti: ultime 24 ore"
		echo ""
		echo "Temi disponibili:"
		echo "  muthur   — Green phosphor CRT (Alien 1979)"
		echo "  nexus6   — Amber/cyan neon (Blade Runner 1982)"
		echo "  hal9000  — Clinical red/steel (2001: A Space Odyssey)"
		echo "  terminui — Rich TUI via terminui (requires Node.js)"
		echo ""
		echo "Navigazione interattiva:"
		echo "  R=refresh  C=completati  B=back  Q=quit  P=push  L=linux  T=tema"
		echo "  <numero>+Enter = drill-down piano (input live)"
		echo ""
		echo "Esempi:"
		echo "  piani                 # Dashboard compatta con auto-refresh"
		echo "  piani -t nexus6       # Stile Blade Runner"
		echo "  piani -t terminui     # Rich TUI con terminui"
		echo "  piani -n              # Vista singola, no refresh"
		echo "  piani -v              # Verbose + auto-refresh"
		echo "  piani -p 62           # Solo Piano #62 + auto-refresh"
		echo "  piani -r 60           # Auto-refresh ogni minuto"
		echo "  piani -v -e -r 120    # Tutto espanso, refresh ogni 2 minuti"
		exit 0
		;;
	*)
		echo "Unknown option: $1"
		exit 1
		;;
	esac
done

# Validate PLAN_ID is numeric (prevent SQL injection)
if [ -n "$PLAN_ID" ] && ! [[ "$PLAN_ID" =~ ^[0-9]+$ ]]; then
	echo "Error: plan ID must be numeric" >&2
	exit 1
fi

# Load theme
_theme_load "$DASHBOARD_THEME"

# terminui theme: delegate to TypeScript renderer
if [[ "$DASHBOARD_THEME" == "terminui" ]]; then
	DASHBOARD_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib/dashboard"
	. "$DASHBOARD_LIB_DIR/dashboard-data-json.sh"
	_extract_dashboard_json | npx tsx "$(dirname "${BASH_SOURCE[0]}")/dashboard-terminui.tsx"
	exit $?
fi

# Single plan detail mode: always expand tasks
if [ -n "$PLAN_ID" ]; then
	EXPAND_COMPLETED=1
fi

# Interactive or single-shot mode (navigation functions from dashboard-navigation.sh)
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
