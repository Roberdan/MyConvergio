#!/bin/bash
# PR rendering helper functions (DB-driven from waves table) — grid layout
# Version: 3.0.0

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
	local wave_prs
	wave_prs=$(dbq "SELECT wave_id, pr_number, pr_url, branch_name, status FROM waves WHERE plan_id = $pid AND pr_number IS NOT NULL AND pr_number > 0 ORDER BY position;")
	[ -z "$wave_prs" ] && return 0

	[[ -z "${GRID_W:-}" ]] && _grid_width
	_grid_box_start "PULL REQUESTS"

	local owner_repo=""
	if [ -n "$pproject" ] && command -v gh &>/dev/null; then
		local project_dir="$HOME/GitHub/$pproject"
		[ -d "$project_dir" ] && owner_repo=$(_get_owner_repo "$project_dir")
	fi

	while IFS='|' read -r wid pr_num pr_url branch wstatus; do
		[ -z "$pr_num" ] && continue
		local clean_url
		clean_url=$(_sanitize_pr_url "$pr_url")

		local pr_status_display ci_display="" review_display=""
		case "$wstatus" in
		done) pr_status_display="${GREEN}merged${NC}" ;;
		merging) pr_status_display="${YELLOW}merging${NC}" ;;
		in_progress)
			pr_status_display="${YELLOW}open${NC}"
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
				local decision
				decision=$(gh api "repos/$owner_repo/pulls/$pr_num/reviews" \
					--jq '[.[] | .state] | if any(. == "CHANGES_REQUESTED") then "CHANGES_REQUESTED" elif any(. == "APPROVED") then "APPROVED" else "PENDING" end' 2>/dev/null || echo "PENDING")
				case "$decision" in
				APPROVED) review_display="${GREEN}APPROVED${NC}" ;;
				CHANGES_REQUESTED) review_display="${RED}CHANGES_REQ${NC}" ;;
				*)
					local reviewers
					reviewers=$(gh api "repos/$owner_repo/pulls/$pr_num/requested_reviewers" \
						--jq '[.users[].login] | join(", ")' 2>/dev/null || echo "")
					[ -n "$reviewers" ] && review_display="${YELLOW}needs: @${reviewers}${NC}" || review_display="${GRAY}no review${NC}"
					;;
				esac
			fi
			;;
		*) pr_status_display="${GRAY}${wstatus}${NC}" ;;
		esac

		local url_display=""
		[[ -n "$clean_url" && "$clean_url" == https://* ]] && url_display="  ${clean_url}"
		_grid_row "  ${CYAN}${wid}${NC} PR #${pr_num} $(echo -e "$pr_status_display $ci_display $review_display") ${GRAY}${branch}${NC}${url_display}"
	done <<<"$wave_prs"

	_grid_box_end
}

# Render PR summary for completed/cancelled plans with live GitHub state
# Usage: _render_completed_plan_prs <plan_id>
_render_completed_plan_prs() {
	local pid="$1"
	local wave_prs
	wave_prs=$(dbq "SELECT wave_id, pr_number, pr_url, status FROM waves WHERE plan_id = $pid AND pr_number IS NOT NULL AND pr_number > 0 ORDER BY position;")
	[ -z "$wave_prs" ] && return 0

	local owner_repo=""
	local project_id
	project_id=$(dbq "SELECT project_id FROM plans WHERE id = $pid")
	if [ -n "$project_id" ] && command -v gh &>/dev/null; then
		local project_dir
		project_dir=$(dbq "SELECT path FROM projects WHERE id = '$project_id'")
		project_dir="${project_dir/#\~/$HOME}"
		[ -d "$project_dir" ] && owner_repo=$(_get_owner_repo "$project_dir")
	fi

	local total=0 on_main=0 open=0 closed=0 parts=""
	while IFS='|' read -r wid pr_num pr_url wstatus; do
		[ -z "$pr_num" ] && continue
		total=$((total + 1))
		local clean_url pr_link="#${pr_num}" pr_state=""
		clean_url=$(_sanitize_pr_url "$pr_url")
		[ -n "$owner_repo" ] && pr_state=$(gh api "repos/$owner_repo/pulls/$pr_num" --jq '.state + "/" + (.merged_at // "null" | if . == "null" then "no" else "yes" end)' 2>/dev/null || echo "")

		case "$pr_state" in
		closed/yes)
			on_main=$((on_main + 1))
			parts="${parts}${GREEN}${pr_link} main${NC} "
			;;
		closed/no)
			closed=$((closed + 1))
			parts="${parts}${RED}${pr_link} closed${NC} "
			;;
		open/*)
			open=$((open + 1))
			parts="${parts}${YELLOW}${pr_link} open${NC} "
			[ -n "$clean_url" ] && [ "$clean_url" != "-" ] && parts="${parts}${clean_url} "
			;;
		*)
			[ "$wstatus" = "done" ] && {
				on_main=$((on_main + 1))
				parts="${parts}${GREEN}${pr_link} main${NC} "
			} ||
				parts="${parts}${GRAY}${pr_link} ?${NC} "
			;;
		esac
	done <<<"$wave_prs"

	if [ "$on_main" -eq "$total" ]; then
		echo -e "${GREEN}on main${NC} ${parts}"
	elif [ "$open" -gt 0 ]; then
		echo -e "${YELLOW}${open} PRs open${NC} ${parts}"
	else
		echo -e "${GRAY}PR:${on_main}/${total}${NC} ${parts}"
	fi
}
