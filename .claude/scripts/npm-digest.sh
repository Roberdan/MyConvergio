#!/usr/bin/env bash
# NPM Digest - Compact npm install/ci output as JSON
# Captures install output server-side, returns only summary.
# Usage: npm-digest.sh [install|ci|audit] [--no-cache] [extra-args...]
# Version: 1.2.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=120
NO_CACHE=0
COMPACT=0
digest_check_compact "$@"
CMD=""
for arg in "$@"; do
	[[ "$arg" == "--no-cache" ]] && {
		NO_CACHE=1
		continue
	}
	[[ "$arg" == "--compact" ]] && continue
	[[ -z "$CMD" ]] && {
		CMD="$arg"
		continue
	}
done
CMD="${CMD:-install}"
shift 2>/dev/null || true
# Skip flags already parsed
while [[ "${1:-}" == "--no-cache" || "${1:-}" == "--compact" || "${1:-}" == "$CMD" ]]; do
	shift 2>/dev/null || break
done

# For audit, delegate to audit-digest.sh (pass remaining args, skip CMD)
if [[ "$CMD" == "audit" ]]; then
	[[ "$NO_CACHE" -eq 1 ]] && exec "$SCRIPT_DIR/audit-digest.sh" --no-cache "$@"
	exec "$SCRIPT_DIR/audit-digest.sh" "$@"
fi

CACHE_KEY="npm-${CMD}-$(digest_hash "$(pwd)")"

if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

TMPLOG=$(mktemp)
trap "rm -f '$TMPLOG'" EXIT INT TERM

# Run npm install/ci, capture ALL output to temp file
EXIT_CODE=0
npm "$CMD" "$@" >"$TMPLOG" 2>&1 || EXIT_CODE=$?

# Parse output
ADDED=$(grep -oE 'added [0-9]+' "$TMPLOG" | grep -oE '[0-9]+' | head -1 || echo "0")
REMOVED=$(grep -oE 'removed [0-9]+' "$TMPLOG" | grep -oE '[0-9]+' | head -1 || echo "0")
CHANGED=$(grep -oE 'changed [0-9]+' "$TMPLOG" | grep -oE '[0-9]+' | head -1 || echo "0")
PACKAGES=$(grep -oE '[0-9]+ packages' "$TMPLOG" | grep -oE '[0-9]+' | head -1 || echo "0")

# Extract vulnerabilities summary
VULN_LINE=$(grep -iE '[0-9]+ vulnerabilit' "$TMPLOG" | head -1 || echo "")
CRITICAL=$(echo "$VULN_LINE" | grep -oE '[0-9]+ critical' | grep -oE '[0-9]+' || echo "0")
HIGH=$(echo "$VULN_LINE" | grep -oE '[0-9]+ high' | grep -oE '[0-9]+' || echo "0")
MODERATE=$(echo "$VULN_LINE" | grep -oE '[0-9]+ moderate' | grep -oE '[0-9]+' || echo "0")

# Extract peer dependency warnings (compact)
PEER_WARNS=$(grep -iE 'peer dep|ERESOLVE|peer.*required' "$TMPLOG" |
	sed 's/^npm warn //' |
	head -5 |
	jq -R -s 'split("\n") | map(select(length > 0)) | map(.[0:150])' 2>/dev/null) || PEER_WARNS="[]"

# Extract errors if failed
ERRORS="[]"
if [[ "$EXIT_CODE" -ne 0 ]]; then
	ERRORS=$(grep -iE '^npm ERR!|error|ENOENT|EPERM|EACCES' "$TMPLOG" |
		grep -viE 'npm warn|peer' |
		head -5 |
		jq -R -s 'split("\n") | map(select(length > 0)) | map(.[0:200])' 2>/dev/null) || ERRORS="[]"
fi

STATUS="ok"
[[ "$EXIT_CODE" -ne 0 ]] && STATUS="error"
[[ "$CRITICAL" -gt 0 || "$HIGH" -gt 0 ]] && STATUS="vulnerable"

RESULT=$(jq -n \
	--arg cmd "$CMD" \
	--arg status "$STATUS" \
	--argjson exit_code "$EXIT_CODE" \
	--argjson added "${ADDED:-0}" \
	--argjson removed "${REMOVED:-0}" \
	--argjson changed "${CHANGED:-0}" \
	--argjson packages "${PACKAGES:-0}" \
	--argjson critical "${CRITICAL:-0}" \
	--argjson high "${HIGH:-0}" \
	--argjson moderate "${MODERATE:-0}" \
	--argjson peer_warnings "$PEER_WARNS" \
	--argjson errors "$ERRORS" \
	'{cmd:$cmd, status:$status, exit_code:$exit_code,
	  packages:$packages, added:$added, removed:$removed, changed:$changed,
	  audit:{critical:$critical, high:$high, moderate:$moderate},
	  peer_warnings:$peer_warnings, errors:$errors}')

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
# --compact: only status + errors (skip packages, added, removed, changed, peer_warnings)
echo "$RESULT" | COMPACT=$COMPACT digest_compact_filter 'status, exit_code, audit, errors'
