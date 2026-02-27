#!/bin/bash
# PR rendering helper functions (DB-driven from waves table)
# Version: 1.5.0

# Extract clean PR URL from pr_url field (handles "already exists:" messages)
_sanitize_pr_url() {
	local raw="$1"
	if [[ "$raw" == *"https://github.com"* ]]; then
		echo "$raw" | grep -oE 'https://github\.com/[^ ]+' | head -1
	else
		echo "$raw"
	fi
}

# Get owner/repo from project dir git remote
_get_owner_repo() {
	local project_dir="$1"
	git -C "$project_dir" remote get-url origin 2>/dev/null | sed -E 's#.+github\.com[:/]##; s/\.git$//'
}

# Render PR section for an active plan using waves DB data
# Usage: _render_plan_prs <plan_id> <project_name>
_render_plan_prs() {
	local pid="$1" pproject="$2"

	# Query waves with PR data for this plan
	local wave_prs
	wave_prs=$(dbq "SELECT wave_id, pr_number, pr_url, branch_name, status FROM waves WHERE plan_id = $pid AND pr_number IS NOT NULL AND pr_number > 0 ORDER BY position;")
	[ -z "$wave_prs" ] && return 0

	echo -e "${GRAY}│  ${NC}${CYAN}PR (da waves DB):${NC}"

	# Resolve owner/repo once for CI lookups
	local owner_repo=""
	if [ -n "$pproject" ] && command -v gh &>/dev/null; then
		local project_dir="$HOME/GitHub/$pproject"
		[ -d "$project_dir" ] && owner_repo=$(_get_owner_repo "$project_dir")
	fi

	while IFS='|' read -r wid pr_num pr_url branch wstatus; do
		[ -z "$pr_num" ] && continue
		local clean_url
		clean_url=$(_sanitize_pr_url "$pr_url")

		# Wave status → PR status display
		local pr_status_display ci_display=""
		case "$wstatus" in
		done)
			pr_status_display="${GREEN}merged${NC}"
			;;
		merging)
			pr_status_display="${YELLOW}merging${NC}"
			;;
		in_progress)
			pr_status_display="${YELLOW}open${NC}"
			# Fetch CI status for open PRs (lightweight single API call)
			if [ -n "$owner_repo" ]; then
				local ci_state
				ci_state=$(gh api "repos/$owner_repo/pulls/$pr_num" --jq '.mergeable_state // "unknown"' 2>/dev/null || echo "unknown")
				case "$ci_state" in
				clean) ci_display="${GREEN}CI:ok${NC}" ;;
				unstable) ci_display="${YELLOW}CI:unstable${NC}" ;;
				dirty) ci_display="${RED}CI:dirty${NC}" ;;
				blocked) ci_display="${RED}CI:blocked${NC}" ;;
				*) ci_display="${GRAY}CI:--${NC}" ;;
				esac
			fi
			;;
		*)
			pr_status_display="${GRAY}$wstatus${NC}"
			;;
		esac

		echo -e "${GRAY}│  ├─${NC} ${CYAN}$wid${NC} PR #${BOLD}${pr_num}${NC} $pr_status_display $ci_display ${GRAY}${branch}${NC}"
	done <<<"$wave_prs"
}

# Render PR summary for completed plans (DB-only, no API calls)
# Usage: _render_completed_plan_prs <plan_id>
_render_completed_plan_prs() {
	local pid="$1"
	local wave_prs
	wave_prs=$(dbq "SELECT wave_id, pr_number, status FROM waves WHERE plan_id = $pid AND pr_number IS NOT NULL AND pr_number > 0 ORDER BY position;")
	[ -z "$wave_prs" ] && return 0

	local total=0 merged=0 open=0
	while IFS='|' read -r wid pr_num wstatus; do
		total=$((total + 1))
		[ "$wstatus" = "done" ] && merged=$((merged + 1))
		[ "$wstatus" = "in_progress" ] || [ "$wstatus" = "merging" ] && open=$((open + 1))
	done <<<"$wave_prs"

	if [ "$merged" -eq "$total" ]; then
		echo "${GREEN}PR:${merged}/${total} merged${NC}"
	elif [ "$open" -gt 0 ]; then
		echo "${YELLOW}PR:${merged}/${total} merged${NC} ${YELLOW}${open} open${NC}"
	else
		echo "${GRAY}PR:${merged}/${total}${NC}"
	fi
}
