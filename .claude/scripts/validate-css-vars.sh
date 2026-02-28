#!/usr/bin/env bash
# validate-css-vars.sh — Cross-project CSS variable orphan detector
# Usage: validate-css-vars.sh [--root src/] [--styles src/styles/] [--json]
# Version: 1.0.0
set -euo pipefail

ROOT="src/"
STYLES="src/styles/"
JSON_OUTPUT=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--root) ROOT="$2"; shift 2 ;;
	--styles) STYLES="$2"; shift 2 ;;
	--json) JSON_OUTPUT=1; shift ;;
	--help|-h)
		echo "Usage: validate-css-vars.sh [--root src/] [--styles src/styles/] [--json]"
		echo "Detects CSS variable references (var(--name)) without matching definitions."
		exit 0 ;;
	*) shift ;;
	esac
done

if [[ ! -d "$ROOT" ]]; then
	echo "{\"error\":\"Root directory not found: $ROOT\",\"pass\":true,\"orphans\":[]}"
	exit 0
fi

# Find all var(--name) references in .tsx/.css/.scss files
REFERENCED=$(grep -roh 'var(--[a-zA-Z0-9_-]\+)' "$ROOT" --include='*.tsx' --include='*.css' --include='*.scss' 2>/dev/null \
	| grep -oE '\-\-[a-zA-Z0-9_-]+' | sort -u || true)

# Find all --name: definitions in CSS files
DEFINED=""
if [[ -d "$STYLES" ]]; then
	DEFINED=$(grep -roh '^\s*--[a-zA-Z0-9_-]\+\s*:' "$STYLES" --include='*.css' --include='*.scss' 2>/dev/null \
		| grep -oE '\-\-[a-zA-Z0-9_-]+' | sort -u || true)
fi
# Also check for definitions in all CSS files under root
DEFINED_ALL=$(grep -roh '^\s*--[a-zA-Z0-9_-]\+\s*:' "$ROOT" --include='*.css' --include='*.scss' 2>/dev/null \
	| grep -oE '\-\-[a-zA-Z0-9_-]+' | sort -u || true)
DEFINED=$(printf '%s\n%s' "$DEFINED" "$DEFINED_ALL" | sort -u)

# Find orphans (referenced but not defined)
ORPHANS=""
if [[ -n "$REFERENCED" ]]; then
	ORPHANS=$(comm -23 <(echo "$REFERENCED") <(echo "$DEFINED") 2>/dev/null || true)
fi

REF_COUNT=$(echo "$REFERENCED" | grep -c . 2>/dev/null || echo 0)
DEF_COUNT=$(echo "$DEFINED" | grep -c . 2>/dev/null || echo 0)
ORPHAN_COUNT=$(echo "$ORPHANS" | grep -c . 2>/dev/null || echo 0)
PASS="true"
[[ "$ORPHAN_COUNT" -gt 0 ]] && PASS="false"

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
	ORPHAN_JSON="[]"
	if [[ -n "$ORPHANS" ]] && [[ "$ORPHAN_COUNT" -gt 0 ]]; then
		ORPHAN_JSON=$(echo "$ORPHANS" | jq -R . | jq -s .)
	fi
	jq -n --argjson orphans "$ORPHAN_JSON" \
		--argjson ref "$REF_COUNT" --argjson def "$DEF_COUNT" \
		--argjson count "$ORPHAN_COUNT" --argjson pass "$PASS" \
		'{referenced_count: $ref, defined_count: $def, orphan_count: $count, pass: $pass, orphans: $orphans}'
else
	echo "=== CSS Variable Validation ==="
	echo "Referenced: $REF_COUNT | Defined: $DEF_COUNT | Orphans: $ORPHAN_COUNT"
	if [[ "$ORPHAN_COUNT" -gt 0 ]]; then
		echo ""
		echo "ORPHANED variables (referenced but never defined):"
		echo "$ORPHANS" | while read -r var; do
			echo "  - $var"
			grep -rn "var($var)" "$ROOT" --include='*.tsx' --include='*.css' 2>/dev/null | head -2 | sed 's/^/    /'
		done
		echo ""
		echo "RESULT: FAIL ($ORPHAN_COUNT orphans)"
		exit 1
	else
		echo "RESULT: PASS"
	fi
fi
