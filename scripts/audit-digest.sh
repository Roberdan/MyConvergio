#!/usr/bin/env bash
set -euo pipefail
# Audit Digest - Compact npm audit output as JSON
# Returns only actionable items: critical, high, fixable.
# Usage: audit-digest.sh [--no-cache] [extra-args...]
# Version: 1.2.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=60
NO_CACHE=0
COMPACT=0
digest_check_compact "$@"
for arg in "$@"; do
	[[ "$arg" == "--no-cache" ]] && NO_CACHE=1
done
[[ "${1:-}" == "--no-cache" || "${1:-}" == "--compact" ]] && shift
[[ "${1:-}" == "--no-cache" || "${1:-}" == "--compact" ]] && shift

CACHE_KEY="audit-$(digest_hash "$(pwd)")"

if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

TMPLOG=$(mktemp)
trap "rm -f '$TMPLOG'" EXIT INT TERM

# Run audit with JSON output (machine-parseable)
npm audit --json "$@" >"$TMPLOG" 2>/dev/null || true

if [[ ! -s "$TMPLOG" ]]; then
	jq -n '{"status":"clean","total":0,"critical":0,"high":0,"moderate":0,"low":0,"fixable":0,"items":[]}'
	exit 0
fi

# Parse JSON audit output
RESULT=$(jq '
	{
		status: (if .metadata.vulnerabilities.critical > 0 then "critical"
			elif .metadata.vulnerabilities.high > 0 then "high"
			elif .metadata.vulnerabilities.moderate > 0 then "moderate"
			elif .metadata.vulnerabilities.total > 0 then "low"
			else "clean" end),
		total: (.metadata.vulnerabilities.total // 0),
		critical: (.metadata.vulnerabilities.critical // 0),
		high: (.metadata.vulnerabilities.high // 0),
		moderate: (.metadata.vulnerabilities.moderate // 0),
		low: (.metadata.vulnerabilities.low // 0),
		fixable: (
			[.vulnerabilities // {} | to_entries[] |
				select(.value.fixAvailable == true)] | length
		),
		items: [
			.vulnerabilities // {} | to_entries[] |
			select(.value.severity == "critical" or .value.severity == "high") |
			{
				package: .key,
				severity: .value.severity,
				title: (.value.via[0].title // .value.via[0] // "unknown"),
				fixable: .value.fixAvailable,
				range: .value.range
			}
		] | .[0:15]
	}
' "$TMPLOG" 2>/dev/null)

# Fallback if JSON parsing fails (old npm versions)
if [[ -z "$RESULT" || "$RESULT" == "null" ]]; then
	RESULT=$(jq -n '{"status":"parse_error","total":0,"items":[],
		"raw_summary":"check npm audit manually"}')
fi

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
# --compact: only actionable fields (skip low, moderate, total)
echo "$RESULT" | COMPACT=$COMPACT digest_compact_filter 'status, critical, high, fixable, items'
