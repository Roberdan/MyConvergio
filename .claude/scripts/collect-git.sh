#!/bin/bash
# Git Collector - Collects git status, log, branches, uncommitted changes
# Usage: ./collect-git.sh [project_path]
# Output: JSON to stdout

# Version: 1.1.0
set -euo pipefail

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH"

# Verify git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
	echo '{"collector":"git","status":"error","error":"Not a git repository"}' | jq .
	exit 1
fi

# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Get recent commits (last 10)
COMMITS=$(git log --format='{"hash":"%h","message":"%s","author":"%an","time":"%ar"}' -n 10 2>/dev/null | jq -s '.' || echo '[]')

# Get all branches
BRANCHES=$(git branch -a --format='%(refname:short)' 2>/dev/null | grep -v '^remotes/' | jq -R -s 'split("\n") | map(select(length > 0))' || echo '[]')

# Get staged files
STAGED=$(git diff --cached --name-status 2>/dev/null | awk '{
    status = "M"
    if ($1 == "A") status = "A"
    else if ($1 == "D") status = "D"
    else if ($1 == "R") status = "R"
    print "{\"path\":\"" $2 "\",\"status\":\"" status "\"}"
}' | jq -s '.' || echo '[]')

# Get unstaged modified files
UNSTAGED=$(git diff --name-status 2>/dev/null | awk '{
    status = "M"
    if ($1 == "A") status = "A"
    else if ($1 == "D") status = "D"
    print "{\"path\":\"" $2 "\",\"status\":\"" status "\"}"
}' | jq -s '.' || echo '[]')

# Get untracked files
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))' || echo '[]')

# Get diff stats for staged
STAGED_STATS=$(git diff --cached --numstat 2>/dev/null | awk '{print "{\"path\":\"" $3 "\",\"additions\":" $1 ",\"deletions\":" $2 "}"}' | jq -s '.' || echo '[]')

# Merge staged with stats
STAGED_WITH_STATS=$(echo "$STAGED" "$STAGED_STATS" | jq -s '
  .[0] as $staged | .[1] as $stats |
  $staged | map(. as $file |
    ($stats | map(select(.path == $file.path)) | first // {additions: 0, deletions: 0}) as $stat |
    $file + {additions: $stat.additions, deletions: $stat.deletions}
  )
')

# Get remote status
REMOTE_STATUS=""
if git rev-parse --abbrev-ref @{upstream} >/dev/null 2>&1; then
	AHEAD=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
	BEHIND=$(git rev-list --count HEAD..@{upstream} 2>/dev/null || echo "0")
	REMOTE_STATUS="{\"ahead\":$AHEAD,\"behind\":$BEHIND}"
else
	REMOTE_STATUS='{"ahead":0,"behind":0}'
fi

# Build final JSON
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -n \
	--arg collector "git" \
	--arg timestamp "$TIMESTAMP" \
	--arg branch "$BRANCH" \
	--argjson commits "$COMMITS" \
	--argjson branches "$BRANCHES" \
	--argjson staged "$STAGED_WITH_STATS" \
	--argjson unstaged "$UNSTAGED" \
	--argjson untracked "$UNTRACKED" \
	--argjson remote "$REMOTE_STATUS" \
	'{
        collector: $collector,
        timestamp: $timestamp,
        status: "success",
        data: {
            currentBranch: $branch,
            commits: $commits,
            branches: $branches,
            uncommitted: {
                staged: $staged,
                unstaged: $unstaged,
                untracked: $untracked
            },
            remote: $remote,
            lastFetch: $timestamp
        }
    }'
