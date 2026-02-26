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
grep -i 'delegation' "$AGENT_FILE" || {
	echo "FAIL: no 'delegation' found"
	FAIL=$((FAIL + 1))
}
grep -E 'KPI|model_effectiveness' "$AGENT_FILE" || {
	echo "FAIL: no KPI/model_effectiveness found"
	FAIL=$((FAIL + 1))
}

[ "$FAIL" -eq 0 ] && echo "PASS: diana delegation checks" || exit 1
