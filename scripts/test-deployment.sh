#!/bin/bash

# =============================================================================
# MYCONVERGIO DEPLOYMENT TEST SCRIPT
# =============================================================================
# This script tests various deployment scenarios for the MyConvergio agents
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DEPLOY_SCRIPT="$ROOT_DIR/deploy-agents.sh"
TEST_DIR="$ROOT_DIR/test-deployment"

# Create test directory
mkdir -p "$TEST_DIR"

# Function to run a test case
run_test() {
    local test_name="$1"
    local cmd="$2"
    local expected_result="${3:-success}"
    
    echo -e "\n${BLUE}TEST: $test_name${NC}"
    echo "Command: $cmd"
    
    set +e
    eval "$cmd"
    local result=$?
    set -e
    
    if [ "$expected_result" = "success" ] && [ $result -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        return 0
    elif [ "$expected_result" != "success" ] && [ $result -ne 0 ]; then
        echo -e "${GREEN}✓ PASSED (expected failure)${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

# Test cases
test_cases=(
    # Test 1: Default deployment (English)
    "Default deployment (EN)" 
    "cd $ROOT_DIR && ./deploy-agents.sh --dry-run"
    
    # Test 2: Italian deployment
    "Italian deployment (IT)"
    "cd $ROOT_DIR && ./deploy-agents.sh --lang it --dry-run"
    
    # Test 3: Custom directory
    "Custom directory"
    "cd $ROOT_DIR && ./deploy-agents.sh --dir $TEST_DIR/custom-dir --dry-run"
    
    # Test 4: Invalid language (should fail)
    "Invalid language (should fail)"
    "cd $ROOT_DIR && ./deploy-agents.sh --lang es --dry-run"
    "failure"
    
    # Test 5: Missing directory (should fail)
    "Missing directory (should fail)"
    "cd $ROOT_DIR && ./deploy-agents.sh --dir /nonexistent/dir --dry-run"
    "failure"
)

# Run all test cases
for ((i=0; i<${#test_cases[@]}; i+=3)); do
    test_name="${test_cases[i]}"
    test_cmd="${test_cases[i+1]}"
    expected_result="${test_cases[i+2]:-success}"
    
    if ! run_test "$test_name" "$test_cmd" "$expected_result"; then
        echo -e "${RED}TEST FAILED: $test_name${NC}"
        exit 1
    fi
done

echo -e "\n${GREEN}All tests completed successfully!${NC}"

# Cleanup
rm -rf "$TEST_DIR"

exit 0
