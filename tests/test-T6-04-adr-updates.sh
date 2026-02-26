#!/usr/bin/env bash
# Test T6-04: Verify ADR updates in docs/adr/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADR_DIR="$SCRIPT_DIR/../docs/adr"

if [[ ! -d "$ADR_DIR" ]]; then
	echo "SKIP: ADR directory not found at $ADR_DIR"
	exit 0
fi

ERRORS=0

check_content() {
	local file="$1" pattern="$2" desc="$3" flags="${4:-}"
	if grep -q $flags "$pattern" "$file" 2>/dev/null; then
		echo "PASS: $desc"
	else
		echo "FAIL: $desc"
		ERRORS=$((ERRORS + 1))
	fi
}

echo "Testing ADR 0003 updates..."
ADR3="$ADR_DIR/0003-opus46-configuration-upgrade.md"
check_content "$ADR3" "February 2026 Update" "ADR 0003 has February 2026 Update section"
check_content "$ADR3" "opus 4.6 validation" "ADR 0003 has Opus 4.6 validation" -i
check_content "$ADR3" "thinking token" "ADR 0003 has thinking token monitoring" -i
check_content "$ADR3" "18 models" "ADR 0003 has 18 models reference"
echo ""

echo "Testing ADR 0009 updates..."
ADR9="$ADR_DIR/0009-compact-markdown-format.md"
check_content "$ADR9" "@import Optimization" "ADR 0009 has @import Optimization section"
check_content "$ADR9" "T0-01" "ADR 0009 has T0-01 reference"
check_content "$ADR9" "NOT lazy" "ADR 0009 has lazy-load clarification" -i
check_content "$ADR9" "token cost" "ADR 0009 has token cost strategy" -i
check_content "$ADR9" "v2.0.0" "ADR 0009 has v2.0.0 format reference"
echo ""

echo "Testing ADR 0005 updates..."
ADR5="$ADR_DIR/0005-multi-agent-concurrency-control.md"
if ! (grep -q "ADR 0016" "$ADR5" 2>/dev/null || grep -q "ADR-0016" "$ADR5" 2>/dev/null); then
	echo "FAIL: ADR 0005 missing ADR 0016 reference"
	ERRORS=$((ERRORS + 1))
else
	echo "PASS: ADR 0005 has ADR 0016 reference"
fi
check_content "$ADR5" "Layer 5" "ADR 0005 has Layer 5 context"
echo ""

if [[ $ERRORS -eq 0 ]]; then
	echo "All ADR tests passed!"
	exit 0
else
	echo "$ERRORS test(s) FAILED"
	exit 1
fi
