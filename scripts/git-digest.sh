#!/usr/bin/env bash
# Git Digest - All git state in ONE call as JSON
# Replaces: git status + git diff --stat + git log --oneline + git branch
# Usage: git-digest.sh [--full] [--no-cache]
#   Default: compact status (~15 lines JSON)
#   --full: includes file-level diff details
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=5
NO_CACHE=0
FULL=0

for arg in "$@"; do
	case "$arg" in
	--full) FULL=1 ;;
	--no-cache) NO_CACHE=1 ;;
	esac
done

# Short TTL — git state changes often. 5s avoids rapid double-calls.
CACHE_KEY="git-$(pwd | md5sum 2>/dev/null | cut -c1-8 || echo 'x')-${FULL}"

if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# Gather everything in minimal subshell calls
BRANCH=$(git branch --show-current 2>/dev/null || echo "DETACHED")
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "")

# Ahead/behind tracking branch
UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
AHEAD=0
BEHIND=0
if [[ -n "$UPSTREAM" ]]; then
	AB=$(git rev-list --left-right --count HEAD..."$UPSTREAM" 2>/dev/null || echo "0 0")
	AHEAD=$(echo "$AB" | awk '{print $1}')
	BEHIND=$(echo "$AB" | awk '{print $2}')
fi

# Status counts (one git status call, parsed)
STATUS_RAW=$(git status --porcelain 2>/dev/null || echo "")
STAGED=0
UNSTAGED=0
UNTRACKED=0
CONFLICTS=0

if [[ -n "$STATUS_RAW" ]]; then
	STAGED=$(echo "$STATUS_RAW" | grep -cE '^[MADRC]') || STAGED=0
	UNSTAGED=$(echo "$STATUS_RAW" | grep -cE '^.[MADRC]') || UNSTAGED=0
	UNTRACKED=$(echo "$STATUS_RAW" | grep -cE '^\?\?') || UNTRACKED=0
	CONFLICTS=$(echo "$STATUS_RAW" | grep -cE '^(UU|AA|DD)') || CONFLICTS=0
fi

CLEAN="true"
[[ "$STAGED" -gt 0 || "$UNSTAGED" -gt 0 || "$UNTRACKED" -gt 0 ]] && CLEAN="false"

# Recent commits (compact: hash + subject)
COMMITS=$(git log --oneline -5 2>/dev/null |
	jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null) || COMMITS="[]"

# Stash count
STASH_COUNT=$(git stash list 2>/dev/null | grep -c .) || STASH_COUNT=0

# Build result
if [[ "$FULL" -eq 1 ]]; then
	# File-level details (default to empty arrays)
	STAGED_FILES="[]"
	UNSTAGED_FILES="[]"
	UNTRACKED_FILES="[]"
	if [[ -n "$STATUS_RAW" ]]; then
		STAGED_FILES=$(echo "$STATUS_RAW" | grep -E '^[MADRC]' |
			awk '{print $2}' |
			jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null) || STAGED_FILES="[]"
		UNSTAGED_FILES=$(echo "$STATUS_RAW" | grep -E '^.[MADRC]' |
			awk '{print $2}' |
			jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null) || UNSTAGED_FILES="[]"
		UNTRACKED_FILES=$(echo "$STATUS_RAW" | grep -E '^\?\?' |
			awk '{print $2}' |
			jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null) || UNTRACKED_FILES="[]"
	fi

	RESULT=$(jq -n \
		--arg branch "$BRANCH" \
		--arg sha "$SHA" \
		--argjson clean "$CLEAN" \
		--argjson ahead "$AHEAD" \
		--argjson behind "$BEHIND" \
		--argjson staged "$STAGED" \
		--argjson unstaged "$UNSTAGED" \
		--argjson untracked "$UNTRACKED" \
		--argjson conflicts "$CONFLICTS" \
		--argjson stashes "$STASH_COUNT" \
		--argjson commits "$COMMITS" \
		--argjson staged_files "$STAGED_FILES" \
		--argjson unstaged_files "$UNSTAGED_FILES" \
		--argjson untracked_files "$UNTRACKED_FILES" \
		'{branch:$branch, sha:$sha, clean:$clean,
		  ahead:$ahead, behind:$behind,
		  staged:$staged, unstaged:$unstaged, untracked:$untracked,
		  conflicts:$conflicts, stashes:$stashes,
		  staged_files:$staged_files, unstaged_files:$unstaged_files,
		  untracked_files:$untracked_files, commits:$commits}')
else
	RESULT=$(jq -n \
		--arg branch "$BRANCH" \
		--arg sha "$SHA" \
		--argjson clean "$CLEAN" \
		--argjson ahead "$AHEAD" \
		--argjson behind "$BEHIND" \
		--argjson staged "$STAGED" \
		--argjson unstaged "$UNSTAGED" \
		--argjson untracked "$UNTRACKED" \
		--argjson conflicts "$CONFLICTS" \
		--argjson stashes "$STASH_COUNT" \
		--argjson commits "$COMMITS" \
		'{branch:$branch, sha:$sha, clean:$clean,
		  ahead:$ahead, behind:$behind,
		  staged:$staged, unstaged:$unstaged, untracked:$untracked,
		  conflicts:$conflicts, stashes:$stashes, commits:$commits}')
fi

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
echo "$RESULT"
