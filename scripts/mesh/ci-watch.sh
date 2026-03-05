#!/usr/bin/env bash
set -euo pipefail
# ci-watch.sh — Poll CI check-runs for a branch/SHA with exponential backoff
# Usage: ci-watch.sh [branch] [--repo owner/repo] [--timeout SEC] [--sha SHA]
# Output: JSON {branch, sha, status: pass|fail|pending|timeout|no_checks, checks:[{name,conclusion}], elapsed_sec}
# Version: 1.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
BRANCH="main"
REPO=""
SHA=""
TIMEOUT=180
START_TIME=$(date +%s)

# ── Arg parsing ───────────────────────────────────────────────────────────────
usage() {
	echo "usage: ci-watch.sh [branch] [--repo owner/repo] [--timeout SEC] [--sha SHA]" >&2
	echo "" >&2
	echo "  branch           Branch to watch (default: main)" >&2
	echo "  --repo           GitHub repo as owner/repo (resolved from git remote if omitted)" >&2
	echo "  --timeout SEC    Max wait time in seconds (default: 180)" >&2
	echo "  --sha SHA        Specific commit SHA to watch (resolved from branch if omitted)" >&2
	exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
	case "$1" in
	--help | -h) usage ;;
	--repo)
		REPO="$2"
		shift 2
		;;
	--timeout)
		TIMEOUT="$2"
		shift 2
		;;
	--sha)
		SHA="$2"
		shift 2
		;;
	--*)
		echo "Unknown option: $1" >&2
		exit 1
		;;
	*)
		POSITIONAL+=("$1")
		shift
		;;
	esac
done

[[ ${#POSITIONAL[@]} -gt 0 ]] && BRANCH="${POSITIONAL[0]}"

# ── Resolve repo from git remote ──────────────────────────────────────────────
resolve_repo() {
	local remote_url
	remote_url=$(git remote get-url origin 2>/dev/null || echo "")
	if [[ -z "$remote_url" ]]; then
		echo ""
		return
	fi
	# Handle SSH (git@github.com:owner/repo.git) and HTTPS
	echo "$remote_url" | sed -E \
		's|git@github\.com:([^/]+/[^.]+)\.git|\1|;
     s|https://github\.com/([^/]+/[^/]+)(\.git)?|\1|'
}

[[ -z "$REPO" ]] && REPO=$(resolve_repo)

# ── Resolve SHA ───────────────────────────────────────────────────────────────
resolve_sha() {
	local sha=""
	# Try local git first (fast)
	sha=$(git rev-parse "origin/${BRANCH}" 2>/dev/null || echo "")
	if [[ -n "$sha" ]]; then
		echo "$sha"
		return
	fi
	# Fallback to GitHub API
	if [[ -n "$REPO" ]]; then
		sha=$(gh api "repos/${REPO}/commits/${BRANCH}" --jq '.sha' 2>/dev/null || echo "")
	fi
	echo "$sha"
}

if [[ -z "$SHA" ]]; then
	SHA=$(resolve_sha)
fi

if [[ -z "$SHA" ]]; then
	jq -n --arg branch "$BRANCH" \
		'{branch:$branch, sha:null, status:"no_checks", checks:[], elapsed_sec:0}'
	exit 0
fi

SHA_SHORT="${SHA:0:7}"

# ── Fetch check-runs ──────────────────────────────────────────────────────────
fetch_checks() {
	local sha="$1"
	local endpoint="commits/${sha}/check-runs"
	local api_path
	api_path="${REPO:+repos/${REPO}/}${endpoint}"
	[[ -z "$REPO" ]] && api_path="commits/${sha}/check-runs"

	local raw
	if [[ -n "$REPO" ]]; then
		raw=$(gh api "repos/${REPO}/commits/${sha}/check-runs" \
			--jq '.check_runs // []' 2>/dev/null || echo "[]")
	else
		raw=$(gh api "commits/${sha}/check-runs" \
			--jq '.check_runs // []' 2>/dev/null || echo "[]")
	fi
	echo "$raw"
}

# ── Polling loop ──────────────────────────────────────────────────────────────
# Backoff schedule: 5, 10, 20, 30, 30, 30, ... seconds
backoff_delay() {
	local attempt="$1"
	case "$attempt" in
	0) echo 5 ;;
	1) echo 10 ;;
	2) echo 20 ;;
	*) echo 30 ;;
	esac
}

FIRST_CHECKS_AT=""
ATTEMPT=0

while true; do
	NOW=$(date +%s)
	ELAPSED=$((NOW - START_TIME))

	if [[ $ELAPSED -ge $TIMEOUT ]]; then
		jq -n \
			--arg branch "$BRANCH" \
			--arg sha "$SHA_SHORT" \
			--argjson elapsed "$ELAPSED" \
			'{branch:$branch, sha:$sha, status:"timeout", checks:[], elapsed_sec:$elapsed}'
		exit 0
	fi

	CHECKS_RAW=$(fetch_checks "$SHA")
	COUNT=$(echo "$CHECKS_RAW" | jq 'length')

	if [[ "$COUNT" -eq 0 ]]; then
		# No checks found yet — wait up to 30s before returning no_checks
		[[ -z "$FIRST_CHECKS_AT" ]] && FIRST_CHECKS_AT="$NOW"
		WAIT_FOR_CHECKS=$((NOW - FIRST_CHECKS_AT))
		if [[ $WAIT_FOR_CHECKS -ge 30 ]]; then
			jq -n \
				--arg branch "$BRANCH" \
				--arg sha "$SHA_SHORT" \
				--argjson elapsed "$ELAPSED" \
				'{branch:$branch, sha:$sha, status:"no_checks", checks:[], elapsed_sec:$elapsed}'
			exit 0
		fi
	else
		# Build compact checks array
		CHECKS=$(echo "$CHECKS_RAW" | jq '[.[] | {
      name: .name,
      conclusion: (
        if .conclusion == "success" then "pass"
        elif .conclusion == "failure" then "fail"
        elif .conclusion == "cancelled" then "fail"
        elif .conclusion == null and .status == "in_progress" then "pending"
        elif .conclusion == null and .status == "queued" then "pending"
        else (.conclusion // .status // "unknown")
        end
      )
    }]')

		PENDING_N=$(echo "$CHECKS" | jq '[.[] | select(.conclusion == "pending")] | length')
		FAIL_N=$(echo "$CHECKS" | jq '[.[] | select(.conclusion == "fail")] | length')

		NOW=$(date +%s)
		ELAPSED=$((NOW - START_TIME))

		if [[ "$PENDING_N" -eq 0 ]]; then
			# All checks completed
			STATUS="pass"
			[[ "$FAIL_N" -gt 0 ]] && STATUS="fail"
			jq -n \
				--arg branch "$BRANCH" \
				--arg sha "$SHA_SHORT" \
				--arg status "$STATUS" \
				--argjson checks "$CHECKS" \
				--argjson elapsed "$ELAPSED" \
				'{branch:$branch, sha:$sha, status:$status, checks:$checks, elapsed_sec:$elapsed}'
			exit 0
		fi
	fi

	# Not done yet — sleep then retry
	DELAY=$(backoff_delay "$ATTEMPT")
	ATTEMPT=$((ATTEMPT + 1))

	REMAINING=$((TIMEOUT - ELAPSED))
	[[ $DELAY -gt $REMAINING ]] && DELAY=$REMAINING
	[[ $DELAY -le 0 ]] && continue

	sleep "$DELAY"
done
