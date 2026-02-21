#!/bin/bash
# Test script for dashboard-mini.sh split
# Removed pipefail/errexit so all tests run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

# Test 1: Check dashboard-mini.sh line count
test_dashboard_mini_lines() {
    local line_count=$(wc -l < "$PROJECT_ROOT/scripts/dashboard-mini.sh" | tr -d ' ')
    if [ "$line_count" -le 250 ]; then
        pass "dashboard-mini.sh is $line_count lines (≤250)"
    else
        fail "dashboard-mini.sh is $line_count lines (>250)"
    fi
}

# Test 2: Check module files exist
test_modules_exist() {
    local modules=("dashboard-config.sh" "dashboard-db.sh" "dashboard-render.sh" "dashboard-sync.sh")
    for mod in "${modules[@]}"; do
        if [ -f "$PROJECT_ROOT/scripts/lib/dashboard/$mod" ]; then
            pass "Module $mod exists"
        else
            fail "Module $mod missing"
        fi
    done
}

# Test 3: Check each module is ≤250 lines
test_module_lines() {
    local modules=("dashboard-config.sh" "dashboard-db.sh" "dashboard-render.sh" "dashboard-sync.sh")
    for mod in "${modules[@]}"; do
        if [ -f "$PROJECT_ROOT/scripts/lib/dashboard/$mod" ]; then
            local line_count=$(wc -l < "$PROJECT_ROOT/scripts/lib/dashboard/$mod" | tr -d ' ')
            if [ "$line_count" -le 250 ]; then
                pass "Module $mod is $line_count lines (≤250)"
            else
                fail "Module $mod is $line_count lines (>250)"
            fi
        fi
    done
}

# Test 4: Check dashboard-mini.sh sources all modules
test_sources_modules() {
    local modules=("dashboard-config.sh" "dashboard-db.sh" "dashboard-render.sh" "dashboard-sync.sh")
    for mod in "${modules[@]}"; do
        if grep -q "/$mod" "$PROJECT_ROOT/scripts/dashboard-mini.sh"; then
            pass "dashboard-mini.sh sources $mod"
        else
            fail "dashboard-mini.sh does not source $mod"
        fi
    done
}

# Test 5: Check bash syntax
test_syntax() {
    local files=(
        "$PROJECT_ROOT/scripts/dashboard-mini.sh"
        "$PROJECT_ROOT/scripts/lib/dashboard/dashboard-config.sh"
        "$PROJECT_ROOT/scripts/lib/dashboard/dashboard-db.sh"
        "$PROJECT_ROOT/scripts/lib/dashboard/dashboard-render.sh"
        "$PROJECT_ROOT/scripts/lib/dashboard/dashboard-sync.sh"
    )
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            if bash -n "$file" 2>/dev/null; then
                pass "Syntax check: $(basename $file)"
            else
                fail "Syntax check: $(basename $file)"
            fi
        fi
    done
}

# Test 6: Check dashboard-mini.sh is executable
test_executable() {
    if [ -x "$PROJECT_ROOT/scripts/dashboard-mini.sh" ]; then
        pass "dashboard-mini.sh is executable"
    else
        fail "dashboard-mini.sh is not executable"
    fi
}

# Run all tests
echo -e "${YELLOW}Running dashboard-mini.sh split tests...${NC}"
echo ""

test_dashboard_mini_lines
test_modules_exist
test_module_lines
test_sources_modules
test_syntax
test_executable

echo ""
echo -e "${YELLOW}========================${NC}"
echo -e "${GREEN}PASSED: $PASSED${NC}"
echo -e "${RED}FAILED: $FAILED${NC}"
echo -e "${YELLOW}========================${NC}"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
