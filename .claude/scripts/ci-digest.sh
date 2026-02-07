#!/usr/bin/env bash
# CI Digest - Compact GitHub Actions status as JSON (~200 tokens)
# Replaces ci-check.sh for AI consumption. Processes logs server-side.
# Usage: ci-digest.sh [run-id|--all] [--no-cache]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=60
NO_CACHE=0
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
MODE="${1:-}"

[[ "$MODE" == "--no-cache" ]] && {
	NO_CACHE=1
	MODE="${2:-}"
}
[[ "${2:-}" == "--no-cache" ]] && NO_CACHE=1

# Resolve run ID
RUN_ID=""
if [[ "$MODE" =~ ^[0-9]+$ ]]; then
	RUN_ID="$MODE"
elif [[ "$MODE" == "--all" ]]; then
	RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
else
	RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId \
		--jq '.[0].databaseId' 2>/dev/null || echo "")
fi

if [[ -z "$RUN_ID" ]]; then
	jq -n '{"status":"no_runs","errors":[]}'
	exit 0
fi

# Cache check
CACHE_KEY="ci-${RUN_ID}"
if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# Fetch run + jobs in one call (gh supports multiple --json fields)
RUN_JSON=$(gh run view "$RUN_ID" \
	--json status,conclusion,headBranch,headSha,name,jobs 2>/dev/null || echo "{}")

RUN_STATUS=$(echo "$RUN_JSON" | jq -r '.conclusion // .status // "unknown"')
RUN_BRANCH=$(echo "$RUN_JSON" | jq -r '.headBranch // ""')
RUN_SHA=$(echo "$RUN_JSON" | jq -r '.headSha[:7] // ""')
RUN_NAME=$(echo "$RUN_JSON" | jq -r '.name // ""')

# Build jobs array - compact: name + status only
JOBS=$(echo "$RUN_JSON" | jq '[.jobs // [] | .[] | {
	name: .name,
	s: (if .conclusion == "success" then "pass"
		elif .conclusion == "failure" then "fail"
		elif .conclusion == "skipped" then "skip"
		elif .status == "in_progress" then "run"
		else .conclusion // .status // "?" end)
}]')

FAILED_COUNT=$(echo "$JOBS" | jq '[.[] | select(.s == "fail")] | length')

# Extract errors from failed jobs (processed in temp file, never echoed raw)
ERRORS="[]"
if [[ "$FAILED_COUNT" -gt 0 ]]; then
	TMPLOG=$(mktemp)
	trap "rm -f '$TMPLOG'" EXIT

	# Capture log to temp file — never hits tool output
	gh run view "$RUN_ID" --log-failed >"$TMPLOG" 2>/dev/null || true

	if [[ -s "$TMPLOG" ]]; then
		# Extract structured errors: job name + error message
		# Strip ANSI, timestamps, noise. Parse file:line where possible.
		ERRORS=$(cat "$TMPLOG" |
			perl -pe 's/\e\[[0-9;]*m//g' |
			perl -pe 's/\xef\xbb\xbf//g' |
			sed 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:.]*Z //' |
			sed 's/##\[error\]/ERROR: /' |
			grep -iE 'error[:\s]|FAIL|AssertionError|TypeError|ReferenceError|SyntaxError|ENOENT|EPERM|timed.out|P2002|Unique constraint' |
			grep -viE 'Downloading|Setting up|Cache|Restore|Post job|Process completed|exit code|echo |##\[group\]|::warning|::notice' |
			sed 's/^[[:space:]]*//' |
			sed 's/"timestamp":"[^"]*",\{0,1\}//g' |
			sort -u |
			head -10 |
			jq -R -s 'split("\n") | map(select(length > 0)) | map({
				msg: (. | sub("^[^\t]*\t[^\t]*\t"; "") | .[0:200])
			})')
	fi
fi

# Build final JSON
RESULT=$(jq -n \
	--arg run "$RUN_ID" \
	--arg status "$RUN_STATUS" \
	--arg branch "$RUN_BRANCH" \
	--arg sha "$RUN_SHA" \
	--arg name "$RUN_NAME" \
	--argjson jobs "$JOBS" \
	--argjson errors "$ERRORS" \
	--argjson failed "$FAILED_COUNT" \
	'{run:($run|tonumber),status:$status,branch:$branch,sha:$sha,name:$name,
	  failed:$failed,jobs:$jobs,errors:$errors}')

# Cache and output
echo "$RESULT" | digest_cache_set "$CACHE_KEY"
echo "$RESULT"
