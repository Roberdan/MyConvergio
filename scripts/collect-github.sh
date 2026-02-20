#!/bin/bash
# GitHub Collector - Collects PR status, actions, comments via gh CLI
# Usage: ./collect-github.sh [project_path]
# Output: JSON to stdout

# Version: 1.1.0
set -euo pipefail

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Check gh CLI
if ! command -v gh &>/dev/null; then
	jq -n --arg ts "$TIMESTAMP" '{
        collector: "github",
        timestamp: $ts,
        status: "error",
        error: "gh CLI not installed"
    }'
	exit 1
fi

# Resolve owner/repo from origin remote (handles forks correctly)
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
gh_api() {
	_get_slug
	local path="$1"
	shift
	gh api "repos/${_SLUG}/${path}" "$@"
}

# Check authentication
if ! gh auth status >/dev/null 2>&1; then
	jq -n --arg ts "$TIMESTAMP" '{
        collector: "github",
        timestamp: $ts,
        status: "error",
        error: "gh not authenticated"
    }'
	exit 1
fi

# Get repo info (from origin, not upstream)
_get_slug
REPO="$_SLUG"
if [[ -z "$REPO" ]]; then
	jq -n --arg ts "$TIMESTAMP" '{
        collector: "github",
        timestamp: $ts,
        status: "error",
        error: "Not a GitHub repository"
    }'
	exit 1
fi

# Get current branch PRs (REST API — GraphQL has numbering issues on forks)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
PR_DATA='null'
if [[ -n "$BRANCH" ]]; then
	PR_DATA=$(gh_api "pulls?state=open" --jq "[.[] | select(.head.ref == \"$BRANCH\")] | .[0] // null" 2>/dev/null || echo 'null')
fi

# If no PR for current branch, get most recent open PR
if [[ "$PR_DATA" == "null" ]]; then
	PR_DATA=$(gh_api "pulls?state=open&per_page=1" --jq '.[0] // null' 2>/dev/null || echo 'null')
fi

# Format PR data (REST API field mapping)
PR_JSON='null'
if [[ "$PR_DATA" != "null" ]]; then
	PR_JSON=$(echo "$PR_DATA" | jq '{
        number: .number,
        title: .title,
        status: (.state // "unknown" | ascii_upcase),
        url: .html_url,
        additions: .additions,
        deletions: .deletions,
        files: .changed_files,
        reviewDecision: null,
        checks: []
    }')
fi

# Get workflow runs
WORKFLOWS=$(gh run list --limit 5 --json databaseId,displayTitle,status,conclusion,workflowName,createdAt 2>/dev/null | jq 'map({
    id: .databaseId,
    name: .workflowName,
    title: .displayTitle,
    status: (if .conclusion == "success" then "pass" elif .conclusion == "failure" then "fail" elif .status == "in_progress" then "running" else .status end),
    createdAt: .createdAt
})' || echo '[]')

# Get open issues count
ISSUES_COUNT=$(gh issue list --state open --json number --limit 100 2>/dev/null | jq 'length' || echo '0')

# Build output
jq -n \
	--arg collector "github" \
	--arg timestamp "$TIMESTAMP" \
	--arg repo "$REPO" \
	--argjson pr "$PR_JSON" \
	--argjson workflows "$WORKFLOWS" \
	--argjson issues "$ISSUES_COUNT" \
	'{
        collector: $collector,
        timestamp: $timestamp,
        status: "success",
        data: {
            repo: $repo,
            pr: $pr,
            workflows: $workflows,
            openIssues: $issues
        }
    }'
