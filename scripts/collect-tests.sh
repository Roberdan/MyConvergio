#!/bin/bash
set -euo pipefail
# Tests Collector - Parses Jest/Playwright/Vitest JSON output
# Usage: ./collect-tests.sh [project_path]
# Output: JSON to stdout

# Version: 1.1.0
set -euo pipefail

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Look for test result files
JEST_RESULT=""
PLAYWRIGHT_RESULT=""

# Common locations for test results (project-agnostic)
JEST_PATHS=(
	"coverage/jest-results.json"
	"test-results/jest.json"
)

PLAYWRIGHT_PATHS=(
	"playwright-report/results.json"
	"test-results/playwright.json"
)

# Find Jest results
for path in "${JEST_PATHS[@]}"; do
	if [[ -f "$path" ]]; then
		JEST_RESULT="$path"
		break
	fi
done

# Find Playwright results
for path in "${PLAYWRIGHT_PATHS[@]}"; do
	if [[ -f "$path" ]]; then
		PLAYWRIGHT_RESULT="$path"
		break
	fi
done

# Parse Jest results
JEST_DATA='null'
if [[ -n "$JEST_RESULT" ]] && [[ -f "$JEST_RESULT" ]]; then
	JEST_DATA=$(jq '{
        framework: "jest",
        file: input_filename,
        passed: .numPassedTests,
        failed: .numFailedTests,
        skipped: .numPendingTests,
        total: .numTotalTests,
        duration: (.testResults | map(.perfStats.runtime) | add // 0),
        suites: (.testResults | length),
        coverage: (if .coverageMap then (.coverageMap | to_entries | map(.value.s | to_entries | map(.value) | [., length] | .[0] | add / .[1] * 100) | add / length) else null end)
    }' "$JEST_RESULT" 2>/dev/null || echo 'null')
fi

# Parse Playwright results
PLAYWRIGHT_DATA='null'
if [[ -n "$PLAYWRIGHT_RESULT" ]] && [[ -f "$PLAYWRIGHT_RESULT" ]]; then
	PLAYWRIGHT_DATA=$(jq '{
        framework: "playwright",
        file: input_filename,
        passed: ([.suites[].specs[].tests[] | select(.status == "passed")] | length),
        failed: ([.suites[].specs[].tests[] | select(.status == "failed")] | length),
        skipped: ([.suites[].specs[].tests[] | select(.status == "skipped")] | length),
        total: ([.suites[].specs[].tests[]] | length),
        duration: .stats.duration,
        suites: (.suites | length)
    }' "$PLAYWRIGHT_RESULT" 2>/dev/null || echo 'null')
fi

# Check package.json for test scripts
TEST_SCRIPTS='[]'
if [[ -f "package.json" ]]; then
	TEST_SCRIPTS=$(jq '.scripts | to_entries | map(select(.key | test("test"))) | map({name: .key, command: .value})' package.json 2>/dev/null || echo '[]')
fi

# Aggregate results
TESTS_FOUND=false
FRAMEWORKS='[]'
if [[ "$JEST_DATA" != "null" ]]; then
	TESTS_FOUND=true
	FRAMEWORKS=$(echo "$FRAMEWORKS" | jq --argjson jest "$JEST_DATA" '. + [$jest]')
fi
if [[ "$PLAYWRIGHT_DATA" != "null" ]]; then
	TESTS_FOUND=true
	FRAMEWORKS=$(echo "$FRAMEWORKS" | jq --argjson pw "$PLAYWRIGHT_DATA" '. + [$pw]')
fi

# Calculate totals
if [[ "$TESTS_FOUND" == true ]]; then
	TOTALS=$(echo "$FRAMEWORKS" | jq '{
        passed: (map(.passed // 0) | add),
        failed: (map(.failed // 0) | add),
        skipped: (map(.skipped // 0) | add),
        total: (map(.total // 0) | add)
    }')
else
	TOTALS='{"passed":0,"failed":0,"skipped":0,"total":0}'
fi

# Build output
jq -n \
	--arg collector "tests" \
	--arg timestamp "$TIMESTAMP" \
	--argjson frameworks "$FRAMEWORKS" \
	--argjson totals "$TOTALS" \
	--argjson scripts "$TEST_SCRIPTS" \
	--argjson found "$TESTS_FOUND" \
	'{
        collector: $collector,
        timestamp: $timestamp,
        status: "success",
        data: {
            found: $found,
            frameworks: $frameworks,
            totals: $totals,
            testScripts: $scripts
        }
    }'
