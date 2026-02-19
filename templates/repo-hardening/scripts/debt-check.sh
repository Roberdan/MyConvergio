#!/bin/bash
# debt-check.sh — Technical debt enforcement
# Checks TODO/FIXME, @ts-ignore, large files. Exits 1 if thresholds exceeded.
# ADAPT: Change SRC_DIR, EXTENSIONS, thresholds
set -euo pipefail

# ADAPT: Source directory and file patterns
SRC_DIR="src"
EXTENSIONS="ts,tsx,js,jsx"
# ADAPT: File extensions for grep
INCLUDE_FLAGS="--include=*.ts --include=*.tsx --include=*.js --include=*.jsx"

# ADAPT: Thresholds (adjust per project maturity)
MAX_TODO=15
MAX_IGNORE=5
MAX_LARGE_FILES=10
LARGE_FILE_LINES=400

FAILED=0
check() {
	local name="$1" count="$2" max="$3"
	if [ "$count" -gt "$max" ]; then
		echo "FAIL: $name: $count/$max"
		FAILED=1
	else
		echo "OK:   $name: $count/$max"
	fi
}

echo "=== Technical Debt Check ==="

# TODO/FIXME markers
# shellcheck disable=SC2086
TODO_COUNT=$({ grep -rn 'TODO\|FIXME' "$SRC_DIR" $INCLUDE_FLAGS 2>/dev/null || true; } | wc -l | tr -d ' ')
check "TODO/FIXME comments" "$TODO_COUNT" "$MAX_TODO"

# @ts-ignore / @ts-expect-error / type: ignore
# shellcheck disable=SC2086
IGNORE_COUNT=$({ grep -rn '@ts-ignore\|@ts-expect-error\|type: ignore' "$SRC_DIR" $INCLUDE_FLAGS 2>/dev/null || true; } | wc -l | tr -d ' ')
check "Type suppressions" "$IGNORE_COUNT" "$MAX_IGNORE"

# Large files (>LARGE_FILE_LINES lines)
LARGE_COUNT=0
while IFS= read -r file; do
	lines=$(wc -l <"$file" 2>/dev/null | tr -d ' ')
	[ "$lines" -gt "$LARGE_FILE_LINES" ] && LARGE_COUNT=$((LARGE_COUNT + 1))
done < <(find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) 2>/dev/null)
check "Files >${LARGE_FILE_LINES} lines" "$LARGE_COUNT" "$MAX_LARGE_FILES"

echo "==========================="
[ $FAILED -ne 0 ] && echo "Debt thresholds exceeded." && exit 1
echo "All debt checks passed."
