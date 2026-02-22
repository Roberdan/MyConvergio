#!/usr/bin/env bash
# Copilot Review Digest - Token-optimized digest of Copilot bot comments from a PR
# Extracts severity (P1/P2/P3) and category from Copilot review comments.
# Usage: copilot-review-digest.sh [pr-number] [--no-cache]
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

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

CACHE_TTL=60
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
		PR_NUM=$(gh_api 'pulls?state=open' --jq ".[] | select(.head.ref == \"$BRANCH\") | .number" 2>/dev/null | head -1)
	fi
fi

# Fallback: most recent open PR
if [[ -z "$PR_NUM" ]]; then
	PR_NUM=$(gh_api 'pulls?state=open&per_page=1' --jq '.[0].number' 2>/dev/null || echo "")
fi

if [[ -z "$PR_NUM" ]]; then
	jq -n '{"pr":null,"status":"no_pr","copilot_comments":0,"by_severity":{},"by_category":{},"comments":[]}'
	exit 0
fi

# Cache check
CACHE_KEY="copilot-review-${PR_NUM}"
if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# Bot authors to INCLUDE (inverse of pr-digest.sh which excludes bots)
BOT_INCLUDE='^(Copilot|copilot\[bot\]|chatgpt-codex-connector\[bot\])$'

# Fetch review comments (inline code comments)
REVIEW_COMMENTS=$(gh_api "pulls/${PR_NUM}/comments" \
	--paginate --jq '.' 2>/dev/null || echo "[]")

# Fetch issue comments (general PR comments)
ISSUE_COMMENTS=$(gh_api "issues/${PR_NUM}/comments" \
	--paginate --jq '.' 2>/dev/null || echo "[]")

# Filter and process Copilot comments
COPILOT_COMMENTS=$(jq -n \
	--argjson review "$REVIEW_COMMENTS" \
	--argjson issue "$ISSUE_COMMENTS" \
	--arg bot_pat "$BOT_INCLUDE" \
	'
# Detect severity from badge images or text markers
def detect_severity:
	if test("P1|critical|🔴|severity.*1|high-severity|P1-orange") then "P1"
	elif test("P2|warning|🟡|severity.*2|medium-severity|P2-yellow") then "P2"
	else "P3"
	end;

# Detect category from body keywords
def detect_category:
	if test("(?i)security|vulnerab|injection|xss|csrf|auth") then "security"
	elif test("(?i)null|undefined|optional|nullable|null.safe") then "null_safety"
	elif test("(?i)error.handl|catch|exception|try.catch|unhandled") then "error_handling"
	elif test("(?i)perform|scale|memory|O\\(n|pagination|aggregate") then "performance"
	elif test("(?i)architect|pattern|coupling|cohesion|separation") then "architecture"
	elif test("(?i)test|coverage|mock|assert|spec|fixture") then "test_quality"
	elif test("(?i)logic|incorrect|wrong|bug|off.by|boundary") then "logic"
	else "other"
	end;

# Process inline review comments from Copilot bots
([$review[] | select(.user.login | test($bot_pat))] |
	map({
		severity: (.body | detect_severity),
		category: (.body | detect_category),
		file: .path,
		line: (.line // .original_line // null),
		body: (.body | .[0:300])
	})) +
# Process issue comments from Copilot bots
([$issue[] | select(.user.login | test($bot_pat))] |
	map({
		severity: (.body | detect_severity),
		category: (.body | detect_category),
		file: null,
		line: null,
		body: (.body | .[0:300])
	}))
')

# Build final JSON with aggregation
RESULT=$(echo "$COPILOT_COMMENTS" | jq --arg pr "$PR_NUM" '
{
	pr: ($pr | tonumber),
	copilot_comments: length,
	by_severity: (group_by(.severity) | map({key: .[0].severity, value: length}) | from_entries),
	by_category: (group_by(.category) | map({key: .[0].category, value: length}) | from_entries),
	comments: .
}')

# Cache and output
echo "$RESULT" | digest_cache_set "$CACHE_KEY"
echo "$RESULT"
