#!/bin/bash
# Diana Performance Dashboard Delegation Intelligence Test
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_FILE="$SCRIPT_DIR/../agents/core_utility/diana-performance-dashboard.md"

if [[ ! -f "$AGENT_FILE" ]]; then
	echo "SKIP: diana-performance-dashboard.md not found at $AGENT_FILE"
	exit 0
fi

FAIL=0
grep -q '^name: diana-performance-dashboard' "$AGENT_FILE" || {
	echo "FAIL: missing agent name frontmatter"
	FAIL=$((FAIL + 1))
}
grep -q '^## Rules' "$AGENT_FILE" || {
	echo "FAIL: missing compact Rules section"
	FAIL=$((FAIL + 1))
}
grep -q '^## Commands' "$AGENT_FILE" || {
	echo "FAIL: missing compact Commands section"
	FAIL=$((FAIL + 1))
}

[ "$FAIL" -eq 0 ] && echo "PASS: diana compact agent checks" || exit 1
