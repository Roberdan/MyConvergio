#!/usr/bin/env bash
# pr-ops-api.sh - GitHub API operations for PR management
# Extracted from pr-ops.sh for modularization
# Version: 1.0.0

# ============================================================================
# API helpers
# ============================================================================
_OWNER="" _REPO="" _SLUG=""

get_owner_repo() {
	[[ -n "$_OWNER" ]] && return
	# Resolve from origin remote (not upstream) to handle forks correctly
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

# REST API helper: resolves to fork (origin), not upstream
# Usage: gh_api "pulls/101" --jq '.number'
gh_api() {
	get_owner_repo
	local path="$1"
	shift
	gh api "repos/${_SLUG}/${path}" "$@"
}

# GraphQL: fetch review thread nodes (id + isResolved)
gql_review_threads() {
	local pr="$1"
	get_owner_repo
	gh api graphql -f query='
		query($owner: String!, $repo: String!, $pr: Int!) {
			repository(owner: $owner, name: $repo) {
				pullRequest(number: $pr) {
					reviewThreads(first: 100) {
						nodes { id isResolved }
					}
				}
			}
		}' -F "owner=$_OWNER" -F "repo=$_REPO" -F "pr=$pr" \
		--jq '.data.repository.pullRequest.reviewThreads.nodes'
}

# ============================================================================
# PR resolution
# ============================================================================
resolve_pr() {
	local pr="${1:-}"
	if [[ -n "$pr" && "$pr" =~ ^[0-9]+$ ]]; then
		echo "$pr"
		return
	fi
	# Use REST API instead of gh pr list (GraphQL has numbering issues on forks)
	local branch
	branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
	[[ -n "$branch" ]] && pr=$(gh api 'repos/{owner}/{repo}/pulls?state=open' --jq ".[] | select(.head.ref == \"$branch\") | .number" 2>/dev/null | head -1)
	[[ -z "$pr" ]] && pr=$(gh api 'repos/{owner}/{repo}/pulls?state=open&per_page=1' --jq '.[0].number' 2>/dev/null || echo "")
	[[ -z "$pr" ]] && {
		echo "ERROR: No PR found" >&2
		exit 1
	}
	echo "$pr"
}
