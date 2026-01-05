#!/bin/bash
# GitHub Collector - Collects PR status, actions, comments via gh CLI
# Usage: ./collect-github.sh [project_path]
# Output: JSON to stdout

set -euo pipefail

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Check gh CLI
if ! command -v gh &> /dev/null; then
    jq -n --arg ts "$TIMESTAMP" '{
        collector: "github",
        timestamp: $ts,
        status: "error",
        error: "gh CLI not installed"
    }'
    exit 1
fi

# Check authentication
if ! gh auth status > /dev/null 2>&1; then
    jq -n --arg ts "$TIMESTAMP" '{
        collector: "github",
        timestamp: $ts,
        status: "error",
        error: "gh not authenticated"
    }'
    exit 1
fi

# Get repo info
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
if [[ -z "$REPO" ]]; then
    jq -n --arg ts "$TIMESTAMP" '{
        collector: "github",
        timestamp: $ts,
        status: "error",
        error: "Not a GitHub repository"
    }'
    exit 1
fi

# Get current branch PRs
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
PR_DATA='null'
if [[ -n "$BRANCH" ]]; then
    PR_DATA=$(gh pr list --head "$BRANCH" --json number,title,state,url,additions,deletions,changedFiles,reviewDecision,statusCheckRollup --limit 1 2>/dev/null | jq '.[0] // null')
fi

# If no PR for current branch, get most recent open PR
if [[ "$PR_DATA" == "null" ]]; then
    PR_DATA=$(gh pr list --state open --json number,title,state,url,additions,deletions,changedFiles,reviewDecision,statusCheckRollup --limit 1 2>/dev/null | jq '.[0] // null')
fi

# Format PR data
PR_JSON='null'
if [[ "$PR_DATA" != "null" ]]; then
    PR_JSON=$(echo "$PR_DATA" | jq '{
        number: .number,
        title: .title,
        status: .state,
        url: .url,
        additions: .additions,
        deletions: .deletions,
        files: .changedFiles,
        reviewDecision: .reviewDecision,
        checks: ((.statusCheckRollup // []) | map({
            name: .name,
            status: (if .conclusion == "SUCCESS" then "pass" elif .conclusion == "FAILURE" then "fail" elif .status == "IN_PROGRESS" then "running" else "pending" end),
            conclusion: .conclusion
        }))
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
