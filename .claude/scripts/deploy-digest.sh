#!/usr/bin/env bash
# Deploy Digest - Compact Vercel deployment status as JSON
# Extracts status + errors only. No raw build logs.
# Usage: deploy-digest.sh [deployment-url] [--no-cache]
# Version: 1.2.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=45
NO_CACHE=0
COMPACT=0
digest_check_compact "$@"
DEPLOYMENT=""
for arg in "$@"; do
	[[ "$arg" == "--no-cache" ]] && {
		NO_CACHE=1
		continue
	}
	[[ "$arg" == "--compact" ]] && continue
	[[ -z "$DEPLOYMENT" ]] && DEPLOYMENT="$arg"
done

# Check vercel CLI
if ! command -v vercel &>/dev/null; then
	jq -n '{"status":"error","msg":"vercel CLI not installed"}'
	exit 1
fi

# Get latest deployment if not specified
if [[ -z "$DEPLOYMENT" ]]; then
	# Parse vercel ls output for latest deployment URL
	DEPLOYMENT=$(vercel ls --limit 1 2>/dev/null |
		grep -oE 'https://[^ ]+\.vercel\.app' | head -1 || echo "")
fi

if [[ -z "$DEPLOYMENT" ]]; then
	jq -n '{"status":"no_deployments","errors":[]}'
	exit 0
fi

# Normalize: extract just the URL/ID
DEPLOY_KEY=$(echo "$DEPLOYMENT" | sed 's|https://||' | sed 's|\.vercel\.app.*||' | tr '/' '-')
CACHE_KEY="deploy-${DEPLOY_KEY}"

if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# Fetch deployment info via vercel inspect
TMPINSPECT=$(mktemp)
trap "rm -f '$TMPINSPECT'" EXIT INT TERM
vercel inspect "$DEPLOYMENT" >"$TMPINSPECT" 2>&1 || true

# Parse inspect output (unstructured text, extract key fields)
DEPLOY_STATUS=$(grep -iE '^\s*(status|state)' "$TMPINSPECT" | head -1 |
	sed 's/.*:\s*//' | tr -d '[:space:]' || echo "unknown")
DEPLOY_URL=$(grep -iE '^\s*url' "$TMPINSPECT" | head -1 |
	sed 's/.*:\s*//' | tr -d '[:space:]' || echo "$DEPLOYMENT")
DEPLOY_CREATED=$(grep -iE '^\s*created' "$TMPINSPECT" | head -1 |
	sed 's/.*:\s*//' || echo "")

# Normalize status
case "$DEPLOY_STATUS" in
READY | ready) STATUS="ready" ;;
ERROR | error | FAILED | failed) STATUS="error" ;;
BUILDING | building) STATUS="building" ;;
QUEUED | queued) STATUS="queued" ;;
CANCELED | canceled | cancelled) STATUS="canceled" ;;
*) STATUS="$DEPLOY_STATUS" ;;
esac

# Extract errors: fetch logs only if deployment failed
ERRORS="[]"
WARNINGS="[]"
if [[ "$STATUS" == "error" ]]; then
	TMPLOG=$(mktemp)
	vercel logs "$DEPLOYMENT" --limit 100 >"$TMPLOG" 2>/dev/null || true

	if [[ -s "$TMPLOG" ]]; then
		ERRORS=$(cat "$TMPLOG" |
			grep -iE 'error|ERR!|FATAL|failed|Module not found|Cannot find' |
			grep -viE 'warning|warn|deprecat|experimental' |
			sed 's/^[[:space:]]*//' |
			sort -u |
			head -10 |
			jq -R -s 'split("\n") | map(select(length > 0)) | map({msg: .[0:200]})' 2>/dev/null) || ERRORS="[]"

		WARNINGS=$(cat "$TMPLOG" |
			grep -iE 'warning|warn' |
			grep -viE 'error|ERR!' |
			sed 's/^[[:space:]]*//' |
			sort -u |
			head -5 |
			jq -R -s 'split("\n") | map(select(length > 0)) | map({msg: .[0:150]})' 2>/dev/null) || WARNINGS="[]"
	fi
	rm -f "$TMPLOG"
fi

# Build final JSON
RESULT=$(jq -n \
	--arg url "$DEPLOY_URL" \
	--arg status "$STATUS" \
	--arg created "$DEPLOY_CREATED" \
	--argjson errors "$ERRORS" \
	--argjson warnings "$WARNINGS" \
	'{url:$url,status:$status,created:$created,
	  errors:$errors,warnings:$warnings}')

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
# --compact: only status + errors (skip url, created, warnings)
echo "$RESULT" | COMPACT=$COMPACT digest_compact_filter 'status, errors'
