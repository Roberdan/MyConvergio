#!/usr/bin/env bash
# Test Digest - Generic test runner with compact JSON output
# Auto-detects vitest/jest/playwright. Returns only failures.
# Usage: test-digest.sh [--suite unit|e2e|all] [--no-cache] [extra-args...]
# Version: 1.2.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=15
NO_CACHE=0
SUITE="all"

COMPACT=0
while [[ $# -gt 0 ]]; do
	case "$1" in
	--suite)
		SUITE="$2"
		shift 2
		;;
	--no-cache)
		NO_CACHE=1
		shift
		;;
	--compact)
		COMPACT=1
		shift
		;;
	*) break ;;
	esac
done

CACHE_KEY="test-${SUITE}-$(digest_hash "$(pwd)")"

if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

# Detect test framework
FRAMEWORK="unknown"
TEST_CMD=""
if [[ -f "package.json" ]]; then
	if grep -q '"vitest"' package.json 2>/dev/null; then
		FRAMEWORK="vitest"
		TEST_CMD="npx vitest run --reporter=json"
	elif grep -q '"jest"' package.json 2>/dev/null; then
		FRAMEWORK="jest"
		TEST_CMD="npx jest --json --silent"
	elif grep -q '"playwright"' package.json 2>/dev/null; then
		FRAMEWORK="playwright"
		TEST_CMD="npx playwright test --reporter=json"
	fi
fi

if [[ -z "$TEST_CMD" ]]; then
	# Fallback: try npm test with generic parsing
	FRAMEWORK="npm"
	TEST_CMD="npm test"
fi

TMPLOG=$(mktemp)
TMPJSON=$(mktemp)
TEST_PID=""
cleanup() {
	[[ -n "$TEST_PID" ]] && kill "$TEST_PID" 2>/dev/null && wait "$TEST_PID" 2>/dev/null || true
	rm -f "$TMPLOG" "$TMPJSON" "$PIDFILE"
}
trap cleanup EXIT INT TERM

# Kill stale test process from previous interrupted run (scoped to this project)
PIDFILE="${TMPDIR:-/tmp}/test-digest-$(digest_hash "$(pwd)").pid"
if [[ -f "$PIDFILE" ]]; then
	OLD_PID=$(cat "$PIDFILE")
	if kill -0 "$OLD_PID" 2>/dev/null; then
		kill "$OLD_PID" 2>/dev/null && wait "$OLD_PID" 2>/dev/null || true
	fi
	rm -f "$PIDFILE"
fi

# Run tests, capture output
EXIT_CODE=0
read -ra TEST_CMD_ARGS <<<"$TEST_CMD"
"${TEST_CMD_ARGS[@]}" "$@" >"$TMPLOG" 2>&1 &
echo "$!" >"$PIDFILE"
TEST_PID=$!
wait "$TEST_PID" || EXIT_CODE=$?
TEST_PID=""
rm -f "$PIDFILE"

STATUS="pass"
[[ "$EXIT_CODE" -ne 0 ]] && STATUS="fail"

# Framework-specific JSON parsing
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
FAILURES="[]"

if [[ "$FRAMEWORK" == "vitest" || "$FRAMEWORK" == "jest" ]]; then
	# Both use similar JSON reporter format
	# Extract JSON from output (may have non-JSON preamble)
	perl -ne 'print if /^\{.*testResults/..0' "$TMPLOG" >"$TMPJSON" 2>/dev/null || true

	if [[ -s "$TMPJSON" ]]; then
		TOTAL=$(jq '.numTotalTests // 0' "$TMPJSON" 2>/dev/null || echo 0)
		PASSED=$(jq '.numPassedTests // 0' "$TMPJSON" 2>/dev/null || echo 0)
		FAILED=$(jq '.numFailedTests // 0' "$TMPJSON" 2>/dev/null || echo 0)
		SKIPPED=$(jq '(.numPendingTests // 0) + (.numTodoTests // 0)' "$TMPJSON" 2>/dev/null || echo 0)

		# Extract failures: test name + error message
		FAILURES=$(jq '[.testResults[] |
			select(.status == "failed") |
			.assertionResults[] |
			select(.status == "failed") |
			{
				test: .fullName[0:100],
				file: (.ancestorTitles[0] // ""),
				msg: (.failureMessages[0] // "" | .[0:200])
			}
		] | .[0:10]' "$TMPJSON" 2>/dev/null || echo "[]")
	fi
elif [[ "$FRAMEWORK" == "playwright" ]]; then
	if [[ -s "$TMPLOG" ]]; then
		# Playwright JSON reporter
		TOTAL=$(jq '(.stats.expected // 0) + (.stats.unexpected // 0) + (.stats.skipped // 0)' "$TMPLOG" 2>/dev/null || echo 0)
		FAILED=$(jq '.stats.unexpected // 0' "$TMPLOG" 2>/dev/null || echo 0)
		SKIPPED=$(jq '.stats.skipped // 0' "$TMPLOG" 2>/dev/null || echo 0)
		PASSED=$((TOTAL - FAILED - SKIPPED))

		FAILURES=$(jq '[.suites[].specs[] |
			select(.ok == false) |
			{
				test: .title[0:100],
				file: .file,
				msg: (.tests[0].results[0].error.message // "" | .[0:200])
			}
		] | .[0:10]' "$TMPLOG" 2>/dev/null || echo "[]")
	fi
fi

# Fallback: parse from raw output if JSON parsing got nothing
if [[ "$TOTAL" -eq 0 && "$EXIT_CODE" -ne 0 ]]; then
	TOTAL=$(grep -coE '(PASS|FAIL|✓|✗|✘)' "$TMPLOG" 2>/dev/null) || TOTAL=0
	FAILED=$(grep -coE '(FAIL|✗|✘)' "$TMPLOG" 2>/dev/null) || FAILED=0
	PASSED=$((TOTAL - FAILED))

	FAILURES=$(grep -A2 -iE 'FAIL|✗|✘|Error:' "$TMPLOG" |
		grep -viE 'node_modules|Snapshot' |
		head -10 |
		jq -R -s 'split("\n") | map(select(length > 0)) | map({test:"",file:"",msg:.[0:200]})' 2>/dev/null) || FAILURES="[]"
fi

[[ -z "$FAILURES" ]] && FAILURES="[]"

DURATION=$(grep -oE '[0-9.]+\s*s(ec)?' "$TMPLOG" | tail -1 || echo "")

RESULT=$(jq -n \
	--arg framework "$FRAMEWORK" \
	--arg status "$STATUS" \
	--argjson exit_code "$EXIT_CODE" \
	--argjson total "$TOTAL" \
	--argjson passed "$PASSED" \
	--argjson failed "$FAILED" \
	--argjson skipped "$SKIPPED" \
	--arg duration "$DURATION" \
	--argjson failures "$FAILURES" \
	'{framework:$framework, status:$status, exit_code:$exit_code,
	  total:$total, passed:$passed, failed:$failed, skipped:$skipped,
	  duration:$duration, failures:$failures}')

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
# --compact: only status + failure details (skip framework, skipped, duration)
echo "$RESULT" | COMPACT=$COMPACT digest_compact_filter 'status, total, failed, failures'
