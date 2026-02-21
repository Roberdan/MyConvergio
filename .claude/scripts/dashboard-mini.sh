#!/bin/bash
# Version: 1.4.0
set -euo pipefail
. scripts/lib/dashboard-delegation.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

DB="$HOME/.claude/data/dashboard.db"
SYNC_SCRIPT="$HOME/.claude/scripts/sync-dashboard-db.sh"
REMOTE_GIT_CACHE="$HOME/.claude/data/remote-git-cache.json"

# Quick sync: pull remote changes before rendering (silent, best-effort)
# Sets REMOTE_ONLINE=1 if sync succeeded, 0 if remote unreachable
REMOTE_ONLINE=0
REMOTE_HOST_RESOLVED=""
quick_sync() {
	REMOTE_ONLINE=0
	[ ! -x "$SYNC_SCRIPT" ] && return 0
	REMOTE_HOST_RESOLVED="$(grep '^REMOTE_HOST=' "$HOME/.claude/config/sync-db.conf" 2>/dev/null | cut -d'"' -f2)"
	# Skip if synced less than 30s ago (but still mark online from last result)
	local marker="$HOME/.claude/data/last-quick-sync"
	if [ -f "$marker" ]; then
		local last now diff
		if [[ "$(uname)" == "Darwin" ]]; then
			last=$(stat -f '%m' "$marker" 2>/dev/null || echo 0)
		else
			last=$(stat -c '%Y' "$marker" 2>/dev/null || echo 0)
		fi
		now=$(date +%s)
		diff=$((now - last))
		if [ "$diff" -lt 30 ]; then
			REMOTE_ONLINE=1
			return 0
		fi
	fi
	# Run incremental sync with 3s SSH timeout, fully silent
	if ssh -o ConnectTimeout=3 -o BatchMode=yes "$REMOTE_HOST_RESOLVED" "echo ok" &>/dev/null; then
		"$SYNC_SCRIPT" incremental &>/dev/null
		touch "$marker"
		REMOTE_ONLINE=1
		# Sync ~/.claude git repo (Mac=master, push to Linux)
		git -C "$HOME/.claude" push linux main --quiet 2>/dev/null || true
		# Fetch git status for all remote active projects (piggyback on SSH)
		_fetch_remote_git_status
	fi
}

# Fetch git status from remote for active projects, cache as JSON
_fetch_remote_git_status() {
	[ -z "$REMOTE_HOST_RESOLVED" ] && return 0
	local projects
	projects=$(sqlite3 "$DB" "SELECT DISTINCT p.project_id FROM plans p WHERE p.status='doing' AND p.execution_host IS NOT NULL AND p.execution_host != ''" 2>/dev/null)
	[ -z "$projects" ] && return 0
	# Build a bash script to run remotely — produces valid JSON per project
	local proj_list="" proj
	while IFS= read -r proj; do
		[ -z "$proj" ] && continue
		proj_list+="$proj "
	done <<<"$projects"
	# Single SSH call, inline script on remote
	# shellcheck disable=SC2086
	local safe_proj_list=""
	for _p in $proj_list; do
		safe_proj_list+="$(printf '%q ' "$_p")"
	done
	ssh -o ConnectTimeout=3 -o BatchMode=yes "$REMOTE_HOST_RESOLVED" bash -s -- $safe_proj_list <<'REMOTE_SCRIPT' >"$REMOTE_GIT_CACHE" 2>/dev/null || true
printf '{'
first=1
for proj in "$@"; do
  [ "$first" -eq 1 ] && first=0 || printf ','
  printf '"%s":' "$proj"
  # Case-insensitive directory match (project_id may differ in case)
  dir=$(find "$HOME/GitHub" -maxdepth 1 -iname "$proj" -type d 2>/dev/null | head -1)
  if [ -n "$dir" ] && { [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; }; then
    cd "$dir"
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
    dirty=$(git status --porcelain 2>/dev/null | head -1)
    clean="true"; [ -n "$dirty" ] && clean="false"
    sha=$(git rev-parse --short HEAD 2>/dev/null || echo "")
    printf '{"branch":"%s","ahead":%s,"behind":%s,"clean":%s,"sha":"%s"}' \
      "$branch" "${ahead:-0}" "${behind:-0}" "$clean" "$sha"
  else
    printf '{}'
  fi
done
printf '}'
REMOTE_SCRIPT
}

# Read cached git field for a project: _get_remote_git <project> <field>
_get_remote_git() {
	local proj="$1" field="$2"
	[ ! -f "$REMOTE_GIT_CACHE" ] && echo "" && return
	jq -r ".[\"$proj\"].$field // empty" "$REMOTE_GIT_CACHE" 2>/dev/null
}

# Get GitHub owner/repo from project directory
_get_owner_repo() {
	local dir="$1"
	local url
	url=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
	[ -z "$url" ] && return
	echo "$url" | sed -E 's|.*github\.com[:/]||; s|\.git$||'
}

# Resolve remote project directory (case-insensitive)
_resolve_remote_dir() {
	ssh -o ConnectTimeout=3 "$REMOTE_HOST_RESOLVED" \
		"find ~/GitHub -maxdepth 1 -iname '$1' -type d 2>/dev/null | head -1" 2>/dev/null
}

# Interactive: push from remote
_remote_push() {
	local proj="$1"
	[ -z "$REMOTE_HOST_RESOLVED" ] && echo -e "${RED}Remote host not configured${NC}" && return 1
	local rdir
	rdir=$(_resolve_remote_dir "$proj")
	[ -z "$rdir" ] && echo -e "${RED}Directory $proj non trovata su Linux${NC}" && return 1
	echo -e "${CYAN}Pushing $proj from Linux ($rdir)...${NC}"
	ssh -o ConnectTimeout=5 "$REMOTE_HOST_RESOLVED" "cd $rdir && git push 2>&1" 2>&1
	echo -e "${GREEN}Done.${NC}"
}

# Interactive: show full remote git status
_remote_git_detail() {
	local proj="$1"
	[ -z "$REMOTE_HOST_RESOLVED" ] && echo -e "${RED}Remote host not configured${NC}" && return 1
	local rdir
	rdir=$(_resolve_remote_dir "$proj")
	[ -z "$rdir" ] && echo -e "${RED}Directory $proj non trovata su Linux${NC}" && return 1
	echo -e "${CYAN}Git status for $proj on Linux ($rdir):${NC}"
	ssh -o ConnectTimeout=5 "$REMOTE_HOST_RESOLVED" "cd $rdir && ~/.claude/scripts/git-digest.sh --full 2>&1" 2>&1
}

# Interactive handler: list remote projects, let user pick, execute action
_handle_remote_action() {
	local action="$1" # "push" or "status"
	if [ "$REMOTE_ONLINE" -eq 0 ]; then
		echo -e "${RED}Linux non raggiungibile${NC}"
		return 1
	fi
	# Get unique remote projects from active plans
	local projects
	projects=$(sqlite3 "$DB" "SELECT DISTINCT p.project_id FROM plans p WHERE p.status='doing' AND p.execution_host IS NOT NULL AND p.execution_host != ''" 2>/dev/null)
	if [ -z "$projects" ]; then
		echo -e "${YELLOW}Nessun piano remoto attivo${NC}"
		return 0
	fi
	# Build numbered list
	local i=1 proj_array=()
	echo -e "${BOLD}${WHITE}Progetti remoti:${NC}"
	while IFS= read -r proj; do
		[ -z "$proj" ] && continue
		local ahead
		ahead=$(_get_remote_git "$proj" "ahead")
		local indicator=""
		[ "${ahead:-0}" -gt 0 ] && indicator=" ${YELLOW}(↑${ahead} unpushed)${NC}"
		echo -e "  ${CYAN}${i})${NC} ${WHITE}${proj}${NC}${indicator}"
		proj_array+=("$proj")
		((i++))
	done <<<"$projects"
	# Auto-select if only one project
	local choice
	if [ "${#proj_array[@]}" -eq 1 ]; then
		choice=1
	else
		echo -ne "\n${GRAY}Scegli progetto (1-${#proj_array[@]}): ${NC}"
		read -r choice
	fi
	# Validate
	if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#proj_array[@]}" ]; then
		echo -e "${RED}Scelta non valida${NC}"
		return 1
	fi
	local selected="${proj_array[$((choice - 1))]}"
	echo ""
	if [ "$action" = "push" ]; then
		_remote_push "$selected"
	else
		_remote_git_detail "$selected"
	fi
}

# Cross-platform date to epoch (Mac uses -j, Linux uses -d)
date_to_epoch() {
	local dt="$1"
	if [[ "$(uname)" == "Darwin" ]]; then
		date -j -f "%Y-%m-%d %H:%M:%S" "$dt" +%s 2>/dev/null || echo 0
	else
		date -d "$dt" +%s 2>/dev/null || echo 0
	fi
}

# Cross-platform date-only to epoch
date_only_to_epoch() {
	local dt="$1"
	if [[ "$(uname)" == "Darwin" ]]; then
		date -j -f "%Y-%m-%d" "$dt" +%s 2>/dev/null || echo 0
	else
		date -d "$dt" +%s 2>/dev/null || echo 0
	fi
}

# Parse arguments
VERBOSE=0
PLAN_ID=""
SHOW_BLOCKED=0
REFRESH_INTERVAL=300 # Default: 5 minuti
EXPAND_COMPLETED=0   # Default: task completati compressi

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
		echo "Comportamento default:"
		echo "  - Auto-refresh ogni 5 minuti (300 secondi)"
		echo "  - Task completati compressi (solo conteggio)"
		echo "  - Premi R per refresh, Q per uscire, P per push Linux, L per git Linux"
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

# Single plan detail mode: always expand tasks (you asked for detail, show detail)
if [ -n "$PLAN_ID" ]; then
	EXPAND_COMPLETED=1
fi

# Function to format elapsed time
format_elapsed() {
	local seconds=${1:-0}
	if [ "$seconds" -lt 60 ]; then
		echo "${seconds}s"
	elif [ "$seconds" -lt 3600 ]; then
		local mins=$((seconds / 60))
		echo "${mins}m"
	elif [ "$seconds" -lt 86400 ]; then
		local hours=$((seconds / 3600))
		local mins=$(((seconds % 3600) / 60))
		echo "${hours}h ${mins}m"
	else
		local days=$((seconds / 86400))
		local hours=$(((seconds % 86400) / 3600))
		echo "${days}d ${hours}h"
	fi
}

# Function to format tokens (K for thousands, M for millions)
format_tokens() {
	local tokens=${1:-0}
	if [ "$tokens" -lt 1000 ]; then
		echo "${tokens}"
	elif [ "$tokens" -lt 1000000 ]; then
		local k=$((tokens / 1000))
		echo "${k}K"
	else
		local m=$((tokens / 1000000))
		echo "${m}M"
	fi
}

# Convert agentic description to human-readable summary
truncate_desc() {
	local desc="${1:-}"
	[ -z "$desc" ] && return
	# Strip agentic patterns: Worktree paths, workflow blocks, agent instructions
	desc=$(echo "$desc" | sed -E \
		-e 's/Worktree: [^ ]+ \([^)]*\)\.?//' \
		-e 's/Worktree: [^ ]+\.?//' \
		-e 's/ *(WORKFLOW|IMPORTANT|NOTE|CONSTRAINT|EXECUTION|AGENT|WARNING|CONTEXT|BRANCH|PLAN_ID|STATUS):.*$//' \
		-e 's#/Users/[^ ]+##g' \
		-e 's/\(branch [^)]*\)//g' \
		-e 's/plan\/[0-9]+-[^ ]*//g')
	# Humanize: underscores to spaces, collapse spaces, trim edges
	desc=$(echo "$desc" | sed -E \
		-e 's/_/ /g' \
		-e 's/  +/ /g' \
		-e 's/^[ .]+//' \
		-e 's/[ .]+$//')
	# Skip if empty or too short after cleanup
	[ ${#desc} -lt 5 ] && return
	# Truncate to 120 chars
	if [ ${#desc} -gt 120 ]; then
		echo "${desc:0:117}..."
	else
		echo "$desc"
	fi
}

# Format line count (K for thousands)
format_lines() {
	local lines=${1:-0}
	if [ "$lines" -lt 1000 ]; then
		echo "$lines"
	elif [ "$lines" -lt 10000 ]; then
		local whole=$((lines / 1000))
		local frac=$(((lines % 1000) / 100))
		echo "${whole}.${frac}K"
	else
		echo "$((lines / 1000))K"
	fi
}

# Weighted progress using effort_level (1/2/3) and Thor validation gate.
# A task counts as "done" ONLY if validated by Thor (validated_at IS NOT NULL).
# Returns "done_weight|total_weight"
calc_weighted_progress() {
	local plan_filter="$1" # SQL WHERE clause fragment for wave selection
	sqlite3 "$DB" "
		SELECT
			COALESCE(SUM(CASE WHEN t.status='done' AND t.validated_at IS NOT NULL
				THEN COALESCE(t.effort_level, 1) ELSE 0 END), 0),
			COALESCE(SUM(COALESCE(t.effort_level, 1)), 0)
		FROM tasks t
		WHERE t.wave_id_fk IN (SELECT id FROM waves WHERE $plan_filter)
	"
}

# Render a progress bar from percentage
# Usage: render_bar <percentage> <bar_length>
render_bar() {
	local pct="$1" blen="${2:-20}"
	local filled=$((pct * blen / 100))
	local empty=$((blen - filled))
	local bar="${GREEN}"
	for ((i = 0; i < filled; i++)); do bar+="█"; done
	bar+="${GRAY}"
	for ((i = 0; i < empty; i++)); do bar+="░"; done
	bar+="${NC}"
	echo -e "$bar"
}

# Function to render dashboard
render_dashboard() {
	# Single plan mode
	if [ -n "$PLAN_ID" ]; then
		plan_info=$(sqlite3 "$DB" "SELECT id, name, status, project_id, source_file, created_at, started_at, completed_at, validated_at, validated_by, worktree_path, parallel_mode, COALESCE(human_summary, ''), REPLACE(REPLACE(COALESCE(description, ''), char(10), ' '), char(13), ''), markdown_path, COALESCE(lines_added, 0), COALESCE(lines_removed, 0) FROM plans WHERE id = $PLAN_ID")
		if [ -z "$plan_info" ]; then
			echo -e "${RED}Piano #$PLAN_ID non trovato${NC}"
			return 1
		fi

		pid=$(echo "$plan_info" | cut -d'|' -f1)
		pname=$(echo "$plan_info" | cut -d'|' -f2)
		pstatus=$(echo "$plan_info" | cut -d'|' -f3)
		pproject=$(echo "$plan_info" | cut -d'|' -f4)
		psource=$(echo "$plan_info" | cut -d'|' -f5)
		pcreated=$(echo "$plan_info" | cut -d'|' -f6)
		pstarted=$(echo "$plan_info" | cut -d'|' -f7)
		pcompleted=$(echo "$plan_info" | cut -d'|' -f8)
		pvalidated=$(echo "$plan_info" | cut -d'|' -f9)
		pvalidator=$(echo "$plan_info" | cut -d'|' -f10)
		pworktree=$(echo "$plan_info" | cut -d'|' -f11)
		pparallel=$(echo "$plan_info" | cut -d'|' -f12)
		phuman_summary=$(echo "$plan_info" | cut -d'|' -f13)
		pdescription=$(echo "$plan_info" | cut -d'|' -f14)
		pmarkdown=$(echo "$plan_info" | cut -d'|' -f15)
		plines_added=$(echo "$plan_info" | cut -d'|' -f16)
		plines_removed=$(echo "$plan_info" | cut -d'|' -f17)

		# Status icon
		case $pstatus in
		done) status_display="${GREEN}DONE${NC}" ;;
		doing) status_display="${YELLOW}IN PROGRESS${NC}" ;;
		*) status_display="${BLUE}TODO${NC}" ;;
		esac

		# Pre-compute metrics for summary header
		local task_total task_done task_validated
		task_total=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $pid)")
		task_done=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $pid)")
		task_validated=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='done' AND validated_at IS NOT NULL AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $pid)")
		local wave_total wave_done
		wave_total=$(sqlite3 "$DB" "SELECT COUNT(*) FROM waves WHERE plan_id = $pid")
		wave_done=$(sqlite3 "$DB" "SELECT COUNT(*) FROM waves WHERE plan_id = $pid AND tasks_done = tasks_total AND tasks_total > 0")

		# Elapsed time
		local elapsed_time=""
		if [ -n "$pcompleted" ] && [ -n "$pstarted" ]; then
			local start_ts end_ts
			start_ts=$(date_to_epoch "$pstarted")
			end_ts=$(date_to_epoch "$pcompleted")
			elapsed_time=$(format_elapsed $((end_ts - start_ts)))
		elif [ -n "$pstarted" ]; then
			local start_ts
			start_ts=$(date_to_epoch "$pstarted")
			elapsed_time=$(format_elapsed $(($(date +%s) - start_ts)))
		fi

		# ─── HEADER ───
		echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
		echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}${WHITE}Piano #$pid: $pname${NC}  $status_display"
		echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
		echo ""

		# ─── DESCRIPTION (full, not truncated) ───
		local desc_to_show="${phuman_summary:-$pdescription}"
		if [ -n "$desc_to_show" ]; then
			echo -e "${BOLD}${WHITE}Scopo${NC}"
			# Word-wrap at ~80 chars
			echo "$desc_to_show" | fold -s -w 80 | while IFS= read -r line; do
				echo -e "${GRAY}│${NC}  ${WHITE}$line${NC}"
			done
			echo ""
		fi

		# ─── AT-A-GLANCE METRICS ───
		echo -e "${BOLD}${WHITE}Metriche${NC}"
		echo -e "${GRAY}├─${NC} Status: $status_display  ${GRAY}│${NC}  Project: ${BLUE}$pproject${NC}"

		# Tasks + waves
		local task_line="${BOLD}${GREEN}${task_done}${NC}/${BOLD}${WHITE}${task_total}${NC} ${GRAY}task${NC}"
		[ "$task_validated" -lt "$task_done" ] && task_line+="  ${GRAY}(${NC}${GREEN}${task_validated}${NC} ${GRAY}Thor-validated)${NC}"
		echo -e "${GRAY}├─${NC} $task_line  ${GRAY}│${NC}  ${GREEN}${wave_done}${NC}/${WHITE}${wave_total}${NC} ${GRAY}waves${NC}"

		# Duration + git lines
		local metrics_line=""
		if [ -n "$elapsed_time" ]; then
			if [ -n "$pcompleted" ]; then
				metrics_line="Duration: ${BOLD}${YELLOW}${elapsed_time}${NC}"
			else
				metrics_line="Running: ${BOLD}${YELLOW}${elapsed_time}${NC}"
			fi
		fi
		if [ "${plines_added:-0}" -gt 0 ] || [ "${plines_removed:-0}" -gt 0 ]; then
			[ -n "$metrics_line" ] && metrics_line+="  ${GRAY}│${NC}  "
			metrics_line+="${GREEN}+$(format_lines ${plines_added:-0})${NC} ${RED}-$(format_lines ${plines_removed:-0})${NC} ${GRAY}lines${NC}"
		fi
		[ -n "$metrics_line" ] && echo -e "${GRAY}├─${NC} $metrics_line"

		# Tokens
		local total_tokens tokens_formatted
		total_tokens=$(sqlite3 "$DB" "SELECT COALESCE(SUM(total_tokens), 0) FROM token_usage WHERE project_id = '$pproject'")
		tokens_formatted=$(format_tokens $total_tokens)
		echo -e "${GRAY}├─${NC} Tokens: ${CYAN}$tokens_formatted${NC} ${GRAY}(progetto)${NC}"

		# Thor validation
		if [ -n "$pvalidated" ]; then
			echo -e "${GRAY}├─${NC} Thor: ${GREEN}✓ $pvalidator${NC} ${GRAY}($pvalidated)${NC}"
		fi
		echo -e "${GRAY}└─${NC} Created: ${GRAY}$pcreated${NC}$([ -n "$pstarted" ] && echo -e "  ${GRAY}│${NC}  Started: ${GRAY}$pstarted${NC}")$([ -n "$pcompleted" ] && echo -e "  ${GRAY}│${NC}  Completed: ${GRAY}$pcompleted${NC}")"
		echo ""

		# ─── FILES & ADRs ───
		local has_refs=0
		if [ -n "$pmarkdown" ] || [ -n "$psource" ]; then
			has_refs=1
		fi
		# Scan plan markdown for ADR references
		local adr_list=""
		local pmarkdown_expanded="$pmarkdown"
		[ -n "$pmarkdown_expanded" ] && pmarkdown_expanded=$(echo "$pmarkdown_expanded" | sed "s|^~|$HOME|")
		if [ -n "$pmarkdown_expanded" ] && [ -f "$pmarkdown_expanded" ]; then
			adr_list=$(grep -oE '(docs/adr/|ADR )([A-Za-z0-9_-]+)' "$pmarkdown_expanded" 2>/dev/null | sed 's/docs\/adr\///; s/ADR //' | sort -u | head -10 || true)
		fi
		[ -n "$adr_list" ] && has_refs=1

		if [ "$has_refs" -eq 1 ]; then
			echo -e "${BOLD}${WHITE}Riferimenti${NC}"
			[ -n "$pmarkdown" ] && echo -e "${GRAY}├─${NC} Piano: ${CYAN}$pmarkdown${NC}"
			[ -n "$psource" ] && echo -e "${GRAY}├─${NC} Source: ${CYAN}$psource${NC}"
			[ -n "$pworktree" ] && echo -e "${GRAY}├─${NC} Worktree: ${CYAN}$pworktree${NC}"
			[ -n "$pparallel" ] && echo -e "${GRAY}├─${NC} Mode: ${GRAY}$pparallel${NC}"
			if [ -n "$adr_list" ]; then
				echo -e "${GRAY}├─${NC} ${BOLD}${WHITE}ADR referenziate:${NC}"
				echo "$adr_list" | while IFS= read -r adr; do
					[ -z "$adr" ] && continue
					# Try to find the ADR file in the project
					local adr_file=""
					if [ -n "$pproject" ]; then
						local proj_dir
						proj_dir=$(find ~/GitHub -maxdepth 1 -iname "$pproject" -type d 2>/dev/null | head -1)
						if [ -n "$proj_dir" ]; then
							adr_file=$(find "$proj_dir/docs/adr" -iname "${adr}*" -type f 2>/dev/null | head -1)
						fi
					fi
					if [ -n "$adr_file" ]; then
						echo -e "${GRAY}│  ├─${NC} ${CYAN}$adr${NC} ${GRAY}→ $adr_file${NC}"
					else
						echo -e "${GRAY}│  ├─${NC} ${CYAN}$adr${NC}"
					fi
				done
			fi
			echo -e "${GRAY}└─${NC}"
			echo ""
		fi

		# ─── PROGRESS BAR ───
		# Weighted progress (Thor-gated)
		local wp_data wp_done wp_total task_progress
		wp_data=$(calc_weighted_progress "plan_id = $pid")
		wp_done=$(echo "$wp_data" | cut -d'|' -f1)
		wp_total=$(echo "$wp_data" | cut -d'|' -f2)
		if [ "$wp_total" -gt 0 ]; then
			task_progress=$((wp_done * 100 / wp_total))
		else
			task_progress=0
		fi
		local bar
		bar=$(render_bar "$task_progress" 30)

		local wave_progress
		if [ "$wave_total" -gt 0 ]; then
			wave_progress=$((wave_done * 100 / wave_total))
		else
			wave_progress=0
		fi

		# Unvalidated done tasks warning
		local unvalidated=$((task_done - task_validated))

		echo -e "${BOLD}${WHITE}Progress${NC} ${GRAY}(Thor-gated: solo task validati contano)${NC}"
		echo -e "${GRAY}├─${NC} $bar ${WHITE}${task_progress}%${NC} ${GRAY}(weighted by effort)${NC}"
		echo -e "${GRAY}├─${NC} Executor: ${GREEN}${task_done}${NC}/${WHITE}${task_total}${NC} done  ${GRAY}│${NC}  Thor: ${GREEN}${task_validated}${NC}/${WHITE}${task_done}${NC} validated"
		if [ "$unvalidated" -gt 0 ]; then
			echo -e "${GRAY}│  ${NC}${YELLOW}${unvalidated} task done ma non validati da Thor${NC}"
		fi
		echo -e "${GRAY}└─${NC} Waves: ${GREEN}${wave_done}${NC}/${WHITE}${wave_total}${NC} complete ${GRAY}(${wave_progress}%)${NC}"
		echo ""

		# Tree view: Waves with nested tasks
		echo -e "${BOLD}${WHITE}Waves & Tasks${NC}"
		local wave_count=0
		wave_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM waves WHERE plan_id = $pid")
		local wave_idx=0
		sqlite3 "$DB" "SELECT id, wave_id, name, status, tasks_done, tasks_total FROM waves WHERE plan_id = $pid ORDER BY position" | while IFS='|' read -r wdb_id wid wname wstatus wdone wtotal; do
			wave_idx=$((wave_idx + 1))
			local is_last_wave=0
			[ "$wave_idx" -eq "$wave_count" ] && is_last_wave=1

			# Wave connector
			local wave_prefix="${GRAY}├─${NC}"
			local child_prefix="${GRAY}│  ${NC}"
			if [ "$is_last_wave" -eq 1 ]; then
				wave_prefix="${GRAY}└─${NC}"
				child_prefix="${GRAY}   ${NC}"
			fi

			# Derive visual status from actual task counts (DB status can be stale)
			local effective_wstatus="$wstatus"
			if [ "$wdone" -eq "$wtotal" ] && [ "$wtotal" -gt 0 ]; then
				effective_wstatus="done"
			elif [ "$wdone" -gt 0 ] && [ "$wdone" -lt "$wtotal" ]; then
				# Check if remaining are all human-blocked
				local non_done_non_human
				non_done_non_human=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wdb_id AND status <> 'done' AND NOT (status = 'blocked' AND (notes LIKE '%Human-only%' OR notes LIKE '%human%' OR notes LIKE '%user acceptance%'))")
				if [ "$non_done_non_human" -eq 0 ]; then
					effective_wstatus="waiting_human"
				else
					effective_wstatus="in_progress"
				fi
			fi

			case $effective_wstatus in
			done) icon="${GREEN}✓${NC}" ;;
			in_progress) icon="${YELLOW}⚡${NC}" ;;
			waiting_human) icon="${CYAN}👤${NC}" ;;
			blocked) icon="${YELLOW}⏸${NC}" ;;
			*) icon="${GRAY}◯${NC}" ;;
			esac

			echo -e "${wave_prefix} $icon ${CYAN}$wid${NC} ${WHITE}$wname${NC} ${GRAY}($wdone/$wtotal)${NC}"

			# Nested tasks under this wave
			local task_lines task_count_w=0
			task_lines=$(sqlite3 "$DB" "SELECT t.task_id, REPLACE(REPLACE(t.title, char(10), ' '), char(13), ''), t.status, t.priority, COALESCE(t.model, ''), REPLACE(REPLACE(COALESCE(t.notes, ''), char(10), ' '), char(13), ''), t.validated_at, COALESCE(t.effort_level, 1) FROM tasks t WHERE t.wave_id_fk = $wdb_id ORDER BY t.task_id")
			task_count_w=$(echo "$task_lines" | grep -c '|' 2>/dev/null || echo 0)

			if [ -z "$task_lines" ]; then
				continue
			fi

			# For done waves with EXPAND_COMPLETED=0, show compressed with validation count
			if [ "$effective_wstatus" = "done" ] && [ "$EXPAND_COMPLETED" -eq 0 ]; then
				local w_validated
				w_validated=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wdb_id AND validated_at IS NOT NULL")
				if [ "$w_validated" -eq "$wtotal" ]; then
					echo -e "${child_prefix}${GRAY}└─ ${wdone} tasks completati${NC} ${GREEN}T✓${NC}"
				else
					echo -e "${child_prefix}${GRAY}└─ ${wdone} tasks completati${NC} ${YELLOW}T:${w_validated}/${wtotal}${NC}"
				fi
				continue
			fi

			local tidx=0
			echo "$task_lines" | while IFS='|' read -r tid ttitle tstatus tprio tmodel tnotes tvalidated teffort; do
				[ -z "$tid" ] && continue
				tidx=$((tidx + 1))
				local is_last_task=0
				[ "$tidx" -eq "$task_count_w" ] && is_last_task=1

				local task_connector="${child_prefix}${GRAY}├─${NC}"
				[ "$is_last_task" -eq 1 ] && task_connector="${child_prefix}${GRAY}└─${NC}"

				# Detect human-action-required tasks
				local is_human=0
				if [[ "$tnotes" == *"Human-only"* ]] || [[ "$tnotes" == *"human"* ]] || [[ "$tnotes" == *"user acceptance"* ]]; then
					is_human=1
				fi

				# Thor validation badge
				local thor_badge=""
				if [ "$tstatus" = "done" ]; then
					if [ -n "$tvalidated" ]; then
						thor_badge="${GREEN}T✓${NC}"
					else
						thor_badge="${RED}T!${NC}"
					fi
				fi

				case $tstatus in
				done) icon="${GREEN}✓${NC}" ;;
				in_progress) icon="${YELLOW}⚡${NC}" ;;
				blocked)
					if [ "$is_human" -eq 1 ]; then
						icon="${CYAN}👤${NC}"
					else
						icon="${YELLOW}⏸${NC}"
					fi
					;;
				*) icon="${GRAY}◯${NC}" ;;
				esac

				# Effort + model badge
				local effort_badge=""
				case $teffort in
				3) effort_badge="${RED}E3${NC}" ;;
				2) effort_badge="${YELLOW}E2${NC}" ;;
				*) effort_badge="${GRAY}E1${NC}" ;;
				esac
				local model_badge=""
				[ -n "$tmodel" ] && model_badge="${GRAY}${tmodel}${NC}"

				short_title=$(echo "$ttitle" | cut -c1-45)
				[ ${#ttitle} -gt 45 ] && short_title="${short_title}..."
				echo -e "${task_connector} $icon ${CYAN}$tid${NC} ${WHITE}$short_title${NC} ${GRAY}[$tprio]${NC} $effort_badge $model_badge $thor_badge"
			done
		done

		# Human action required summary with instructions
		local human_tasks
		human_tasks=$(sqlite3 "$DB" "SELECT t.task_id, t.title, w.wave_id, REPLACE(REPLACE(COALESCE(t.description, t.title), char(10), ' '), char(13), '') FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE w.plan_id = $pid AND t.status = 'blocked' AND (t.notes LIKE '%Human-only%' OR t.notes LIKE '%human%' OR t.notes LIKE '%user acceptance%')" 2>/dev/null)
		if [ -n "$human_tasks" ]; then
			echo ""
			local human_count
			human_count=$(echo "$human_tasks" | wc -l | tr -d ' ')
			echo -e "${BOLD}${CYAN}👤 Action Required ($human_count)${NC}"
			local hidx=0
			echo "$human_tasks" | while IFS='|' read -r tid ttitle twid tdesc; do
				[ -z "$tid" ] && continue
				hidx=$((hidx + 1))
				local is_last=0
				[ "$hidx" -eq "$human_count" ] && is_last=1
				local hprefix="${GRAY}├─${NC}"
				local hchild="${GRAY}│  ${NC}"
				if [ "$is_last" -eq 1 ]; then
					hprefix="${GRAY}└─${NC}"
					hchild="${GRAY}   ${NC}"
				fi
				echo -e "${hprefix} ${CYAN}👤${NC} ${CYAN}$tid${NC} ${WHITE}$ttitle${NC} ${GRAY}($twid)${NC}"
				# Show actionable description
				if [ -n "$tdesc" ] && [ "$tdesc" != "$ttitle" ]; then
					# Wrap long descriptions
					local desc_line
					desc_line=$(echo "$tdesc" | cut -c1-70)
					echo -e "${hchild}${YELLOW}→ $desc_line${NC}"
					if [ ${#tdesc} -gt 70 ]; then
						desc_line=$(echo "$tdesc" | cut -c71-140)
						[ -n "$desc_line" ] && echo -e "${hchild}${YELLOW}  $desc_line${NC}"
					fi
				fi
			done
		fi

		# Legend
		echo ""
		echo -e "${BOLD}${WHITE}Legenda${NC}"
		echo -e "${GRAY}├─${NC} ${GREEN}✓${NC} done  ${YELLOW}⚡${NC} in progress  ${GRAY}◯${NC} pending  ${YELLOW}⏸${NC} blocked  ${CYAN}👤${NC} richiede azione tua"
		echo -e "${GRAY}├─${NC} Effort: ${RED}E3${NC}=alto  ${YELLOW}E2${NC}=medio  ${GRAY}E1${NC}=basso  ${GRAY}-- peso nella progress bar${NC}"
		echo -e "${GRAY}├─${NC} Thor: ${GREEN}T✓${NC}=validato  ${RED}T!${NC}=non validato  ${GRAY}-- solo T✓ conta come done${NC}"
		echo -e "${GRAY}└─${NC} Progress pesata: effort x validazione Thor. Task non validati non contano"

		return 0
	fi

	echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${BOLD}${CYAN}║${NC}          ${BOLD}${WHITE}🎯 Convergio.io - Dashboard Piani${NC}          ${BOLD}${CYAN}║${NC}"
	echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
	echo ""

	# Overview (single query instead of 7 separate calls)
	local overview
	overview=$(sqlite3 "$DB" "
		SELECT
			(SELECT COUNT(*) FROM plans),
			(SELECT COUNT(*) FROM plans WHERE status='done'),
			(SELECT COUNT(*) FROM plans WHERE status='doing'),
			(SELECT COUNT(*) FROM plans WHERE status='todo'),
			(SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id IN (SELECT id FROM plans WHERE status='doing'))),
			(SELECT COUNT(*) FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id IN (SELECT id FROM plans WHERE status='doing'))),
			(SELECT COUNT(*) FROM tasks WHERE status='in_progress' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id IN (SELECT id FROM plans WHERE status='doing')));
	")
	total=$(echo "$overview" | cut -d'|' -f1)
	local plan_done=$(echo "$overview" | cut -d'|' -f2)
	doing=$(echo "$overview" | cut -d'|' -f3)
	todo=$(echo "$overview" | cut -d'|' -f4)
	total_tasks=$(echo "$overview" | cut -d'|' -f5)
	done_tasks=$(echo "$overview" | cut -d'|' -f6)
	in_progress_tasks=$(echo "$overview" | cut -d'|' -f7)

	echo -e "${BOLD}${WHITE}📊 Overview${NC}"
	echo -e "${GRAY}├─${NC} Piani: ${GREEN}${plan_done}${NC} done, ${YELLOW}${doing}${NC} doing, ${BLUE}${todo}${NC} todo ${GRAY}(${total} totali)${NC}"
	echo -e "${GRAY}└─${NC} Tasks attivi: ${GREEN}${done_tasks}${NC} done, ${YELLOW}${in_progress_tasks}${NC} in progress ${GRAY}(${total_tasks} totali)${NC}"
	echo ""

	# Piani attivi (single query with subqueries to avoid N+1)
	echo -e "${BOLD}${WHITE}🚀 Piani Attivi${NC}"
	sqlite3 "$DB" "
		SELECT p.id, p.name, p.status, p.updated_at, p.started_at, p.created_at, p.project_id,
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND tasks_done=tasks_total AND tasks_total>0),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND status='in_progress'),
			(SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id=p.id)),
			(SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id=p.id) AND status='done'),
			COALESCE((SELECT SUM(total_tokens) FROM token_usage WHERE project_id=p.project_id), 0),
			COALESCE(p.execution_host, ''),
			COALESCE(p.human_summary, REPLACE(REPLACE(COALESCE(p.description, ''), char(10), ' '), char(13), ''))
		FROM plans p WHERE p.status IN ('doing', 'in_progress') ORDER BY p.id
	" | while IFS='|' read -r pid pname pstatus pupdated pstarted pcreated pproject wave_total wave_done wave_doing task_total task_done total_tokens exec_host pdescription; do
		[ -z "$pid" ] && continue

		# Elapsed time (running time)
		if [ -n "$pstarted" ]; then
			start_ts=$(date_to_epoch "$pstarted")
		else
			start_ts=$(date_to_epoch "$pcreated")
		fi
		now_ts=$(date +%s)
		elapsed_seconds=$((now_ts - start_ts))
		elapsed_time=$(format_elapsed $elapsed_seconds)

		tokens_formatted=$(format_tokens $total_tokens)

		# Weighted task progress (model-based complexity)
		local wp_data wp_done_w wp_total_w
		wp_data=$(calc_weighted_progress "plan_id = $pid")
		wp_done_w=$(echo "$wp_data" | cut -d'|' -f1)
		wp_total_w=$(echo "$wp_data" | cut -d'|' -f2)
		if [ "$wp_total_w" -gt 0 ]; then
			task_progress=$((wp_done_w * 100 / wp_total_w))
		else
			task_progress=0
		fi
		bar=$(render_bar "$task_progress" 20)

		# Wave progress
		if [ "$wave_total" -gt 0 ]; then
			wave_progress=$((wave_done * 100 / wave_total))
		else
			wave_progress=0
		fi

		# Time since last update
		if [ -n "$pupdated" ]; then
			update_date=$(echo "$pupdated" | cut -d' ' -f1)
			days_ago=$((($(date +%s) - $(date_only_to_epoch "$update_date")) / 86400))
			if [ "$days_ago" -eq 0 ]; then
				time_info="${GREEN}oggi${NC}"
			elif [ "$days_ago" -eq 1 ]; then
				time_info="${YELLOW}ieri${NC}"
			elif [ "$days_ago" -gt 7 ]; then
				time_info="${RED}${days_ago}g fa${NC}"
			else
				time_info="${GRAY}${days_ago}g fa${NC}"
			fi
		else
			time_info=""
		fi

		# Truncate long names
		short_name=$(echo "$pname" | cut -c1-50)
		if [ ${#pname} -gt 50 ]; then
			short_name="${short_name}..."
		fi

		# Project display
		project_display=""
		[ -n "$pproject" ] && project_display="${BLUE}[$pproject]${NC} "

		# Git branch/worktree detection
		branch_display=""
		if [ -n "$pproject" ]; then
			project_dir="$HOME/GitHub/$pproject"
			if [ -d "$project_dir/.git" ] || [ -f "$project_dir/.git" ]; then
				current_branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
				if [ -n "$current_branch" ]; then
					# Check if it's a worktree
					if [ -f "$project_dir/.git" ]; then
						branch_display="${CYAN}⎇ ${current_branch}${NC} ${GRAY}(worktree)${NC}"
					else
						branch_display="${CYAN}⎇ ${current_branch}${NC}"
					fi
				fi
			fi
		fi

		# Host tag: LINUX for remote (green if synced, red+OFFLINE if not), MAC for local
		local_host="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
		local_host="${local_host%.local}"
		host_tag=""
		is_remote=0
		if [ -n "$exec_host" ] && [ "$exec_host" != "$local_host" ]; then
			is_remote=1
			if [ "$REMOTE_ONLINE" -eq 1 ]; then
				host_tag=" ${GREEN}LINUX${NC}"
			else
				host_tag=" ${RED}LINUX${NC} ${GRAY}(offline)${NC}"
			fi
		else
			host_tag=" ${GREEN}MAC${NC}"
		fi

		echo -e "${GRAY}├─${NC} ${YELLOW}[#$pid]${NC} ${project_display}${WHITE}$short_name${NC}${host_tag} $([ -n "$time_info" ] && echo -e "${GRAY}(${time_info}${GRAY})${NC}")"
		[ -n "$pdescription" ] && echo -e "${GRAY}│  ${NC}${GRAY}$(truncate_desc "$pdescription")${NC}"
		[ -n "$branch_display" ] && echo -e "${GRAY}│  ├─${NC} $branch_display"
		# Remote git status inline (only for LINUX plans when online)
		if [ "$is_remote" -eq 1 ] && [ "$REMOTE_ONLINE" -eq 1 ] && [ -f "$REMOTE_GIT_CACHE" ]; then
			local r_ahead r_behind r_clean r_branch r_git_line
			r_ahead=$(_get_remote_git "$pproject" "ahead")
			r_behind=$(_get_remote_git "$pproject" "behind")
			r_clean=$(_get_remote_git "$pproject" "clean")
			r_branch=$(_get_remote_git "$pproject" "branch")
			r_git_line=""
			if [ -n "$r_branch" ]; then
				r_git_line="${GRAY}git:${NC} ${CYAN}${r_branch}${NC}"
				if [ "${r_ahead:-0}" -gt 0 ]; then
					r_git_line+=" ${YELLOW}↑${r_ahead} unpushed${NC}"
				fi
				if [ "${r_behind:-0}" -gt 0 ]; then
					r_git_line+=" ${RED}↓${r_behind} behind${NC}"
				fi
				if [ "$r_clean" = "false" ]; then
					r_git_line+=" ${RED}dirty${NC}"
				elif [ "${r_ahead:-0}" -eq 0 ] && [ "${r_behind:-0}" -eq 0 ]; then
					r_git_line+=" ${GREEN}clean${NC}"
				fi
				echo -e "${GRAY}│  ├─${NC} ${r_git_line}"
			fi
		fi
		echo -e "${GRAY}│  ├─${NC} Progress: $bar ${WHITE}${task_progress}%${NC} ${GRAY}(${task_done}/${task_total} tasks)${NC}"
		echo -e "${GRAY}│  ├─${NC} Waves: ${GREEN}${wave_done}${NC}/${WHITE}${wave_total}${NC} complete ${GRAY}(${wave_progress}%)${NC}"
		echo -e "${GRAY}│  └─${NC} Runtime: ${CYAN}${elapsed_time}${NC} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"

		# Verbose: show wave names
		if [ "$VERBOSE" -eq 1 ]; then
			sqlite3 "$DB" "SELECT wave_id, name, status FROM waves WHERE plan_id = $pid AND status != 'done' ORDER BY position LIMIT 3" | while IFS='|' read -r wid wname wstatus; do
				case $wstatus in
				in_progress) icon="${YELLOW}⚡${NC}" ;;
				blocked) icon="${YELLOW}⏸${NC}" ;;
				*) icon="${GRAY}◯${NC}" ;;
				esac
				short_wname=$(echo "$wname" | cut -c1-45)
				[ ${#wname} -gt 45 ] && short_wname="${short_wname}..."
				echo -e "${GRAY}│     └─${NC} $icon ${CYAN}$wid${NC} ${GRAY}$short_wname${NC}"
			done
		fi

		# Task in esecuzione per questo piano (inline)
		plan_tasks=$(sqlite3 "$DB" "SELECT t.task_id, REPLACE(REPLACE(t.title, char(10), ' '), char(13), ''), t.priority FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE w.plan_id = $pid AND t.status = 'in_progress' ORDER BY t.priority DESC" 2>/dev/null)
		if [ -n "$plan_tasks" ]; then
			echo -e "${GRAY}│  ${NC}${YELLOW}⚡ In esecuzione:${NC}"
			echo "$plan_tasks" | while IFS='|' read -r tid ttitle tprio; do
				short_ttitle=$(echo "$ttitle" | cut -c1-42)
				[ ${#ttitle} -gt 42 ] && short_ttitle="${short_ttitle}..."
				prio_color="${GRAY}"
				[ "$tprio" = "P1" ] && prio_color="${RED}"
				echo -e "${GRAY}│  ├─${NC} ${CYAN}$tid${NC} ${WHITE}$short_ttitle${NC} ${prio_color}[$tprio]${NC}"
			done
		fi

		# PR aperte per questo piano specifico (match per branch/titolo)
		if [ -n "$pproject" ] && command -v gh &>/dev/null; then
			project_dir="$HOME/GitHub/$pproject"
			if [ -d "$project_dir" ]; then
				# REST API instead of gh pr list (GraphQL has numbering issues on forks)
				pr_data=$(gh api 'repos/{owner}/{repo}/pulls?state=open' --jq '[.[] | {number, title, url: .html_url, headRefName: .head.ref, statusCheckRollup: null, comments: .comments, reviewDecision: null, isDraft: .draft, mergeable: .mergeable}]' 2>/dev/null || true)
				if [ -n "$pr_data" ] && echo "$pr_data" | jq -e 'type == "array" and length > 0' &>/dev/null; then
					# Normalize plan name for matching: lowercase, extract keywords
					plan_normalized=$(echo "$pname" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/plan-[0-9]*-//g')

					# Extract matching PRs (branch or title contains plan keywords)
					matched_prs=""
					while read -r pr; do
						[ -z "$pr" ] && continue
						pr_branch=$(echo "$pr" | jq -r '.headRefName' | tr '[:upper:]' '[:lower:]')
						pr_title_lower=$(echo "$pr" | jq -r '.title' | tr '[:upper:]' '[:lower:]')

						# Check if PR matches this plan (branch contains key parts of plan name or vice versa)
						match=0
						# Extract significant keywords from plan name (skip common words)
						for keyword in $(echo "$plan_normalized" | tr '-' '\n' | grep -v -E '^(the|and|for|with|complete|plan)$' | head -3); do
							[ ${#keyword} -lt 3 ] && continue
							if [[ "$pr_branch" == *"$keyword"* ]] || [[ "$pr_title_lower" == *"$keyword"* ]]; then
								match=1
								break
							fi
						done
						[ "$match" -eq 1 ] && matched_prs+="$pr"$'\n'
					done < <(echo "$pr_data" | jq -c '.[]' 2>/dev/null)

					# Display matched PRs
					if [ -n "$matched_prs" ]; then
						echo -e "${GRAY}│  ${NC}${CYAN}🔀 Pull Requests:${NC}"
						echo -n "$matched_prs" | while read -r pr; do
							[ -z "$pr" ] && continue
							pr_num=$(echo "$pr" | jq -r '.number')
							pr_title=$(echo "$pr" | jq -r '.title')
							pr_url=$(echo "$pr" | jq -r '.url')
							pr_draft=$(echo "$pr" | jq -r '.isDraft')
							pr_comments=$(echo "$pr" | jq -r '.comments | length')
							pr_review=$(echo "$pr" | jq -r '.reviewDecision // "NONE"')
							pr_mergeable=$(echo "$pr" | jq -r '.mergeable // "UNKNOWN"')

							# CI status counts
							ci_pass=$(echo "$pr" | jq -r '.statusCheckRollup | if . then [.[] | select(.conclusion == "SUCCESS" or .conclusion == "NEUTRAL")] | length else 0 end')
							ci_fail=$(echo "$pr" | jq -r '.statusCheckRollup | if . then [.[] | select(.conclusion == "FAILURE")] | length else 0 end')
							ci_pending=$(echo "$pr" | jq -r '.statusCheckRollup | if . then [.[] | select(.status == "IN_PROGRESS" or .state == "PENDING")] | length else 0 end')
							ci_total=$((ci_pass + ci_fail + ci_pending))

							# CI display: icon + counts
							if [ "$ci_total" -eq 0 ]; then
								ci_display="${GRAY}CI:--${NC}"
							elif [ "$ci_fail" -gt 0 ]; then
								ci_display="${RED}CI:✗${ci_fail}${NC}"
								[ "$ci_pass" -gt 0 ] && ci_display+="${GREEN}✓${ci_pass}${NC}"
							elif [ "$ci_pending" -gt 0 ]; then
								ci_display="${GREEN}CI:✓${ci_pass}${NC}${YELLOW}◯${ci_pending}${NC}"
							else
								ci_display="${GREEN}CI:✓${ci_total}${NC}"
							fi

							# Review status
							case "$pr_review" in
							APPROVED) review_display="${GREEN}Rev:✓${NC}" ;;
							CHANGES_REQUESTED) review_display="${RED}Rev:✗${NC}" ;;
							REVIEW_REQUIRED) review_display="${YELLOW}Rev:◯${NC}" ;;
							*) review_display="${GRAY}Rev:--${NC}" ;;
							esac

							# Mergeable status
							case "$pr_mergeable" in
							MERGEABLE) merge_display="${GREEN}Mrg:✓${NC}" ;;
							CONFLICTING) merge_display="${RED}Mrg:✗${NC}" ;;
							*) merge_display="${GRAY}Mrg:?${NC}" ;;
							esac

							# Draft label
							draft_label=""
							[ "$pr_draft" = "true" ] && draft_label="${GRAY}[draft]${NC} "

							# Comment count (filter out bot comments for display)
							comment_display=""
							[ "$pr_comments" -gt 0 ] && comment_display="${CYAN}💬${pr_comments}${NC}"

							# Truncate title
							short_title=$(echo "$pr_title" | cut -c1-28)
							[ ${#pr_title} -gt 28 ] && short_title="${short_title}..."

							# Display PR number clearly
							echo -e "${GRAY}│  ├─${NC} ${CYAN}PR #${pr_num}${NC} ${draft_label}${WHITE}$short_title${NC}  $ci_display $review_display $merge_display $comment_display"
						done
					fi
				fi
			fi
		fi

		echo ""
	done

	# Piani in Pipeline (todo - non ancora lanciati)
	pipeline_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM plans WHERE status='todo'")
	if [ "$pipeline_count" -gt 0 ]; then
		echo -e "${BOLD}${WHITE}📋 In Pipeline ($pipeline_count)${NC}"
		sqlite3 "$DB" "SELECT id, name, created_at, project_id, COALESCE(human_summary, REPLACE(REPLACE(COALESCE(description, ''), char(10), ' '), char(13), '')) FROM plans WHERE status='todo' ORDER BY created_at DESC" | while IFS='|' read -r pid pname pcreated pproject pdescription; do
			# Days since created
			if [ -n "$pcreated" ]; then
				create_date=$(echo "$pcreated" | cut -d' ' -f1)
				days_old=$((($(date +%s) - $(date_only_to_epoch "$create_date")) / 86400))
				if [ "$days_old" -eq 0 ]; then
					age_info="${GREEN}oggi${NC}"
				elif [ "$days_old" -eq 1 ]; then
					age_info="${YELLOW}ieri${NC}"
				elif [ "$days_old" -gt 7 ]; then
					age_info="${RED}${days_old}g fa${NC}"
				else
					age_info="${GRAY}${days_old}g fa${NC}"
				fi
			else
				age_info=""
			fi

			# Wave and task counts
			wave_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM waves WHERE plan_id = $pid")
			task_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $pid)")

			# Truncate name
			short_name=$(echo "$pname" | cut -c1-50)
			[ ${#pname} -gt 50 ] && short_name="${short_name}..."

			# Project display
			project_display=""
			[ -n "$pproject" ] && project_display="${BLUE}[$pproject]${NC} "

			echo -e "${GRAY}├─${NC} ${BLUE}◯${NC} ${YELLOW}[#$pid]${NC} ${project_display}${WHITE}$short_name${NC} ${GRAY}(creato: ${age_info}${GRAY})${NC}"
			[ -n "$pdescription" ] && echo -e "${GRAY}│  ${NC}${GRAY}$(truncate_desc "$pdescription")${NC}"
			echo -e "${GRAY}│  └─${NC} ${GRAY}${wave_count} waves,${NC} ${BOLD}${WHITE}${task_count} tasks${NC}"
		done

		echo -e "${GRAY}└─${NC}"
		echo ""
	fi

	# Blocked tasks (if requested)
	if [ "$SHOW_BLOCKED" -eq 1 ]; then
		blocked_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='blocked'" 2>/dev/null)
		if [ "$blocked_count" -gt 0 ]; then
			echo -e "${BOLD}${RED}✗ Task Bloccati ($blocked_count)${NC}"
			sqlite3 "$DB" "SELECT t.task_id, REPLACE(REPLACE(t.title, char(10), ' '), char(13), ''), p.id, p.project_id FROM tasks t JOIN waves w ON t.wave_id_fk = w.id JOIN plans p ON w.plan_id = p.id WHERE t.status = 'blocked' ORDER BY p.id" 2>/dev/null | while IFS='|' read -r task_id title plan_id blocked_project; do
				short_title=$(echo "$title" | cut -c1-45)
				[ ${#title} -gt 45 ] && short_title="${short_title}..."
				blocked_project_display=""
				[ -n "$blocked_project" ] && blocked_project_display="${BLUE}[$blocked_project]${NC} "
				echo -e "${GRAY}├─${NC} ${RED}$task_id${NC} ${WHITE}$short_title${NC} ${blocked_project_display}${GRAY}[#$plan_id]${NC}"
			done
			echo -e "${GRAY}└─${NC}"
			echo ""
		fi
	fi

	# Piani completati nelle ultime 24 ore
	local completed_week_count
	completed_week_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM plans WHERE status = 'done' AND datetime(COALESCE(completed_at, updated_at, created_at)) >= datetime('now', '-1 day')")
	echo -e "${BOLD}${WHITE}✅ Completati ultime 24h ($completed_week_count)${NC}"
	if [ "$completed_week_count" -eq 0 ]; then
		echo -e "${GRAY}└─${NC} Nessun piano completato nelle ultime 24 ore"
	fi
	if [ "$EXPAND_COMPLETED" -eq 0 ] && [ "$completed_week_count" -gt 0 ]; then
		echo -e "${GRAY}│  ${NC}${GRAY}Usa ${WHITE}piani -e${GRAY} per vedere dettagli task${NC}"
	fi

	sqlite3 "$DB" "SELECT id, name, updated_at, validated_at, validated_by, completed_at, started_at, created_at, project_id, COALESCE(human_summary, REPLACE(REPLACE(COALESCE(description, ''), char(10), ' '), char(13), '')), COALESCE(lines_added, 0), COALESCE(lines_removed, 0), COALESCE(worktree_path, '') FROM plans WHERE status = 'done' AND datetime(COALESCE(completed_at, updated_at, created_at)) >= datetime('now', '-1 day') ORDER BY COALESCE(completed_at, updated_at, created_at) DESC" | while IFS='|' read -r plan_id name updated validated_at validated_by completed started created done_project pdescription lines_added lines_removed worktree_path; do
		[ -z "$plan_id" ] && continue
		# Use completed_at or updated_at for display
		display_date="${completed:-${updated:-$created}}"
		date=$(echo "$display_date" | cut -d' ' -f1)
		short_name=$(echo "$name" | cut -c1-50)
		if [ ${#name} -gt 50 ]; then
			short_name="${short_name}..."
		fi

		# Elapsed time (total execution time)
		if [ -n "$completed" ] && [ -n "$started" ]; then
			start_ts=$(date_to_epoch "$started")
			end_ts=$(date_to_epoch "$completed")
			elapsed_seconds=$((end_ts - start_ts))
		elif [ -n "$completed" ] && [ -n "$created" ]; then
			start_ts=$(date_to_epoch "$created")
			end_ts=$(date_to_epoch "$completed")
			elapsed_seconds=$((end_ts - start_ts))
		else
			elapsed_seconds=0
		fi
		elapsed_time=$(format_elapsed $elapsed_seconds)

		# Token usage (usa project_id perché plan_id è sempre NULL nel DB)
		total_tokens=$(sqlite3 "$DB" "SELECT COALESCE(SUM(total_tokens), 0) FROM token_usage WHERE project_id = '$done_project'")
		tokens_formatted=$(format_tokens $total_tokens)

		# Thor validation status
		if [ -n "$validated_at" ] && [ -n "$validated_by" ]; then
			thor_status="${GREEN}✓ Thor${NC}"
		else
			thor_status="${GRAY}⊘ No Thor${NC}"
		fi

		# Count tasks (done/total)
		task_done_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $plan_id)")
		task_total_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $plan_id)")

		# Project display for completed plans
		done_project_display=""
		[ -n "$done_project" ] && done_project_display="${BLUE}[$done_project]${NC} "

		# Git stats display
		local git_stats_display=""
		if [ "${lines_added:-0}" -gt 0 ] || [ "${lines_removed:-0}" -gt 0 ]; then
			git_stats_display=" ${GRAY}│${NC} ${GREEN}+$(format_lines ${lines_added:-0})${NC} ${RED}-$(format_lines ${lines_removed:-0})${NC}"
		fi

		# PR detection for completed plan
		local pr_display="" pr_merged=0 pr_ci_display="" pr_num=""
		if [ -n "$done_project" ] && command -v gh &>/dev/null; then
			local project_dir="$HOME/GitHub/$done_project"
			if [ -d "$project_dir" ]; then
				local owner_repo
				owner_repo=$(_get_owner_repo "$project_dir")
				if [ -n "$owner_repo" ]; then
					local pr_data
					pr_data=$(gh api "repos/$owner_repo/pulls?state=all&per_page=20&sort=updated&direction=desc" \
						--jq '[.[] | {number, title, url: .html_url, headRefName: .head.ref, state, merged_at, head_sha: .head.sha}]' \
						2>/dev/null || true)
					if [ -n "$pr_data" ] && echo "$pr_data" | jq -e 'type == "array" and length > 0' &>/dev/null; then
						local plan_normalized
						plan_normalized=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/plan-[0-9]*-//g')
						while read -r pr; do
							[ -z "$pr" ] && continue
							local pr_branch pr_title_lower
							pr_branch=$(echo "$pr" | jq -r '.headRefName' | tr '[:upper:]' '[:lower:]')
							pr_title_lower=$(echo "$pr" | jq -r '.title' | tr '[:upper:]' '[:lower:]')
							local match=0
							for keyword in $(echo "$plan_normalized" | tr '-' '\n' | grep -v -E '^(the|and|for|with|complete|plan)$' | head -3); do
								[ ${#keyword} -lt 3 ] && continue
								if [[ "$pr_branch" == *"$keyword"* ]] || [[ "$pr_title_lower" == *"$keyword"* ]]; then
									match=1
									break
								fi
							done
							if [ "$match" -eq 1 ]; then
								pr_num=$(echo "$pr" | jq -r '.number')
								local pr_url_val pr_merged_at pr_state pr_head_sha
								pr_url_val=$(echo "$pr" | jq -r '.url')
								pr_merged_at=$(echo "$pr" | jq -r '.merged_at // empty')
								pr_state=$(echo "$pr" | jq -r '.state')
								pr_head_sha=$(echo "$pr" | jq -r '.head_sha')
								# CI status from commit status
								if [ -n "$pr_head_sha" ] && [ "$pr_head_sha" != "null" ]; then
									local ci_state
									ci_state=$(gh api "repos/$owner_repo/commits/$pr_head_sha/status" --jq '.state' 2>/dev/null || echo "unknown")
									case "$ci_state" in
									success) pr_ci_display="${GREEN}CI:✓${NC}" ;;
									failure) pr_ci_display="${RED}CI:✗${NC}" ;;
									pending) pr_ci_display="${YELLOW}CI:◯${NC}" ;;
									*) pr_ci_display="${GRAY}CI:--${NC}" ;;
									esac
								fi
								if [ -n "$pr_merged_at" ]; then
									pr_merged=1
									pr_display="${GREEN}PR #${pr_num} merged${NC}"
								elif [ "$pr_state" = "open" ]; then
									pr_display="${YELLOW}PR #${pr_num} open${NC}"
								else
									pr_display="${RED}PR #${pr_num} closed${NC}"
								fi
								break
							fi
						done < <(echo "$pr_data" | jq -c '.[]' 2>/dev/null)
					fi
				fi
			fi
		fi

		# Worktree check
		local worktree_exists=0 worktree_display=""
		if [ -n "$worktree_path" ]; then
			local wt_expanded
			wt_expanded=$(echo "$worktree_path" | sed "s|^~|$HOME|")
			if [ -d "$wt_expanded" ]; then
				worktree_exists=1
				worktree_display="${RED}WT: esiste${NC}"
			else
				worktree_display="${GREEN}WT: pulito${NC}"
			fi
		fi

		# Plan conclusion assessment
		local truly_done=1
		if [ -n "$pr_num" ] && [ "$pr_merged" -eq 0 ]; then
			truly_done=0
		fi
		if [ "$worktree_exists" -eq 1 ]; then
			truly_done=0
		fi
		local plan_icon="${GREEN}✓${NC}"
		[ "$truly_done" -eq 0 ] && plan_icon="${YELLOW}⚠${NC}"

		# Build closure status line
		local closure_line=""
		if [ -n "$pr_display" ]; then
			closure_line+="$pr_display"
			[ -n "$pr_ci_display" ] && closure_line+=" $pr_ci_display"
		fi
		if [ -n "$worktree_display" ]; then
			[ -n "$closure_line" ] && closure_line+=" ${GRAY}│${NC} "
			closure_line+="$worktree_display"
		fi

		# Compact view: single line with count
		if [ "$EXPAND_COMPLETED" -eq 0 ]; then
			echo -e "${GRAY}├─${NC} $plan_icon ${YELLOW}[#$plan_id]${NC} ${done_project_display}${WHITE}$short_name${NC} ${GRAY}($date)${NC} $thor_status"
			[ -n "$pdescription" ] && echo -e "${GRAY}│  ${NC}${GRAY}$(truncate_desc "$pdescription")${NC}"
			if [ -n "$closure_line" ]; then
				echo -e "${GRAY}│  ├─${NC} ${BOLD}${GREEN}${task_done_count}${NC}/${BOLD}${WHITE}${task_total_count}${NC} ${GRAY}task${NC} ${GRAY}│${NC} ${BOLD}${YELLOW}${elapsed_time}${NC}${git_stats_display} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"
				echo -e "${GRAY}│  └─${NC} $closure_line"
			else
				echo -e "${GRAY}│  └─${NC} ${BOLD}${GREEN}${task_done_count}${NC}/${BOLD}${WHITE}${task_total_count}${NC} ${GRAY}task${NC} ${GRAY}│${NC} ${BOLD}${YELLOW}${elapsed_time}${NC}${git_stats_display} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"
			fi
		else
			# Expanded view: with task list
			echo -e "${GRAY}├─${NC} $plan_icon ${YELLOW}[#$plan_id]${NC} ${done_project_display}${WHITE}$short_name${NC} ${GRAY}($date)${NC} $thor_status"
			[ -n "$pdescription" ] && echo -e "${GRAY}│  ${NC}${GRAY}$(truncate_desc "$pdescription")${NC}"
			echo -e "${GRAY}│  ├─${NC} ${BOLD}${GREEN}${task_done_count}${NC}/${BOLD}${WHITE}${task_total_count}${NC} ${GRAY}task${NC} ${GRAY}│${NC} ${BOLD}${YELLOW}${elapsed_time}${NC}${git_stats_display} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"

			local has_closure=0
			[ -n "$closure_line" ] && has_closure=1

			if [ "$task_done_count" -gt 0 ]; then
				if [ "$has_closure" -eq 1 ]; then
					echo -e "${GRAY}│  ├─${NC} ${GRAY}Task completati:${NC}"
				else
					echo -e "${GRAY}│  └─${NC} ${GRAY}Task completati:${NC}"
				fi
				# Show all completed tasks (limit to first 10 for readability)
				sqlite3 "$DB" "SELECT task_id, REPLACE(REPLACE(title, char(10), ' '), char(13), '') FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $plan_id) ORDER BY task_id LIMIT 10" | while IFS='|' read -r tid title; do
					short_title=$(echo "$title" | cut -c1-55)
					if [ ${#title} -gt 55 ]; then
						short_title="${short_title}..."
					fi
					echo -e "${GRAY}│     • ${NC}${CYAN}$tid${NC} ${GRAY}$short_title${NC}"
				done

				# Show count if more than 10
				if [ "$task_done_count" -gt 10 ]; then
					remaining=$((task_done_count - 10))
					echo -e "${GRAY}│     ${NC}${GRAY}... e altri $remaining task${NC}"
				fi
			fi
			if [ "$has_closure" -eq 1 ]; then
				echo -e "${GRAY}│  └─${NC} $closure_line"
			fi
			echo ""
		fi
	done
	echo -e "${GRAY}└─${NC}"

	echo ""

	# Warn about active/pipeline plans missing descriptions
	local missing_desc
	missing_desc=$(sqlite3 "$DB" "SELECT GROUP_CONCAT('#' || id, ', ') FROM plans WHERE status IN ('doing', 'todo') AND (description IS NULL OR description = '' OR description = '{')")
	if [ -n "$missing_desc" ]; then
		echo -e "${YELLOW}⚠ Piani senza descrizione: ${WHITE}${missing_desc}${NC}"
		echo -e "${GRAY}  Usa: plan-db.sh update-desc <id> \"descrizione\"${NC}"
		echo ""
	fi

	echo -e "${GRAY}Dashboard: ${CYAN}http://localhost:31415${NC} ${GRAY}│ Usa ${WHITE}piani -h${GRAY} per opzioni${NC}"
	echo ""
}

# Refresh mode
if [ "$REFRESH_INTERVAL" -gt 0 ]; then
	# Trap CTRL+C for clean exit
	trap 'echo -e "\n${YELLOW}Dashboard terminata.${NC}"; exit 0' INT

	# Clear immediately and render (no sleep, no empty space)
	clear
	while true; do
		quick_sync
		render_dashboard

		# Timestamp e countdown
		now=$(date "+%H:%M:%S")
		echo -e "${GRAY}Ultimo aggiornamento: ${WHITE}$now${NC} ${GRAY}│ Prossimo refresh tra ${REFRESH_INTERVAL}s${NC}"

		# Wait for keypress or timeout
		printf "\r${GRAY}Refresh tra: ${WHITE}%3ds${NC} ${GRAY}(${WHITE}R${GRAY}=refresh, ${WHITE}Q${GRAY}=esci, ${WHITE}P${GRAY}=push, ${WHITE}L${GRAY}=linux git)${NC}    " "$REFRESH_INTERVAL"
		key=""
		read -t "$REFRESH_INTERVAL" -n 1 key 2>/dev/null || true
		case "$key" in
		q | Q)
			echo -e "\n${YELLOW}Dashboard terminata.${NC}"
			exit 0
			;;
		p | P)
			echo ""
			_handle_remote_action "push"
			echo -e "\n${GRAY}Premi un tasto per continuare...${NC}"
			read -n 1 -s
			;;
		l | L)
			echo ""
			_handle_remote_action "status"
			echo -e "\n${GRAY}Premi un tasto per continuare...${NC}"
			read -n 1 -s
			;;
		"") ;; # timeout - normal refresh
		*)
			# Any other key = immediate refresh
			printf "\r${CYAN}Refresh forzato...%50s${NC}\r" " "
			;;
		esac
		clear
	done
else
	# Single render mode
	quick_sync
	render_dashboard
fi
