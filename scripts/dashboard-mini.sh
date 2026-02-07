#!/bin/bash
set -uo pipefail

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
		echo "  - Completamenti: ultimi 3 + ultime 24h"
		echo ""
		echo "Comportamento default:"
		echo "  - Auto-refresh ogni 5 minuti (300 secondi)"
		echo "  - Task completati compressi (solo conteggio)"
		echo "  - Premi R per refresh immediato, Q per uscire"
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

# Function to format elapsed time
format_elapsed() {
	local seconds=$1
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
	local tokens=$1
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

# Function to render dashboard
render_dashboard() {
	# Single plan mode
	if [ -n "$PLAN_ID" ]; then
		plan_info=$(sqlite3 "$DB" "SELECT id, name, status, project_id, source_file, created_at, started_at, completed_at, validated_at, validated_by, worktree_path, parallel_mode FROM plans WHERE id = $PLAN_ID")
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

		# Status icon
		case $pstatus in
		done) status_display="${GREEN}DONE${NC}" ;;
		doing) status_display="${YELLOW}IN PROGRESS${NC}" ;;
		*) status_display="${BLUE}TODO${NC}" ;;
		esac

		echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
		echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}${WHITE}Piano #$pid: $pname${NC}"
		echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
		echo ""

		# Info
		echo -e "${BOLD}${WHITE}Info${NC}"
		echo -e "${GRAY}├─${NC} Status: $status_display"
		echo -e "${GRAY}├─${NC} Project: ${BLUE}$pproject${NC}"
		[ -n "$psource" ] && echo -e "${GRAY}├─${NC} Source: ${CYAN}$psource${NC}"
		echo -e "${GRAY}├─${NC} Created: ${GRAY}$pcreated${NC}"
		[ -n "$pstarted" ] && echo -e "${GRAY}├─${NC} Started: ${GRAY}$pstarted${NC}"
		[ -n "$pcompleted" ] && echo -e "${GRAY}├─${NC} Completed: ${GRAY}$pcompleted${NC}"
		if [ -n "$pvalidated" ]; then
			echo -e "${GRAY}├─${NC} Thor: ${GREEN}✓ $pvalidator${NC} ${GRAY}($pvalidated)${NC}"
		fi
		[ -n "$pworktree" ] && echo -e "${GRAY}├─${NC} Worktree: ${CYAN}$pworktree${NC}"
		[ -n "$pparallel" ] && echo -e "${GRAY}├─${NC} Mode: ${GRAY}$pparallel${NC}"

		# Elapsed time
		if [ -n "$pcompleted" ] && [ -n "$pstarted" ]; then
			start_ts=$(date_to_epoch "$pstarted")
			end_ts=$(date_to_epoch "$pcompleted")
			elapsed_time=$(format_elapsed $((end_ts - start_ts)))
			echo -e "${GRAY}├─${NC} Duration: ${CYAN}$elapsed_time${NC}"
		elif [ -n "$pstarted" ]; then
			start_ts=$(date_to_epoch "$pstarted")
			elapsed_time=$(format_elapsed $(($(date +%s) - start_ts)))
			echo -e "${GRAY}├─${NC} Running: ${YELLOW}$elapsed_time${NC}"
		fi

		# Tokens
		total_tokens=$(sqlite3 "$DB" "SELECT COALESCE(SUM(total_tokens), 0) FROM token_usage WHERE project_id = '$pproject'")
		tokens_formatted=$(format_tokens $total_tokens)
		echo -e "${GRAY}└─${NC} Tokens: ${CYAN}$tokens_formatted${NC} ${GRAY}(progetto)${NC}"
		echo ""

		# Waves
		echo -e "${BOLD}${WHITE}Waves${NC}"
		sqlite3 "$DB" "SELECT wave_id, name, status, tasks_done, tasks_total FROM waves WHERE plan_id = $pid ORDER BY position" | while IFS='|' read -r wid wname wstatus wdone wtotal; do
			case $wstatus in
			done) icon="${GREEN}✓${NC}" ;;
			in_progress) icon="${YELLOW}⚡${NC}" ;;
			blocked) icon="${RED}✗${NC}" ;;
			*) icon="${GRAY}◯${NC}" ;;
			esac
			echo -e "${GRAY}├─${NC} $icon ${CYAN}$wid${NC} ${WHITE}$wname${NC} ${GRAY}($wdone/$wtotal)${NC}"
		done
		echo -e "${GRAY}└─${NC}"

		# Tasks grouped by wave
		echo ""
		echo -e "${BOLD}${WHITE}Tasks${NC}"
		sqlite3 "$DB" "SELECT t.task_id, t.title, t.status, t.priority, w.wave_id FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE w.plan_id = $pid ORDER BY w.position, t.task_id" | while IFS='|' read -r tid ttitle tstatus tprio twid; do
			case $tstatus in
			done) icon="${GREEN}✓${NC}" ;;
			in_progress) icon="${YELLOW}⚡${NC}" ;;
			blocked) icon="${RED}✗${NC}" ;;
			*) icon="${GRAY}◯${NC}" ;;
			esac
			short_title=$(echo "$ttitle" | cut -c1-55)
			[ ${#ttitle} -gt 55 ] && short_title="${short_title}..."
			echo -e "${GRAY}├─${NC} $icon ${CYAN}$tid${NC} ${WHITE}$short_title${NC} ${GRAY}[$tprio] ($twid)${NC}"
		done
		echo -e "${GRAY}└─${NC}"

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
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND status='done'),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND status='in_progress'),
			(SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id=p.id)),
			(SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id=p.id) AND status='done'),
			COALESCE((SELECT SUM(total_tokens) FROM token_usage WHERE project_id=p.project_id), 0),
			COALESCE(p.execution_host, '')
		FROM plans p WHERE p.status IN ('doing', 'in_progress') ORDER BY p.id
	" | while IFS='|' read -r pid pname pstatus pupdated pstarted pcreated pproject wave_total wave_done wave_doing task_total task_done total_tokens exec_host; do

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

		# Task progress (more accurate)
		if [ "$task_total" -gt 0 ]; then
			task_progress=$((task_done * 100 / task_total))
			bar_length=20
			filled=$((task_progress * bar_length / 100))
			empty=$((bar_length - filled))

			bar="${GREEN}"
			for ((i = 0; i < filled; i++)); do bar+="█"; done
			bar+="${GRAY}"
			for ((i = 0; i < empty; i++)); do bar+="░"; done
			bar+="${NC}"
		else
			bar="${GRAY}░░░░░░░░░░░░░░░░░░░░${NC}"
			task_progress=0
		fi

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

		# Host tag
		local_host="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
		local_host="${local_host%.local}"
		host_tag=""
		if [ -n "$exec_host" ] && [ "$exec_host" != "$local_host" ]; then
			host_tag=" ${YELLOW}@${exec_host}${NC}"
		fi

		echo -e "${GRAY}├─${NC} ${YELLOW}[#$pid]${NC} ${project_display}${WHITE}$short_name${NC}${host_tag} $([ -n "$time_info" ] && echo -e "${GRAY}(${time_info}${GRAY})${NC}")"
		[ -n "$branch_display" ] && echo -e "${GRAY}│  ├─${NC} $branch_display"
		echo -e "${GRAY}│  ├─${NC} Progress: $bar ${WHITE}${task_progress}%${NC} ${GRAY}(${task_done}/${task_total} tasks)${NC}"
		echo -e "${GRAY}│  ├─${NC} Waves: ${GREEN}${wave_done}${NC}/${WHITE}${wave_total}${NC} complete ${GRAY}(${wave_progress}%)${NC}"
		echo -e "${GRAY}│  └─${NC} Runtime: ${CYAN}${elapsed_time}${NC} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"

		# Verbose: show wave names
		if [ "$VERBOSE" -eq 1 ]; then
			sqlite3 "$DB" "SELECT wave_id, name, status FROM waves WHERE plan_id = $pid AND status != 'done' ORDER BY position LIMIT 3" | while IFS='|' read -r wid wname wstatus; do
				case $wstatus in
				in_progress) icon="${YELLOW}⚡${NC}" ;;
				blocked) icon="${RED}✗${NC}" ;;
				*) icon="${GRAY}◯${NC}" ;;
				esac
				short_wname=$(echo "$wname" | cut -c1-45)
				[ ${#wname} -gt 45 ] && short_wname="${short_wname}..."
				echo -e "${GRAY}│     └─${NC} $icon ${CYAN}$wid${NC} ${GRAY}$short_wname${NC}"
			done
		fi

		# Task in esecuzione per questo piano (inline)
		plan_tasks=$(sqlite3 "$DB" "SELECT t.task_id, t.title, t.priority FROM tasks t JOIN waves w ON t.wave_id_fk = w.id WHERE w.plan_id = $pid AND t.status = 'in_progress' ORDER BY t.priority DESC" 2>/dev/null)
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
				pr_data=$(gh pr list --repo "$(git -C "$project_dir" remote get-url origin 2>/dev/null)" --state open --json number,title,url,headRefName,statusCheckRollup,comments,reviewDecision,isDraft,mergeable 2>/dev/null)
				if [ -n "$pr_data" ] && [ "$pr_data" != "[]" ]; then
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
		sqlite3 "$DB" "SELECT id, name, created_at, project_id FROM plans WHERE status='todo' ORDER BY created_at DESC" | while IFS='|' read -r pid pname pcreated pproject; do
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
			echo -e "${GRAY}│  └─${NC} ${GRAY}${wave_count} waves, ${task_count} tasks${NC}"
		done

		echo -e "${GRAY}└─${NC}"
		echo ""
	fi

	# Blocked tasks (if requested)
	if [ "$SHOW_BLOCKED" -eq 1 ]; then
		blocked_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='blocked'" 2>/dev/null)
		if [ "$blocked_count" -gt 0 ]; then
			echo -e "${BOLD}${RED}✗ Task Bloccati ($blocked_count)${NC}"
			sqlite3 "$DB" "SELECT t.task_id, t.title, p.id, p.project_id FROM tasks t JOIN waves w ON t.wave_id_fk = w.id JOIN plans p ON w.plan_id = p.id WHERE t.status = 'blocked' ORDER BY p.id" 2>/dev/null | while IFS='|' read -r task_id title plan_id blocked_project; do
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

	# Ultimi 3 piani completati
	echo -e "${BOLD}${WHITE}✅ Recenti Completamenti${NC}"
	if [ "$EXPAND_COMPLETED" -eq 0 ]; then
		echo -e "${GRAY}│  ${NC}${GRAY}Usa ${WHITE}piani -e${GRAY} per vedere dettagli task${NC}"
	fi

	sqlite3 "$DB" "SELECT id, name, updated_at, validated_at, validated_by, completed_at, started_at, created_at, project_id FROM plans WHERE status = 'done' ORDER BY COALESCE(completed_at, updated_at, created_at) DESC LIMIT 3" | while IFS='|' read -r plan_id name updated validated_at validated_by completed started created done_project; do
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

		# Count completed tasks
		task_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $plan_id)")

		# Project display for completed plans
		done_project_display=""
		[ -n "$done_project" ] && done_project_display="${BLUE}[$done_project]${NC} "

		# Compact view: single line with count
		if [ "$EXPAND_COMPLETED" -eq 0 ]; then
			echo -e "${GRAY}├─${NC} ${GREEN}✓${NC} ${YELLOW}[#$plan_id]${NC} ${done_project_display}${WHITE}$short_name${NC} ${GRAY}($date)${NC} $thor_status"
			echo -e "${GRAY}│  └─${NC} ${GRAY}${task_count} task │${NC} Time: ${CYAN}${elapsed_time}${NC} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"
		else
			# Expanded view: with task list
			echo -e "${GRAY}├─${NC} ${GREEN}✓${NC} ${YELLOW}[#$plan_id]${NC} ${done_project_display}${WHITE}$short_name${NC} ${GRAY}($date)${NC} $thor_status"
			echo -e "${GRAY}│  ├─${NC} Time: ${CYAN}${elapsed_time}${NC} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"

			if [ "$task_count" -gt 0 ]; then
				echo -e "${GRAY}│  └─${NC} ${GRAY}$task_count task completati:${NC}"
				# Show all completed tasks (limit to first 10 for readability)
				sqlite3 "$DB" "SELECT task_id, title FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $plan_id) ORDER BY task_id LIMIT 10" | while IFS='|' read -r tid title; do
					short_title=$(echo "$title" | cut -c1-55)
					if [ ${#title} -gt 55 ]; then
						short_title="${short_title}..."
					fi
					echo -e "${GRAY}│     • ${NC}${CYAN}$tid${NC} ${GRAY}$short_title${NC}"
				done

				# Show count if more than 10
				if [ "$task_count" -gt 10 ]; then
					remaining=$((task_count - 10))
					echo -e "${GRAY}│     ${NC}${GRAY}... e altri $remaining task${NC}"
				fi
			fi
			echo ""
		fi
	done
	echo -e "${GRAY}└─${NC}"

	echo ""

	# Piani completati nelle ultime 24 ore
	echo -e "${BOLD}${WHITE}🎉 Completati ultime 24h${NC}"
	completed_24h=$(sqlite3 "$DB" "SELECT id, name, updated_at, validated_at, validated_by, completed_at, started_at, created_at, project_id FROM plans WHERE status = 'done' AND datetime(COALESCE(completed_at, updated_at, created_at)) >= datetime('now', '-1 day') ORDER BY COALESCE(completed_at, updated_at, created_at) DESC")

	if [ -z "$completed_24h" ]; then
		echo -e "${GRAY}└─${NC} Nessun piano completato nelle ultime 24 ore"
	else
		echo "$completed_24h" | while IFS='|' read -r plan_id name updated validated_at validated_by completed started created h24_project; do
			# Use completed_at or updated_at for display
			display_date="${completed:-${updated:-$created}}"
			date=$(echo "$display_date" | cut -d' ' -f1)
			time=$(echo "$display_date" | cut -d' ' -f2 | cut -d':' -f1-2)
			short_name=$(echo "$name" | cut -c1-45)
			if [ ${#name} -gt 45 ]; then
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
			total_tokens=$(sqlite3 "$DB" "SELECT COALESCE(SUM(total_tokens), 0) FROM token_usage WHERE project_id = '$h24_project'")
			tokens_formatted=$(format_tokens $total_tokens)

			# Thor validation status
			if [ -n "$validated_at" ] && [ -n "$validated_by" ]; then
				thor_status="${GREEN}✓ Thor${NC}"
			else
				thor_status="${GRAY}⊘ No Thor${NC}"
			fi

			# Count completed tasks
			task_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id = $plan_id)")

			# Project display for 24h completed
			h24_project_display=""
			[ -n "$h24_project" ] && h24_project_display="${BLUE}[$h24_project]${NC} "

			echo -e "${GRAY}├─${NC} ${GREEN}✓${NC} ${YELLOW}[#$plan_id]${NC} ${h24_project_display}${WHITE}$short_name${NC} ${GRAY}($time)${NC} $thor_status"
			echo -e "${GRAY}│  └─${NC} ${GRAY}${task_count} task │${NC} Time: ${CYAN}${elapsed_time}${NC} ${GRAY}│${NC} Tokens: ${CYAN}${tokens_formatted}${NC} ${GRAY}(progetto)${NC}"
		done
		echo -e "${GRAY}└─${NC}"
	fi

	echo ""
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
		render_dashboard

		# Timestamp e countdown
		now=$(date "+%H:%M:%S")
		echo -e "${GRAY}Ultimo aggiornamento: ${WHITE}$now${NC} ${GRAY}│ Prossimo refresh tra ${REFRESH_INTERVAL}s${NC}"

		# Countdown con aggiornamento ogni secondo, intercetta tasti
		for ((i = REFRESH_INTERVAL; i > 0; i--)); do
			printf "\r${GRAY}Refresh tra: ${WHITE}%3ds${NC} ${GRAY}(${WHITE}R${GRAY}=refresh, ${WHITE}Q${GRAY}=esci)${NC}    " "$i"
			if read -t 1 -n 1 key 2>/dev/null; then
				case "$key" in
				q | Q)
					echo -e "\n${YELLOW}Dashboard terminata.${NC}"
					exit 0
					;;
				*)
					# Any other key = immediate refresh
					printf "\r${CYAN}Refresh forzato...%50s${NC}\r" " "
					break
					;;
				esac
			fi
		done
		clear
	done
else
	# Single render mode
	render_dashboard
fi
