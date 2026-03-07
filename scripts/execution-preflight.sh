#!/usr/bin/env bash
# execution-preflight.sh - Compact execution readiness snapshot for planner/executor workflows
# Usage: execution-preflight.sh [--text] [path]
# Version: 1.0.0
set -euo pipefail

MODE="json"
TARGET="."
PLAN_ID=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--text)
		MODE="text"
		shift
		;;
	--plan-id)
		PLAN_ID="${2:-}"
		shift 2
		;;
	-h | --help)
		cat <<'EOF'
Usage: execution-preflight.sh [--text] [--plan-id ID] [path]

Outputs a compact execution-readiness snapshot for the target repo/worktree.
Default output is JSON.
EOF
		exit 0
		;;
	*)
		TARGET="$1"
		shift
		;;
	esac
done

cd "$TARGET"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BRANCH="$(git branch --show-current 2>/dev/null || echo "")"
DIRTY_COUNT="$(git status --porcelain 2>/dev/null | awk 'NF {count++} END {print count + 0}')"
REMOTE_URL="$(git remote get-url origin 2>/dev/null || echo "")"

HAS_TROUBLESHOOTING=false
[[ -f "$REPO_ROOT/TROUBLESHOOTING.md" ]] && HAS_TROUBLESHOOTING=true

CI_KNOWLEDGE_PATH=""
for candidate in \
	"$REPO_ROOT/.claude/ci-knowledge.md" \
	"$REPO_ROOT/docs/ci-knowledge.md" \
	"$HOME/.claude/data/ci-knowledge/$(basename "$REPO_ROOT").md"; do
	if [[ -f "$candidate" ]]; then
		CI_KNOWLEDGE_PATH="$candidate"
		break
	fi
done

ADR_COUNT=0
if [[ -d "$REPO_ROOT/docs/adr" ]]; then
	ADR_COUNT="$(find "$REPO_ROOT/docs/adr" -maxdepth 1 -type f -name '*.md' | wc -l | awk '{print $1}')"
fi

CHANGELOG_PRESENT=false
[[ -f "$REPO_ROOT/CHANGELOG.md" ]] && CHANGELOG_PRESENT=true

README_PRESENT=false
[[ -f "$REPO_ROOT/README.md" ]] && README_PRESENT=true

VERSION_HINT=""
if [[ -f "$REPO_ROOT/CHANGELOG.md" ]]; then
	VERSION_HINT="$(sed -nE 's/^## \[(v[^]]+)\].*/\1/p' "$REPO_ROOT/CHANGELOG.md" | sed -n '1p')"
fi

GH_AUTH_STATUS="unavailable"
GH_ACCOUNT=""
if command -v gh >/dev/null 2>&1; then
	GH_STATUS_RAW="$(gh auth status 2>&1 || true)"
	if [[ "$GH_STATUS_RAW" == *"Logged in to github.com account "* ]]; then
		GH_AUTH_STATUS="authenticated"
		GH_ACCOUNT="$(printf '%s\n' "$GH_STATUS_RAW" | sed -nE 's/.*Logged in to github.com account ([^ ]+).*/\1/p' | sed -n '1p')"
	else
		GH_AUTH_STATUS="unauthenticated"
	fi
fi

WARNINGS=()
[[ -z "$BRANCH" ]] && WARNINGS+=("missing_branch")
[[ "$DIRTY_COUNT" -gt 0 ]] && WARNINGS+=("dirty_worktree")
[[ "$HAS_TROUBLESHOOTING" != true ]] && WARNINGS+=("missing_troubleshooting")
[[ -z "$CI_KNOWLEDGE_PATH" ]] && WARNINGS+=("missing_ci_knowledge")
[[ "$ADR_COUNT" -eq 0 ]] && WARNINGS+=("missing_adrs")
[[ "$CHANGELOG_PRESENT" != true ]] && WARNINGS+=("missing_changelog")
[[ "$GH_AUTH_STATUS" != "authenticated" ]] && WARNINGS+=("gh_auth_not_ready")

WARNINGS_JSON="$(printf '%s\n' "${WARNINGS[@]-}" | jq -Rsc 'split("\n") | map(select(length > 0))')"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
GENERATED_EPOCH="$(date +%s)"

if [[ "$MODE" == "text" ]]; then
	echo "repo_root=$REPO_ROOT"
	echo "branch=$BRANCH"
	echo "dirty_count=$DIRTY_COUNT"
	echo "gh_auth_status=$GH_AUTH_STATUS"
	echo "gh_account=$GH_ACCOUNT"
	echo "has_troubleshooting=$HAS_TROUBLESHOOTING"
	echo "ci_knowledge_path=$CI_KNOWLEDGE_PATH"
	echo "adr_count=$ADR_COUNT"
	echo "changelog_present=$CHANGELOG_PRESENT"
	echo "readme_present=$README_PRESENT"
	echo "version_hint=$VERSION_HINT"
	echo "remote_url=$REMOTE_URL"
	echo "warnings=$(echo "$WARNINGS_JSON" | jq -cr '.')"
	exit 0
fi

OUTPUT="$(jq -cn \
	--arg repo_root "$REPO_ROOT" \
	--arg branch "$BRANCH" \
	--arg remote_url "$REMOTE_URL" \
	--arg gh_auth_status "$GH_AUTH_STATUS" \
	--arg gh_account "$GH_ACCOUNT" \
	--arg ci_knowledge_path "$CI_KNOWLEDGE_PATH" \
	--arg version_hint "$VERSION_HINT" \
	--arg generated_at "$GENERATED_AT" \
	--argjson generated_epoch "$GENERATED_EPOCH" \
	--argjson dirty_count "$DIRTY_COUNT" \
	--argjson has_troubleshooting "$HAS_TROUBLESHOOTING" \
	--argjson adr_count "$ADR_COUNT" \
	--argjson changelog_present "$CHANGELOG_PRESENT" \
	--argjson readme_present "$README_PRESENT" \
	--argjson warnings "$WARNINGS_JSON" \
	'{
	  repo_root: $repo_root,
	  branch: $branch,
	  remote_url: $remote_url,
	  dirty_count: $dirty_count,
	  gh_auth_status: $gh_auth_status,
	  gh_account: $gh_account,
	  has_troubleshooting: $has_troubleshooting,
	  ci_knowledge_path: $ci_knowledge_path,
	  adr_count: $adr_count,
	  changelog_present: $changelog_present,
	  readme_present: $readme_present,
	  version_hint: $version_hint,
	  generated_at: $generated_at,
	  generated_epoch: $generated_epoch,
	  warnings: $warnings
	}')"

if [[ -n "$PLAN_ID" ]]; then
	SNAPSHOT_DIR="$HOME/.claude/data/execution-preflight"
	mkdir -p "$SNAPSHOT_DIR"
	printf '%s\n' "$OUTPUT" >"$SNAPSHOT_DIR/plan-${PLAN_ID}.json"
fi

printf '%s\n' "$OUTPUT"
