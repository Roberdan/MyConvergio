#!/usr/bin/env bash
# branch-protect.sh — Enforce branch protection with conversation resolution
# Usage: branch-protect.sh [check|apply|list] [repo] [branch]
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/lib/colors.sh" ]] && source "$SCRIPT_DIR/lib/colors.sh" 2>/dev/null || {
	red() { echo "$*"; }
	green() { echo "$*"; }
	yellow() { echo "$*"; }
}

for cmd in gh jq; do
	command -v "$cmd" &>/dev/null || {
		echo "ERROR: $cmd not installed" >&2
		exit 1
	}
done

usage() {
	cat <<-'EOF'
		branch-protect.sh <cmd> [repo] [branch]
		  check  [repo] [branch]   Check current protection rules
		  apply  [repo] [branch]   Apply conversation resolution + admin enforcement
		  list                     List all repos with their protection status

		  repo defaults to current git origin; branch defaults to main
	EOF
	exit 0
}

resolve_repo() {
	local repo="${1:-}"
	if [[ -n "$repo" ]]; then
		echo "$repo"
		return
	fi
	local remote_url
	remote_url=$(git remote get-url origin 2>/dev/null || echo "")
	if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
		echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
	else
		echo "ERROR: Cannot resolve repo. Provide owner/repo as argument." >&2
		exit 1
	fi
}

resolve_branch() {
	echo "${1:-main}"
}

cmd_check() {
	local repo branch
	repo=$(resolve_repo "${1:-}")
	branch=$(resolve_branch "${2:-}")

	echo "=== Branch Protection: $repo ($branch) ==="

	local protection
	protection=$(gh api "repos/${repo}/branches/${branch}/protection" 2>/dev/null) || protection='{"error": true}'

	if echo "$protection" | jq -e '.error // .message' &>/dev/null; then
		echo "Status: NO PROTECTION RULES"
		echo ""
		echo "Recommendation: run 'branch-protect.sh apply $repo $branch'"
		return 1
	fi

	local conv_resolution enforce_admins required_reviews
	conv_resolution=$(echo "$protection" | jq -r '.required_conversation_resolution.enabled // false')
	enforce_admins=$(echo "$protection" | jq -r '.enforce_admins.enabled // false')
	required_reviews=$(echo "$protection" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')

	local status_checks
	status_checks=$(echo "$protection" | jq -r '.required_status_checks.strict // false')

	echo "Conversation resolution required: $conv_resolution"
	echo "Enforce admins: $enforce_admins"
	echo "Required reviews: $required_reviews"
	echo "Strict status checks: $status_checks"

	local issues=0
	if [[ "$conv_resolution" != "true" ]]; then
		echo ""
		echo "WARNING: Conversation resolution NOT enforced — PRs can merge with unresolved comments"
		issues=$((issues + 1))
	fi
	if [[ "$enforce_admins" != "true" ]]; then
		echo "WARNING: Admin bypass enabled — admins can skip protection rules"
		issues=$((issues + 1))
	fi

	if [[ "$issues" -eq 0 ]]; then
		echo ""
		echo "PROTECTED"
		return 0
	else
		echo ""
		echo "$issues issue(s) found. Run: branch-protect.sh apply $repo $branch"
		return 1
	fi
}

cmd_apply() {
	local repo branch
	repo=$(resolve_repo "${1:-}")
	branch=$(resolve_branch "${2:-}")

	echo "Applying branch protection to $repo ($branch)..."

	# Fetch existing protection to preserve current settings
	local existing
	existing=$(gh api "repos/${repo}/branches/${branch}/protection" 2>/dev/null) || existing='{}'

	# Build protection payload preserving existing settings (jq ensures valid JSON)
	local payload
	payload=$(echo "$existing" | jq '{
		required_status_checks: {
			strict: (.required_status_checks.strict // true),
			contexts: (.required_status_checks.contexts // [])
		},
		enforce_admins: true,
		required_pull_request_reviews: {
			required_approving_review_count: (.required_pull_request_reviews.required_approving_review_count // 0),
			dismiss_stale_reviews: (.required_pull_request_reviews.dismiss_stale_reviews // false)
		},
		restrictions: null,
		required_conversation_resolution: true
	}')

	echo "$payload" | gh api -X PUT "repos/${repo}/branches/${branch}/protection" --input - >/dev/null

	echo "Applied:"
	echo "  - required_conversation_resolution: true"
	echo "  - enforce_admins: true"
	echo "  - Preserved existing status checks and review requirements"
	echo ""
	echo "Verify: branch-protect.sh check $repo $branch"
}

cmd_list() {
	echo "=== Repos with branch protection status ==="
	local repos
	repos=$(gh repo list --json nameWithOwner,defaultBranchRef --jq '.[] | "\(.nameWithOwner) \(.defaultBranchRef.name)"' 2>/dev/null || echo "")

	if [[ -z "$repos" ]]; then
		echo "No repos found or gh auth issue"
		return 1
	fi

	while IFS=' ' read -r repo branch; do
		local protection
		protection=$(gh api "repos/${repo}/branches/${branch}/protection" 2>/dev/null) || protection='{"error": true}'
		local conv
		conv=$(echo "$protection" | jq -r '.required_conversation_resolution.enabled // false' 2>/dev/null || echo "none")
		printf "%-40s %-8s conv_resolution=%s\n" "$repo" "$branch" "$conv"
	done <<<"$repos"
}

CMD="${1:-}"
shift 2>/dev/null || true

case "$CMD" in
check) cmd_check "$@" ;;
apply) cmd_apply "$@" ;;
list) cmd_list "$@" ;;
-h | --help | help | "") usage ;;
*)
	echo "Unknown: $CMD"
	usage
	;;
esac
