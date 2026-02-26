#!/bin/bash
# Test: ADR 0010 multi-provider orchestration compliance
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADR_FILE="$SCRIPT_DIR/../docs/adr/0010-multi-provider-orchestration.md"

if [[ ! -f "$ADR_FILE" ]]; then
	echo "SKIP: ADR 0010 file not found at $ADR_FILE"
	exit 0
fi

PASS=0
FAIL=0

check() {
	local desc="$1"
	local pattern="$2"
	if grep -q "$pattern" "$ADR_FILE"; then
		echo "PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "FAIL: $desc"
		FAIL=$((FAIL + 1))
	fi
}

check "Status Accepted" "Status.*Accepted"
check "delegate.sh mention" "delegate\.sh"

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
