#!/usr/bin/env bash
# Diff Digest - Summarize large git diffs as compact JSON
# Use before merge/PR review to understand scope without reading raw diff.
# Usage: diff-digest.sh [base] [head] [--no-cache]
#   diff-digest.sh                    # diff vs main
#   diff-digest.sh main feature/x     # diff between branches
#   diff-digest.sh HEAD~3             # last 3 commits
# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=30
NO_CACHE=0
BASE="${1:-main}"
HEAD="${2:-HEAD}"

[[ "$BASE" == "--no-cache" ]] && {
	NO_CACHE=1
	BASE="${2:-main}"
	HEAD="${3:-HEAD}"
}
[[ "${3:-}" == "--no-cache" ]] && NO_CACHE=1

CACHE_KEY="diff-$(digest_hash "${BASE}..${HEAD}")"

if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# Use three-dot for branch comparison, two-dot for commit range
DIFF_RANGE="${BASE}...${HEAD}"
if [[ "$BASE" == HEAD* ]]; then
	DIFF_RANGE="$BASE"
	HEAD=""
fi

# Get stat summary
STAT=$(git diff --stat "$DIFF_RANGE" 2>/dev/null || echo "")
NUMSTAT=$(git diff --numstat "$DIFF_RANGE" 2>/dev/null || echo "")

if [[ -z "$NUMSTAT" ]]; then
	jq -n --arg base "$BASE" --arg head "$HEAD" \
		'{"base":$base,"head":$head,"files_changed":0,"insertions":0,"deletions":0,"files":[]}'
	exit 0
fi

# Parse numstat into JSON: [{file, add, del}] sorted by total changes desc
FILES_JSON=$(echo "$NUMSTAT" | jq -R -s '
	split("\n") | map(select(length > 0)) | map(
		split("\t") |
		{
			file: .[2],
			add: (if .[0] == "-" then 0 else (.[0] | tonumber) end),
			del: (if .[1] == "-" then 0 else (.[1] | tonumber) end),
			binary: (.[0] == "-"),
			total: (if .[0] == "-" then 0 else (.[0] | tonumber) end) +
			       (if .[1] == "-" then 0 else (.[1] | tonumber) end)
		}
	) | sort_by(-.total)' 2>/dev/null || echo "[]")

# Totals
FILES_CHANGED=$(echo "$FILES_JSON" | jq 'length' 2>/dev/null || echo 0)
TOTAL_ADD=$(echo "$FILES_JSON" | jq '[.[].add] | add // 0' 2>/dev/null || echo 0)
TOTAL_DEL=$(echo "$FILES_JSON" | jq '[.[].del] | add // 0' 2>/dev/null || echo 0)

# File type breakdown
TYPE_BREAKDOWN=$(echo "$FILES_JSON" | jq '
	group_by(.file | split(".") | last) |
	map({
		ext: (.[0].file | split(".") | last),
		count: length,
		lines: ([.[].total] | add)
	}) | sort_by(-.lines) | .[0:8]' 2>/dev/null || echo "[]")

# Top 10 biggest files (for targeted review)
TOP_FILES=$(echo "$FILES_JSON" | jq '.[0:10] | map({file, add, del})' 2>/dev/null || echo "[]")

# Commit count in range
COMMIT_COUNT=$(git rev-list --count "$DIFF_RANGE" 2>/dev/null || echo 0)

RESULT=$(jq -n \
	--arg base "$BASE" \
	--arg head "$HEAD" \
	--argjson files_changed "$FILES_CHANGED" \
	--argjson insertions "$TOTAL_ADD" \
	--argjson deletions "$TOTAL_DEL" \
	--argjson commits "$COMMIT_COUNT" \
	--argjson by_type "$TYPE_BREAKDOWN" \
	--argjson top_files "$TOP_FILES" \
	'{base:$base, head:$head, files_changed:$files_changed,
	  insertions:$insertions, deletions:$deletions, commits:$commits,
	  by_type:$by_type, top_files:$top_files}')

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
echo "$RESULT"
