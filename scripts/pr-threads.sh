#!/usr/bin/env bash
set -euo pipefail
# PR Threads - Fetch unresolved PR review threads with full context
# Complements pr-digest.sh (compact) with full comment bodies and thread IDs.
# Usage: pr-threads.sh [pr-number] [--no-cache]
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

# --- Dependencies ---
for cmd in gh jq; do
	command -v "$cmd" &>/dev/null || {
		echo "ERROR: $cmd not installed" >&2
		exit 1
	}
done

# --- Slug resolution (same pattern as pr-digest.sh) ---
_OWNER="" _REPO="" _SLUG=""
_get_slug() {
	[[ -n "$_SLUG" ]] && return
	local remote_url
	remote_url=$(git remote get-url origin 2>/dev/null || echo "")
	if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
		_OWNER="${BASH_REMATCH[1]}"
		_REPO="${BASH_REMATCH[2]}"
	else
		_OWNER=$(gh repo view --json owner --jq '.owner.login')
		_REPO=$(gh repo view --json name --jq '.name')
	fi
	_SLUG="${_OWNER}/${_REPO}"
}

# --- Args ---
CACHE_TTL=60
NO_CACHE=0
PR_NUM="${1:-}"

[[ "$PR_NUM" == "--no-cache" ]] && {
	NO_CACHE=1
	PR_NUM="${2:-}"
}
[[ "${2:-}" == "--no-cache" ]] && NO_CACHE=1

# --- Resolve PR from branch (REST API — GraphQL has numbering issues on forks) ---
if [[ -z "$PR_NUM" ]]; then
	_get_slug
	BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
	if [[ -n "$BRANCH" ]]; then
		PR_NUM=$(gh api "repos/${_SLUG}/pulls?state=open" \
			--jq ".[] | select(.head.ref == \"$BRANCH\") | .number" 2>/dev/null | head -1)
	fi
fi
if [[ -z "$PR_NUM" ]]; then
	jq -n '{"pr":null,"status":"no_pr","threads":[]}'
	exit 0
fi

# --- Cache check ---
CACHE_KEY="pr-threads-${PR_NUM}"
if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# --- Bot filter (same as pr-digest.sh) ---
BOT_FILTER='vercel[bot]|github-actions[bot]|dependabot[bot]|codecov[bot]|netlify[bot]|renovate[bot]|sonarcloud[bot]|codefactor-io[bot]|codeclimate[bot]|mergify[bot]'

# --- GraphQL: fetch full review threads (REST API has no reviewThreads endpoint) ---
_get_slug
RAW=$(gh api graphql -f query='
	query($owner: String!, $repo: String!, $pr: Int!) {
		repository(owner: $owner, name: $repo) {
			pullRequest(number: $pr) {
				headRefName
				reviewThreads(first: 100) {
					nodes {
						id
						isResolved
						isOutdated
						path
						line
						startLine
						diffSide
						comments(first: 10) {
							nodes {
								id
								databaseId
								author { login }
								body
								createdAt
							}
						}
					}
				}
			}
		}
	}' -F "owner=$_OWNER" -F "repo=$_REPO" -F "pr=$PR_NUM")

# --- Transform to compact JSON ---
RESULT=$(echo "$RAW" | jq --arg bots "$BOT_FILTER" --argjson pr "$PR_NUM" '
	.data.repository.pullRequest as $pull |
	($pull.reviewThreads.nodes | map(select(.isResolved == false))) as $unresolved |
	{
		pr: $pr,
		branch: $pull.headRefName,
		total_threads: ($pull.reviewThreads.nodes | length),
		unresolved: ($unresolved | length),
		threads: [
			$unresolved[] |
			{
				thread_id: .id,
				path: .path,
				line: .line,
				start_line: .startLine,
				is_outdated: .isOutdated,
				comments: [
					.comments.nodes[] |
					select(.author.login | test($bots) | not) |
					{
						id: .databaseId,
						author: .author.login,
						body: .body,
						created: (.createdAt | .[0:10])
					}
				]
			} |
			select(.comments | length > 0)
		]
	}')

# --- Cache and output ---
echo "$RESULT" | digest_cache_set "$CACHE_KEY"
echo "$RESULT"
