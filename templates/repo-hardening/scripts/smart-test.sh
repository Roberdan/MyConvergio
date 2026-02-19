#!/bin/bash
# smart-test.sh — Run tests only for staged files (fast feedback)
# ADAPT: Change SRC_DIR, file extensions, test runner command
set -euo pipefail

# ADAPT: Source directory and extensions
SRC_DIR="src"
EXTENSIONS='\.tsx?$'
# ADAPT: Test runner (vitest related, jest --findRelatedTests, pytest)
TEST_CMD="npx vitest related"
TEST_FLAGS="--run --reporter=dot"

STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E "^${SRC_DIR}/.*${EXTENSIONS}" || true)

if [ -z "$STAGED" ]; then
	echo "[smart-test] No staged source files — skipping"
	exit 0
fi

COUNT=$(echo "$STAGED" | wc -l | tr -d ' ')
echo "[smart-test] $COUNT file(s) staged, running related tests..."
echo "$STAGED" | head -3
[ "$COUNT" -gt 3 ] && echo "  ... and $((COUNT - 3)) more"

# shellcheck disable=SC2086
$TEST_CMD $STAGED $TEST_FLAGS
