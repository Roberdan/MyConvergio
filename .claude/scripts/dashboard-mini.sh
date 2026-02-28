#!/bin/bash
# Version: 2.2.0
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

		# Build PR display: OSC 8 clickable link if URL available
		local pr_display="$pr"
		if [[ "$pr" != "-" && "$pr_url" == https://* ]]; then
			# OSC 8 hyperlink: ESC]8;;URL ESC\ text ESC]8;; ESC\
			pr_display=$'\e]8;;'"$pr_url"$'\e\\'"#${pr}"$'\e]8;;\e\\'
			if [[ "$status" == "done" ]]; then
				# Green = merged
				pr_display=$'\e[32m'"$pr_display"$'\e[0m'
			elif [[ "$status" == "in_progress" || "$status" == "merging" ]]; then
				# Live CI state if --prs flag set
				if [[ "$live_prs" -eq 1 ]]; then
					local ci_state
					ci_state=$(gh api "repos/{owner}/{repo}/pulls/${pr}" \
						--jq '.mergeable_state' 2>/dev/null || echo "?")
					pr_display="${pr_display} [${ci_state}]"
				fi
				pr_display=$'\e[33m'"$pr_display"$'\e[0m'
			fi
		fi

		printf "%-6s %-12s %-6s %-24s %-8b %-30s %s\n" \
			"$wid" "$status" "$tasks" "$branch" "$pr_display" "$wt_path" "$clean"
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
		echo "Navigazione interattiva:"
		echo "  R=refresh  C=completati  B=back  Q=quit  P=push  L=linux"
		echo "  <numero>+Enter = drill-down piano (input live)"
		echo ""
		echo "Esempi:"
		echo "  piani                 # Dashboard compatta con auto-refresh"
		echo "  piani -e              # Con dettagli task completati espansi"
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
