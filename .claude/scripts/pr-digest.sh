#!/usr/bin/env bash
# PR Digest - Compact PR review status as JSON
# Only human comments, only unresolved threads. Skips bots.
# Usage: pr-digest.sh [pr-number] [--no-cache]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=30
NO_CACHE=0
PR_NUM="${1:-}"

[[ "$PR_NUM" == "--no-cache" ]] && {
	NO_CACHE=1
	PR_NUM="${2:-}"
}
[[ "${2:-}" == "--no-cache" ]] && NO_CACHE=1

# Resolve PR number from current branch if not provided
if [[ -z "$PR_NUM" ]]; then
	BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
	if [[ -n "$BRANCH" ]]; then
		PR_NUM=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")
	fi
fi

# Fallback: most recent open PR
if [[ -z "$PR_NUM" ]]; then
	PR_NUM=$(gh pr list --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null || echo "")
fi

if [[ -z "$PR_NUM" ]]; then
	jq -n '{"pr":null,"status":"no_pr","threads":[]}'
	exit 0
fi

# Cache check
CACHE_KEY="pr-${PR_NUM}"
if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# Bot authors to filter out
BOT_FILTER='vercel[bot]|github-actions[bot]|dependabot[bot]|codecov[bot]|netlify[bot]|renovate[bot]|sonarcloud[bot]|codefactor-io[bot]|codeclimate[bot]|mergify[bot]'

# Fetch PR metadata (compact)
PR_META=$(gh pr view "$PR_NUM" \
	--json number,title,state,reviewDecision,additions,deletions,changedFiles \
	2>/dev/null || echo "{}")

PR_STATE=$(echo "$PR_META" | jq -r '.state // "UNKNOWN"')
PR_DECISION=$(echo "$PR_META" | jq -r '.reviewDecision // "PENDING"')

# Fetch review comments (inline code comments)
REVIEW_COMMENTS=$(gh api "repos/{owner}/{repo}/pulls/${PR_NUM}/comments" \
	--paginate --jq '.' 2>/dev/null || echo "[]")

# Fetch issue comments (general PR comments, not inline)
ISSUE_COMMENTS=$(gh api "repos/{owner}/{repo}/issues/${PR_NUM}/comments" \
	--paginate --jq '.' 2>/dev/null || echo "[]")

# Fetch reviews (approve/request changes with body)
REVIEWS=$(gh api "repos/{owner}/{repo}/pulls/${PR_NUM}/reviews" \
	--paginate --jq '.' 2>/dev/null || echo "[]")

# Process review comments: filter bots, extract compact data
THREADS=$(echo "$REVIEW_COMMENTS" | jq --arg bots "$BOT_FILTER" '
	[.[] |
		select(.user.login | test($bots) | not) |
		{
			author: .user.login,
			file: .path,
			line: (.line // .original_line // null),
			body: (.body | .[0:200]),
			outdated: (if .position == null and .original_position != null then true else false end),
			created: (.created_at | .[0:10])
		}
	] | sort_by(.created) | reverse')

# Process issue comments: filter bots, skip empty
GENERAL=$(echo "$ISSUE_COMMENTS" | jq --arg bots "$BOT_FILTER" '
	[.[] |
		select(.user.login | test($bots) | not) |
		select(.body | length > 0) |
		{
			author: .user.login,
			body: (.body | .[0:200]),
			created: (.created_at | .[0:10])
		}
	] | sort_by(.created) | reverse | .[0:5]')

# Process reviews with body (approve/request changes messages)
REVIEW_MSGS=$(echo "$REVIEWS" | jq --arg bots "$BOT_FILTER" '
	[.[] |
		select(.user.login | test($bots) | not) |
		select(.body | length > 0) |
		{
			author: .user.login,
			state: .state,
			body: (.body | .[0:200]),
			created: (.submitted_at | .[0:10])
		}
	] | sort_by(.created) | reverse | .[0:5]')

# Build final JSON
RESULT=$(jq -n \
	--argjson meta "$PR_META" \
	--arg decision "$PR_DECISION" \
	--argjson threads "$THREADS" \
	--argjson general "$GENERAL" \
	--argjson reviews "$REVIEW_MSGS" \
	'{
		pr: ($meta.number // null),
		title: ($meta.title // ""),
		status: ($meta.state // "UNKNOWN"),
		decision: $decision,
		changes: {add: ($meta.additions // 0), del: ($meta.deletions // 0), files: ($meta.changedFiles // 0)},
		inline_comments: ($threads | length),
		threads: $threads,
		general_comments: $general,
		reviews: $reviews
	}')

# Cache and output
echo "$RESULT" | digest_cache_set "$CACHE_KEY"
echo "$RESULT"
