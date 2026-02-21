#!/bin/bash
# PR rendering helper functions
# Version: 1.4.0

# Render PR section for an active plan
# Usage: _render_plan_prs <project_name> <plan_name>
_render_plan_prs() {
local pproject="$1" pname="$2"
[ -z "$pproject" ] || ! command -v gh &>/dev/null && return 0

local project_dir="$HOME/GitHub/$pproject"
[ ! -d "$project_dir" ] && return 0

# REST API instead of gh pr list
local pr_data
pr_data=$(gh api 'repos/{owner}/{repo}/pulls?state=open' --jq '[.[] | {number, title, url: .html_url, headRefName: .head.ref, statusCheckRollup: null, comments: .comments, reviewDecision: null, isDraft: .draft, mergeable: .mergeable}]' 2>/dev/null || true)
[ -z "$pr_data" ] || ! echo "$pr_data" | jq -e 'type == "array" and length > 0' &>/dev/null && return 0

# Normalize plan name for matching
local plan_normalized
plan_normalized=$(echo "$pname" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/plan-[0-9]*-//g')

# Extract matching PRs
local matched_prs=""
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
[ "$match" -eq 1 ] && matched_prs+="$pr"$'\n'
done < <(echo "$pr_data" | jq -c '.[]' 2>/dev/null)

# Display matched PRs
if [ -n "$matched_prs" ]; then
echo -e "${GRAY}│  ${NC}${CYAN}🔀 Pull Requests:${NC}"
echo -n "$matched_prs" | while read -r pr; do
[ -z "$pr" ] && continue
local pr_num pr_title pr_url pr_draft pr_comments pr_review pr_mergeable
pr_num=$(echo "$pr" | jq -r '.number')
pr_title=$(echo "$pr" | jq -r '.title')
pr_url=$(echo "$pr" | jq -r '.url')
pr_draft=$(echo "$pr" | jq -r '.isDraft')
pr_comments=$(echo "$pr" | jq -r '.comments | length')
pr_review=$(echo "$pr" | jq -r '.reviewDecision // "NONE"')
pr_mergeable=$(echo "$pr" | jq -r '.mergeable // "UNKNOWN"')

# CI status counts
local ci_pass ci_fail ci_pending ci_total ci_display
ci_pass=$(echo "$pr" | jq -r '.statusCheckRollup | if . then [.[] | select(.conclusion == "SUCCESS" or .conclusion == "NEUTRAL")] | length else 0 end')
ci_fail=$(echo "$pr" | jq -r '.statusCheckRollup | if . then [.[] | select(.conclusion == "FAILURE")] | length else 0 end')
ci_pending=$(echo "$pr" | jq -r '.statusCheckRollup | if . then [.[] | select(.status == "IN_PROGRESS" or .state == "PENDING")] | length else 0 end')
ci_total=$((ci_pass + ci_fail + ci_pending))

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
local review_display
case "$pr_review" in
APPROVED) review_display="${GREEN}Rev:✓${NC}" ;;
CHANGES_REQUESTED) review_display="${RED}Rev:✗${NC}" ;;
REVIEW_REQUIRED) review_display="${YELLOW}Rev:◯${NC}" ;;
*) review_display="${GRAY}Rev:--${NC}" ;;
esac

# Mergeable status
local merge_display
case "$pr_mergeable" in
MERGEABLE) merge_display="${GREEN}Mrg:✓${NC}" ;;
CONFLICTING) merge_display="${RED}Mrg:✗${NC}" ;;
*) merge_display="${GRAY}Mrg:?${NC}" ;;
esac

# Draft label
local draft_label=""
[ "$pr_draft" = "true" ] && draft_label="${GRAY}[draft]${NC} "

# Comment count
local comment_display=""
[ "$pr_comments" -gt 0 ] && comment_display="${CYAN}💬${pr_comments}${NC}"

# Truncate title
local short_title=$(echo "$pr_title" | cut -c1-28)
[ ${#pr_title} -gt 28 ] && short_title="${short_title}..."

echo -e "${GRAY}│  ├─${NC} ${CYAN}PR #${pr_num}${NC} ${draft_label}${WHITE}$short_title${NC}  $ci_display $review_display $merge_display $comment_display"
done
fi
}
