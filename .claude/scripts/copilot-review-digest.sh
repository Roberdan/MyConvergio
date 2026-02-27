#!/usr/bin/env bash
# Usage: copilot-review-digest.sh [pr-number] [--no-cache]
# Version: 1.2.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

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
COMPACT=0
digest_check_compact "$@"
PR_NUM=""
for arg in "$@"; do
	[[ "$arg" == "--no-cache" ]] && {
		NO_CACHE=1
		continue
	}
	[[ "$arg" == "--compact" ]] && continue
	[[ -z "$PR_NUM" ]] && PR_NUM="$arg"
done

if [[ -z "$PR_NUM" ]]; then
	BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
	if [[ -n "$BRANCH" ]]; then
		PR_NUM=$(gh_api 'pulls?state=open' --jq ".[] | select(.head.ref == \"$BRANCH\") | .number" 2>/dev/null | head -1)
	fi
fi

if [[ -z "$PR_NUM" ]]; then
	PR_NUM=$(gh_api 'pulls?state=open&per_page=1' --jq '.[0].number' 2>/dev/null || echo "")
fi

if [[ -z "$PR_NUM" ]]; then
	jq -n '{"pr":null,"status":"no_pr","copilot_comments":0,"by_severity":{},"by_category":{},"comments":[]}'
	exit 0
fi

CACHE_KEY="copilot-review-${PR_NUM}"
if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# Inverse of pr-digest.sh bot filter: here we INCLUDE only Copilot bots
BOT_INCLUDE='^(Copilot|copilot\[bot\]|chatgpt-codex-connector\[bot\])$'

REVIEW_COMMENTS=$(gh_api "pulls/${PR_NUM}/comments" \
	--paginate --jq '.' 2>/dev/null || echo "[]")

ISSUE_COMMENTS=$(gh_api "issues/${PR_NUM}/comments" \
	--paginate --jq '.' 2>/dev/null || echo "[]")

COPILOT_COMMENTS=$(jq -n \
	--argjson review "$REVIEW_COMMENTS" \
	--argjson issue "$ISSUE_COMMENTS" \
	--arg bot_pat "$BOT_INCLUDE" \
	'
def detect_severity:
	if test("P1|critical|🔴|severity.*1|high-severity|P1-orange") then "P1"
	elif test("P2|warning|🟡|severity.*2|medium-severity|P2-yellow") then "P2"
	else "P3"
	end;

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

([$review[] | select(.user.login | test($bot_pat))] |
	map({
		severity: (.body | detect_severity),
		category: (.body | detect_category),
		file: .path,
		line: (.line // .original_line // null),
		body: (.body | .[0:300])
	})) +
([$issue[] | select(.user.login | test($bot_pat))] |
	map({
		severity: (.body | detect_severity),
		category: (.body | detect_category),
		file: null,
		line: null,
		body: (.body | .[0:300])
	}))
')

RESULT=$(echo "$COPILOT_COMMENTS" | jq --arg pr "$PR_NUM" '
{
	pr: ($pr | tonumber),
	copilot_comments: length,
	by_severity: (group_by(.severity) | map({key: .[0].severity, value: length}) | from_entries),
	by_category: (group_by(.category) | map({key: .[0].category, value: length}) | from_entries),
	comments: .
}')

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
# --compact: only severity summary + comments (skip by_category)
echo "$RESULT" | COMPACT=$COMPACT digest_compact_filter 'copilot_comments, by_severity, comments'
