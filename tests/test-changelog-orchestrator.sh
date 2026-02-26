#!/bin/bash
# RED test: CHANGELOG.md must mention Convergio Orchestrator and ADR-0010
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANGELOG="$SCRIPT_DIR/../CHANGELOG.md"

if [[ ! -f "$CHANGELOG" ]]; then
	echo "SKIP: CHANGELOG.md not found at $CHANGELOG"
	exit 0
fi

FAIL=0
if ! grep -q 'Convergio Orchestrator' "$CHANGELOG"; then
	echo 'FAIL: Missing Convergio Orchestrator in CHANGELOG.md'
	FAIL=$((FAIL + 1))
fi
if ! grep -q 'ADR-0010' "$CHANGELOG"; then
	echo 'FAIL: Missing ADR-0010 in CHANGELOG.md'
	FAIL=$((FAIL + 1))
fi

if [[ "$FAIL" -eq 0 ]]; then
	echo 'PASS: CHANGELOG.md contains expected entries'
fi
exit "$FAIL"
