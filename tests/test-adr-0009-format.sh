#!/bin/bash
# Test: ADR 0009 exists and meets format requirements
set -euo pipefail

ADR_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs/adr/0009-compact-markdown-format.md"
PASS=0
FAIL=0

assert() {
	local desc="$1" result="$2"
	if [[ "$result" == "true" ]]; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		FAIL=$((FAIL + 1))
	fi
}

echo "=== ADR 0009 Format Validation ==="

# F-01: File exists
assert "ADR file exists" "$([[ -f "$ADR_FILE" ]] && echo true || echo false)"

if [[ ! -f "$ADR_FILE" ]]; then
	echo "RESULT: $PASS passed, $((FAIL)) failed (file missing, skipping content checks)"
	exit 1
fi

CONTENT="$(cat "$ADR_FILE")"
LINE_COUNT="$(wc -l <"$ADR_FILE" | tr -d ' ')"

# F-02: Has standard ADR sections
assert "Has Context section" "$(grep -q '## Context' "$ADR_FILE" && echo true || echo false)"
assert "Has Decision section" "$(grep -q '## Decision' "$ADR_FILE" && echo true || echo false)"
assert "Has Consequences section" "$(grep -q '## Consequences' "$ADR_FILE" && echo true || echo false)"

# F-03: Has Status and Date
assert "Has Status field" "$(grep -q 'Status.*:' "$ADR_FILE" && echo true || echo false)"
assert "Has Date field" "$(grep -q 'Date.*:' "$ADR_FILE" && echo true || echo false)"

# F-04: Max 250 lines
assert "Under 250 lines (got $LINE_COUNT)" "$([[ $LINE_COUNT -le 250 ]] && echo true || echo false)"

# F-05: Documents key rules
assert "Documents no-prose rule" "$(grep -qi 'keyword.*bullet\|bullet.*keyword\|no prose' "$ADR_FILE" && echo true || echo false)"
assert "Documents tables for mappings" "$(grep -q 'table' "$ADR_FILE" && echo true || echo false)"
assert "Documents max 250 lines" "$(grep -q '250' "$ADR_FILE" && echo true || echo false)"
assert "Documents max 150 instructions" "$(grep -q '150' "$ADR_FILE" && echo true || echo false)"
assert "Documents progressive disclosure" "$(grep -qi 'progressive' "$ADR_FILE" && echo true || echo false)"
assert "Documents @imports" "$(grep -q '@import' "$ADR_FILE" && echo true || echo false)"

# F-06: Has before/after example
assert "Has before/after example" "$(grep -qi 'before\|after\|verbose\|compact' "$ADR_FILE" && echo true || echo false)"

# F-07: Has cross-tool compatibility matrix
assert "Has compatibility matrix" "$(grep -q 'Claude Code' "$ADR_FILE" && grep -q 'Copilot' "$ADR_FILE" && echo true || echo false)"

# F-08: Model-agnostic documented
assert "Documents model-agnostic rule" "$(grep -qi 'model.agnostic\|model agnostic' "$ADR_FILE" && echo true || echo false)"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
