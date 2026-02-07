#!/usr/bin/env bash
# Build Digest - Compact build output as JSON
# Auto-detects Next.js/Vite/generic. Captures build output server-side.
# Usage: build-digest.sh [--no-cache] [extra-args...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=30
NO_CACHE=0
[[ "${1:-}" == "--no-cache" ]] && {
	NO_CACHE=1
	shift
}

CACHE_KEY="build-$(pwd | md5sum 2>/dev/null | cut -c1-8 || echo 'x')"

if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# Detect framework
FRAMEWORK="generic"
if [[ -f "next.config.js" || -f "next.config.mjs" || -f "next.config.ts" ]]; then
	FRAMEWORK="nextjs"
elif [[ -f "vite.config.ts" || -f "vite.config.js" ]]; then
	FRAMEWORK="vite"
fi

TMPLOG=$(mktemp)
trap "rm -f '$TMPLOG'" EXIT

# Run build, capture to temp file
EXIT_CODE=0
npm run build "$@" >"$TMPLOG" 2>&1 || EXIT_CODE=$?

STATUS="ok"
[[ "$EXIT_CODE" -ne 0 ]] && STATUS="error"

# Extract errors
ERRORS=$(grep -iE 'error[:\s]|Error:|FAIL|Module not found|Cannot find|SyntaxError|TypeError' "$TMPLOG" |
	grep -viE 'warning|warn|deprecat|experimental|Linting' |
	sed 's/^[[:space:]]*//' |
	sort -u | head -10 |
	jq -R -s 'split("\n") | map(select(length > 0)) | map(.[0:200])' 2>/dev/null || echo "[]")

# Extract warnings
WARNINGS=$(grep -iE 'warning|warn' "$TMPLOG" |
	grep -viE 'error|ERR!|node_modules' |
	sed 's/^[[:space:]]*//' |
	sort -u | head -5 |
	jq -R -s 'split("\n") | map(select(length > 0)) | map(.[0:150])' 2>/dev/null || echo "[]")

# Framework-specific parsing
ROUTES=0
BUNDLE_SIZE=""
BUILD_TIME=""

if [[ "$FRAMEWORK" == "nextjs" ]]; then
	# Count routes from Next.js output
	ROUTES=$(grep -cE '^\s*(├|└|\/)\s' "$TMPLOG" 2>/dev/null) || ROUTES=0
	# Extract bundle size
	BUNDLE_SIZE=$(grep -oE 'First Load JS.*' "$TMPLOG" | tail -1 |
		sed 's/First Load JS shared by all//' | tr -d '[:space:]' || echo "")
	# Build time
	BUILD_TIME=$(grep -oE 'Compiled.*in [0-9.]+[ms]' "$TMPLOG" | tail -1 || echo "")
	[[ -z "$BUILD_TIME" ]] && BUILD_TIME=$(grep -oE 'Ready in [0-9.]+[ms]' "$TMPLOG" | tail -1 || echo "")
elif [[ "$FRAMEWORK" == "vite" ]]; then
	BUNDLE_SIZE=$(grep -oE 'built in [0-9.]+[ms]' "$TMPLOG" | tail -1 || echo "")
	BUILD_TIME="$BUNDLE_SIZE"
fi

# TypeScript errors count
TS_ERRORS=$(grep -cE 'TS[0-9]+:' "$TMPLOG" 2>/dev/null) || TS_ERRORS=0

RESULT=$(jq -n \
	--arg framework "$FRAMEWORK" \
	--arg status "$STATUS" \
	--argjson exit_code "$EXIT_CODE" \
	--argjson routes "$ROUTES" \
	--arg bundle_size "$BUNDLE_SIZE" \
	--arg build_time "$BUILD_TIME" \
	--argjson ts_errors "$TS_ERRORS" \
	--argjson errors "$ERRORS" \
	--argjson warnings "$WARNINGS" \
	'{framework:$framework, status:$status, exit_code:$exit_code,
	  routes:$routes, bundle_size:$bundle_size, build_time:$build_time,
	  ts_errors:$ts_errors, errors:$errors, warnings:$warnings}')

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
echo "$RESULT"
