#!/usr/bin/env bash
# pr-ops.sh - PR write/action operations (reply, resolve, merge, status)
# Complements pr-digest.sh (read-only) with correct API calls.
# Usage: pr-ops.sh <command> [args...]
# Version: 2.0.0 - Modularized
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "${SCRIPT_DIR}/lib/pr-ops-api.sh"

# --- Dependencies ---
for cmd in gh jq; do
	command -v "$cmd" &>/dev/null || {
		echo "ERROR: $cmd not installed"
		exit 1
	}
done

usage() {
	echo "pr-ops.sh <cmd> [args] — status|reply|comment|resolve|ready|merge|ci"
	echo "  reply <pr> <comment_id> \"msg\"  |  comment <pr> \"msg\"  |  resolve <pr>"
	echo "  ready/merge/ci/status [pr]  (PR auto-resolved from branch if omitted)"
	exit 0
}

# --- Commands ---
cmd_status() {
	local pr
	pr=$(resolve_pr "${1:-}")
	"$SCRIPT_DIR/pr-digest.sh" "$pr" --no-cache
}

cmd_reply() {
	local pr="${1:-}" comment_id="${2:-}" msg="${3:-}"
	if [[ -z "$pr" || -z "$comment_id" || -z "$msg" ]]; then
		echo "Usage: pr-ops.sh reply <pr> <comment_id> \"message\""
		exit 1
	fi
	local result
	result=$(gh_api "pulls/${pr}/comments" \
		-F body="$msg" -F "in_reply_to=$comment_id" \
		--jq '{id: .id, author: .user.login, created: .created_at}' 2>&1) || {
		echo "ERROR: Reply failed: $result" >&2
		exit 1
	}
	echo "Reply posted: $(echo "$result" | jq -r '.id')"
}

cmd_comment() {
	local pr="${1:-}" msg="${2:-}"
	if [[ -z "$pr" || -z "$msg" ]]; then
		echo "Usage: pr-ops.sh comment <pr> \"message\""
		exit 1
	fi
	gh pr comment "$pr" --body "$msg"
	echo "Comment posted on PR #$pr"
}

cmd_resolve() {
	local pr
	pr=$(resolve_pr "${1:-}")
	local threads_json
	threads_json=$(gql_review_threads "$pr")
	local unresolved
	unresolved=$(echo "$threads_json" | jq '[.[] | select(.isResolved == false)]')
	local count
	count=$(echo "$unresolved" | jq 'length')
	if [[ "$count" -eq 0 ]]; then
		echo "All threads already resolved on PR #$pr"
		exit 0
	fi
	echo "Resolving $count thread(s) on PR #$pr..."
	local resolved=0
	for thread_id in $(echo "$unresolved" | jq -r '.[].id'); do
		gh api graphql -f query='
			mutation($threadId: ID!) {
				resolveReviewThread(input: { threadId: $threadId }) {
					thread { isResolved }
				}
			}' -F "threadId=$thread_id" --silent 2>/dev/null && resolved=$((resolved + 1))
	done
	echo "Resolved: $resolved/$count threads"
}

cmd_ready() {
	local pr
	pr=$(resolve_pr "${1:-}")
	# Use REST API for base metadata (GraphQL has numbering issues on forks)
	local meta
	meta=$(gh_api "pulls/${pr}" \
		--jq '{state: (.state | ascii_upcase), mergeable: (if .mergeable then "MERGEABLE" elif .mergeable == false then "CONFLICTING" else "UNKNOWN" end), mergeStateStatus: (.mergeable_state // "UNKNOWN" | ascii_upcase)}' 2>/dev/null || echo "{}")
	local state
	state=$(echo "$meta" | jq -r '.state')
	# reviewDecision via reviews endpoint
	local decision
	decision=$(gh_api "pulls/${pr}/reviews" \
		--jq '[.[] | .state] | if any(. == "CHANGES_REQUESTED") then "CHANGES_REQUESTED" elif any(. == "APPROVED") then "APPROVED" else "PENDING" end' 2>/dev/null || echo "PENDING")
	local mergeable
	mergeable=$(echo "$meta" | jq -r '.mergeable // "UNKNOWN"')
	local merge_status
	merge_status=$(echo "$meta" | jq -r '.mergeStateStatus // "UNKNOWN"')

	# CI status via check-runs and statuses endpoints
	local sha
	sha=$(gh_api "pulls/${pr}" --jq '.head.sha' 2>/dev/null || echo "")
	local ci_pass=0 ci_fail=0 ci_pending=0
	if [[ -n "$sha" ]]; then
		local check_data
		check_data=$(gh_api "commits/${sha}/check-runs" --jq '.check_runs' 2>/dev/null || echo "[]")
		ci_pass=$(echo "$check_data" | jq '[.[] | select(.conclusion == "success" or .conclusion == "skipped" or .conclusion == "neutral")] | length')
		ci_fail=$(echo "$check_data" | jq '[.[] | select(.conclusion == "failure")] | length')
		ci_pending=$(echo "$check_data" | jq '[.[] | select(.status != "completed")] | length')
	fi

	# Unresolved threads via GraphQL
	local threads_json
	threads_json=$(gql_review_threads "$pr" 2>/dev/null || echo "[]")
	local unresolved_threads
	unresolved_threads=$(echo "$threads_json" | jq '[.[]? | select(.isResolved == false)] | length')

	echo "=== PR #$pr Merge Readiness ==="
	echo "State: $state | Review: $decision | Mergeable: $mergeable"
	echo "CI: $ci_pass pass, $ci_fail fail, $ci_pending pending"
	echo "Unresolved threads: $unresolved_threads"
	echo "Merge status: $merge_status"

	local blockers=0
	[[ "$state" != "OPEN" ]] && {
		echo "BLOCKER: PR is $state"
		blockers=$((blockers + 1))
	}
	[[ "$ci_fail" -gt 0 ]] && {
		echo "BLOCKER: $ci_fail CI check(s) failing"
		blockers=$((blockers + 1))
	}
	[[ "$ci_pending" -gt 0 ]] && {
		echo "BLOCKER: $ci_pending CI check(s) pending"
		blockers=$((blockers + 1))
	}
	[[ "$decision" == "CHANGES_REQUESTED" ]] && {
		echo "BLOCKER: Changes requested"
		blockers=$((blockers + 1))
	}
	[[ "$unresolved_threads" -gt 0 ]] && {
		echo "BLOCKER: $unresolved_threads unresolved thread(s)"
		blockers=$((blockers + 1))
	}
	[[ "$mergeable" == "CONFLICTING" ]] && {
		echo "BLOCKER: Merge conflicts"
		blockers=$((blockers + 1))
	}

	if [[ "$blockers" -eq 0 ]]; then
		echo "READY TO MERGE"
		exit 0
	else
		echo "$blockers BLOCKER(S) - NOT READY"
		exit 1
	fi
}

cmd_merge() {
	local pr
	pr=$(resolve_pr "${1:-}")
	if cmd_ready "$pr" >/dev/null 2>&1; then
		echo "PR #$pr is ready. Merging..."
		gh pr merge "$pr" --squash --delete-branch
		echo "PR #$pr merged successfully"
	else
		echo "PR #$pr not ready to merge. Blockers:"
		cmd_ready "$pr" 2>&1 | grep "BLOCKER:" || true
		exit 1
	fi
}

cmd_ci() {
	local pr
	pr=$(resolve_pr "${1:-}")
	local branch
	branch=$(gh_api "pulls/${pr}" --jq '.head.ref' 2>/dev/null || echo "")
	[[ -z "$branch" ]] && {
		echo "ERROR: Cannot get branch for PR #$pr"
		exit 1
	}
	local run_id
	run_id=$(gh run list --branch "$branch" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
	[[ -z "$run_id" ]] && {
		echo "No CI runs found for branch $branch"
		exit 1
	}
	"$SCRIPT_DIR/ci-digest.sh" "$run_id"
}

# --- Dispatch ---
CMD="${1:-}"
shift 2>/dev/null || true

case "$CMD" in
status) cmd_status "$@" ;;
reply) cmd_reply "$@" ;;
comment) cmd_comment "$@" ;;
resolve) cmd_resolve "$@" ;;
ready) cmd_ready "$@" ;;
merge) cmd_merge "$@" ;;
ci) cmd_ci "$@" ;;
-h | --help | help | "") usage ;;
*)
	echo "Unknown command: $CMD"
	usage
	;;
esac
