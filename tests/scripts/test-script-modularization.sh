#!/bin/bash
# Test script to verify modularization of oversized scripts
# This test verifies that all target scripts are ≤250 lines
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/../../scripts"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0

check_line_count() {
    local script="$1"
    local max_lines=250
    
    if [[ ! -f "$SCRIPTS_DIR/$script" ]]; then
        echo -e "${RED}FAIL${NC}: $script not found"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    local lines
    lines=$(wc -l < "$SCRIPTS_DIR/$script")
    
    if [[ $lines -gt $max_lines ]]; then
        echo -e "${RED}FAIL${NC}: $script has $lines lines (max: $max_lines)"
        FAILED=$((FAILED + 1))
        return 1
    else
        echo -e "${GREEN}PASS${NC}: $script has $lines lines (≤$max_lines)"
        return 0
    fi
}

echo "=== Script Modularization Tests ==="
echo ""

check_line_count "execute-plan.sh"
check_line_count "sync-dashboard-db.sh"
check_line_count "pr-ops.sh"
check_line_count "sync-to-myconvergio.sh"

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAILED test(s) failed${NC}"
    exit 1
fi
