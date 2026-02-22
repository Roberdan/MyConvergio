#!/usr/bin/env bash
# Usage: project-audit.sh [--project-root <path>] [--json] [--no-cache]
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_LIB="$SCRIPT_DIR/lib/project-audit-checks.sh"

PROJECT_ROOT="."
JSON_OUTPUT=0
NO_CACHE=0

usage() {
	cat <<'EOF'
project-audit - Project hardening and quality audit orchestrator

Usage:
  project-audit.sh [--project-root <path>] [--json] [--no-cache] [--help]

Options:
  --project-root <path>  Project root to audit (default: current directory)
  --json                 Print JSON output only
  --no-cache             Disable cache for library checks
  --help                 Show this help
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--project-root)
		PROJECT_ROOT="${2:-}"
		if [[ -z "$PROJECT_ROOT" ]]; then
			echo "--project-root requires a value" >&2
			exit 1
		fi
		shift 2
		;;
	--json)
		JSON_OUTPUT=1
		shift
		;;
	--no-cache)
		NO_CACHE=1
		shift
		;;
	--help|-h)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 1
		;;
	esac
done

HARDENING_JSON="$("$SCRIPT_DIR/hardening-check.sh" --project-root "$PROJECT_ROOT")"
if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$HARDENING_JSON"; then
	echo "hardening-check.sh returned invalid JSON" >&2
	exit 1
fi

EXTRA_CHECKS_JSON='[]'
if [[ -f "$CHECKS_LIB" ]]; then
	# shellcheck source=/dev/null
	source "$CHECKS_LIB"
	if declare -F run_project_audit_checks >/dev/null 2>&1; then
		EXTRA_CHECKS_JSON="$(run_project_audit_checks "$PROJECT_ROOT" "$NO_CACHE")"
	elif declare -F project_audit_checks_json >/dev/null 2>&1; then
		EXTRA_CHECKS_JSON="$(project_audit_checks_json "$PROJECT_ROOT" "$NO_CACHE")"
	fi
fi
if ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$EXTRA_CHECKS_JSON"; then
	echo "project-audit-checks returned invalid JSON array" >&2
	exit 1
fi

REPORT_JSON="$(jq -n \
	--arg project_root "$PROJECT_ROOT" \
	--argjson json "$JSON_OUTPUT" \
	--argjson no_cache "$NO_CACHE" \
	--argjson hardening "$HARDENING_JSON" \
	--argjson extra "$EXTRA_CHECKS_JSON" '
	def check_pass:
		if has("pass") then .pass
		elif has("status") then (.status == "pass")
		else true end;
	($hardening.status == "pass" and (($hardening.failed // 0) == 0)) as $hardening_pass |
	([ $extra[] | select((check_pass | not)) ] | length) as $extra_failed |
	(1 + ($extra | length)) as $total_checks |
	((if $hardening_pass then 0 else 1 end) + $extra_failed) as $failed_checks |
	{
		tool: "project-audit",
		project_root: $project_root,
		no_cache: $no_cache,
		status: (if $failed_checks == 0 then "pass" else "gaps_found" end),
		summary: {
			total_checks: $total_checks,
			passed_checks: ($total_checks - $failed_checks),
			failed_checks: $failed_checks
		},
		checks: {
			hardening: $hardening,
			additional: $extra
		}
	}')"

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
	echo "$REPORT_JSON"
	exit 0
fi

echo "=== project-audit ==="
echo "Project root: $PROJECT_ROOT"
echo "Total checks: $(jq -r '.summary.total_checks' <<<"$REPORT_JSON")"
echo "Passed: $(jq -r '.summary.passed_checks' <<<"$REPORT_JSON")"
echo "Failed: $(jq -r '.summary.failed_checks' <<<"$REPORT_JSON")"
echo "Status: $(jq -r '.status' <<<"$REPORT_JSON")"

if [[ "$(jq -r '.checks.hardening.status' <<<"$REPORT_JSON")" != "pass" ]]; then
	echo ""
	echo "Hardening gaps:"
	jq -r '.checks.hardening.gaps[]? | "  - \(.name) [\(.severity)]"' <<<"$REPORT_JSON"
fi

if [[ "$(jq -r '.checks.additional | length' <<<"$REPORT_JSON")" -gt 0 ]]; then
	echo ""
	echo "Additional checks:"
	jq -r '.checks.additional[] | "  - \(.check // .name // "unnamed"): \(.pass // (.status == "pass"))"' <<<"$REPORT_JSON"
fi
