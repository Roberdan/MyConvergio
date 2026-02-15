#!/bin/bash
# Technical Debt Collector - Finds TODO, FIXME, HACK, DEFERRED, SKIPPED
# Usage: ./collect-debt.sh [project_path]
# Output: JSON to stdout

# Version: 1.1.0
set -euo pipefail

PROJECT_PATH="${1:-.}"
LIMIT="${2:-150}"
cd "$PROJECT_PATH"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Search for debt items using jq for safe JSON encoding
DEBT_ITEMS='[]'
if command -v rg &>/dev/null; then
	# Use ripgrep if available (faster)
	DEBT_ITEMS=$(rg -n --no-heading --color=never \
		-e "TODO" -e "FIXME" -e "HACK" -e "DEFERRED" -e "SKIPPED" -e "XXX" -e "BUG" -e "OPTIMIZE" \
		--type-add 'code:*.{ts,tsx,js,jsx,py,sh}' --type code \
		--glob '!node_modules' --glob '!.git' --glob '!dist' --glob '!build' --glob '!coverage' --glob '!.next' \
		-m 200 . 2>/dev/null | head -"$LIMIT" |
		jq -R -s 'split("\n") | map(select(length > 0)) | map(
			capture("^(?<file>[^:]+):(?<line>[0-9]+):(?<text>.+)$") // null
		) | map(select(. != null)) | map(.line |= tonumber | .type = (
			if (.text | test("FIXME|BUG")) then "fixme"
			elif (.text | test("HACK")) then "hack"
			elif (.text | test("DEFERRED")) then "deferred"
			elif (.text | test("SKIPPED")) then "skipped"
			else "todo" end
		))' || echo '[]')
else
	# Fallback to grep
	DEBT_ITEMS=$(grep -rn --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
		--include="*.py" --include="*.sh" \
		-E "(TODO|FIXME|HACK|DEFERRED|SKIPPED|XXX|BUG|OPTIMIZE)" \
		--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build --exclude-dir=.next \
		. 2>/dev/null | head -"$LIMIT" |
		jq -R -s 'split("\n") | map(select(length > 0)) | map(
			capture("^(?<file>[^:]+):(?<line>[0-9]+):(?<text>.+)$") // null
		) | map(select(. != null)) | map(.line |= tonumber | .type = (
			if (.text | test("FIXME|BUG")) then "fixme"
			elif (.text | test("HACK")) then "hack"
			elif (.text | test("DEFERRED")) then "deferred"
			elif (.text | test("SKIPPED")) then "skipped"
			else "todo" end
		))' || echo '[]')
fi

# Group by type
BY_TYPE=$(echo "$DEBT_ITEMS" | jq '{
    todo: [.[] | select(.type == "todo")],
    fixme: [.[] | select(.type == "fixme")],
    hack: [.[] | select(.type == "hack")],
    deferred: [.[] | select(.type == "deferred")],
    skipped: [.[] | select(.type == "skipped")]
}')

# Count total
TOTAL=$(echo "$DEBT_ITEMS" | jq 'length')

# Build output
jq -n \
	--arg collector "debt" \
	--arg timestamp "$TIMESTAMP" \
	--argjson total "$TOTAL" \
	--argjson byType "$BY_TYPE" \
	--argjson items "$DEBT_ITEMS" \
	'{
        collector: $collector,
        timestamp: $timestamp,
        status: "success",
        data: {
            total: $total,
            byType: $byType,
            lastScan: $timestamp
        }
    }'
