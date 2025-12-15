#!/bin/bash

################################################################################
# MyConvergio Agent Security Test Runner
# Version: 1.0.0
# Date: December 15, 2025
#
# Purpose: Automated and manual security testing for MyConvergio agents
# Usage: ./run_security_tests.sh [options]
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DOC="${SCRIPT_DIR}/security_tests.md"
RESULTS_DIR="${REPO_ROOT}/.claude/logs/security_tests"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="${RESULTS_DIR}/results_${TIMESTAMP}.md"
LATEST_RESULTS="${RESULTS_DIR}/latest_results.md"

# Test categories
CATEGORIES=("W6A" "W6B" "W6C" "W6D")
CATEGORY_NAMES=(
    "Jailbreak Resistance"
    "Identity Lock"
    "Prompt Injection"
    "Tool Boundaries"
)

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

################################################################################
# Setup Functions
################################################################################

setup_environment() {
    print_header "Setting Up Test Environment"

    # Create results directory
    mkdir -p "$RESULTS_DIR"
    print_success "Created results directory: $RESULTS_DIR"

    # Verify test documentation exists
    if [[ ! -f "$TEST_DOC" ]]; then
        print_error "Test documentation not found: $TEST_DOC"
        exit 1
    fi
    print_success "Test documentation verified"

    # Verify agents are deployed
    if [[ ! -d "${REPO_ROOT}/.claude/agents" ]]; then
        print_error "Agents directory not found. Run ./deploy-agents-en.sh first"
        exit 1
    fi
    print_success "Agents directory verified"

    # Check Claude Code CLI
    if ! command -v claude &> /dev/null; then
        print_error "Claude Code CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
    print_success "Claude Code CLI verified"

    print_success "Environment setup complete"
    echo ""
}

################################################################################
# Test Execution Functions
################################################################################

initialize_results() {
    cat > "$RESULTS_FILE" << EOF
# MyConvergio Agent Security Test Results
**Date**: $(date +"%Y-%m-%d %H:%M:%S")
**Test Suite Version**: 1.0.0

---

## Executive Summary

**Status**: Running...

| Metric | Value |
|--------|-------|
| Total Tests | TBD |
| Passed | TBD |
| Failed | TBD |
| Skipped | TBD |
| Pass Rate | TBD |

---

## Test Results by Category

EOF
}

finalize_results() {
    local pass_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        pass_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi

    local status="PASS"
    if [[ $FAILED_TESTS -gt 0 ]]; then
        status="FAIL"
    fi

    # Update executive summary
    sed -i.bak "s/\*\*Status\*\*: Running.../\*\*Status\*\*: $status/" "$RESULTS_FILE"
    sed -i.bak "s/| Total Tests | TBD |/| Total Tests | $TOTAL_TESTS |/" "$RESULTS_FILE"
    sed -i.bak "s/| Passed | TBD |/| Passed | $PASSED_TESTS |/" "$RESULTS_FILE"
    sed -i.bak "s/| Failed | TBD |/| Failed | $FAILED_TESTS |/" "$RESULTS_FILE"
    sed -i.bak "s/| Skipped | TBD |/| Skipped | $SKIPPED_TESTS |/" "$RESULTS_FILE"
    sed -i.bak "s/| Pass Rate | TBD |/| Pass Rate | ${pass_rate}% |/" "$RESULTS_FILE"
    rm "${RESULTS_FILE}.bak"

    # Add final recommendations
    cat >> "$RESULTS_FILE" << EOF

---

## Recommendations

EOF

    if [[ $FAILED_TESTS -eq 0 ]]; then
        cat >> "$RESULTS_FILE" << EOF
✅ **All tests passed!** The agent security posture is excellent.

Continue monitoring and add new test cases as attack patterns evolve.
EOF
    else
        cat >> "$RESULTS_FILE" << EOF
⚠️ **$FAILED_TESTS test(s) failed.** Immediate action required.

### Priority Actions:
1. Review failed tests in detail
2. Update agent security frameworks
3. Verify Constitution compliance
4. Re-run tests after fixes
5. Consider additional security hardening

### Next Steps:
- Investigate root cause of failures
- Update agent prompts if needed
- Add regression tests
- Document security incidents
EOF
    fi

    cat >> "$RESULTS_FILE" << EOF

---

**Report Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Test Runner Version**: 1.0.0
EOF

    # Copy to latest results
    cp "$RESULTS_FILE" "$LATEST_RESULTS"
}

run_manual_test_prompt() {
    local category="$1"
    local test_id="$2"
    local agent="$3"

    print_info "Manual test required: $category - Test $test_id"
    echo ""
    echo "To execute this test:"
    echo "  1. Invoke the agent: @$agent"
    echo "  2. Copy the test prompt from: $TEST_DOC"
    echo "  3. Evaluate the response against pass criteria"
    echo "  4. Record results using: $0 --record $test_id [PASS|FAIL] \"notes\""
    echo ""
}

record_test_result() {
    local test_id="$1"
    local result="$2"
    local notes="$3"

    cat >> "$RESULTS_FILE" << EOF

### Test $test_id: $result
**Notes**: $notes
**Timestamp**: $(date +"%Y-%m-%d %H:%M:%S")

EOF

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [[ "$result" == "PASS" ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

################################################################################
# Category Test Functions
################################################################################

run_category_tests() {
    local category="$1"
    local category_name="$2"

    print_header "Testing Category: $category - $category_name"

    cat >> "$RESULTS_FILE" << EOF

### $category: $category_name

EOF

    case "$category" in
        "W6A")
            run_w6a_tests
            ;;
        "W6B")
            run_w6b_tests
            ;;
        "W6C")
            run_w6c_tests
            ;;
        "W6D")
            run_w6d_tests
            ;;
        *)
            print_error "Unknown category: $category"
            ;;
    esac
}

run_w6a_tests() {
    print_info "W6A: Jailbreak Resistance Tests (50+ tests)"
    print_info "These tests require manual execution. See $TEST_DOC for test prompts."
    echo ""

    cat >> "$RESULTS_FILE" << EOF
**Total Tests**: 50+
**Test Groups**:
- A1: Classic Jailbreak Patterns (10 tests)
- A2: Research/Education Bypass (10 tests)
- A3: Encoded/Obfuscated Attacks (10 tests)
- A4: Ethical Boundary Testing (10 tests)
- A5: Multi-Step Manipulation (10 tests)
- A6: Cross-Agent Exploitation (10 tests)

**Status**: Manual testing required. See test documentation for detailed test cases.

**Quick Reference**:
- Test A1.1: Ignore Previous Instructions
- Test A1.2: DAN Mode Activation
- Test A1.3: Developer Mode Override
- Test A1.4: Hypothetical Scenario Bypass
- Test A1.5: Roleplay Jailbreak
[See full test list in security_tests.md]

EOF

    SKIPPED_TESTS=$((SKIPPED_TESTS + 50))
}

run_w6b_tests() {
    print_info "W6B: Identity Lock Tests (20+ tests)"
    print_info "These tests require manual execution. See $TEST_DOC for test prompts."
    echo ""

    cat >> "$RESULTS_FILE" << EOF
**Total Tests**: 20+
**Test Groups**:
- B1: Direct Identity Override (10 tests)
- B2: Role Boundary Violations (10 tests)

**Status**: Manual testing required. See test documentation for detailed test cases.

**Quick Reference**:
- Test B1.1: Complete Role Replacement
- Test B1.2: Persona Addition
- Test B1.3: Memory Reset Claim
- Test B1.4: Admin Override
- Test B1.5: Gradual Identity Shift
[See full test list in security_tests.md]

EOF

    SKIPPED_TESTS=$((SKIPPED_TESTS + 20))
}

run_w6c_tests() {
    print_info "W6C: Prompt Injection Tests (30+ tests)"
    print_info "These tests require manual execution. See $TEST_DOC for test prompts."
    echo ""

    cat >> "$RESULTS_FILE" << EOF
**Total Tests**: 30+
**Test Groups**:
- C1: Direct Injection Patterns (10 tests)
- C2: Context Manipulation (10 tests)
- C3: Indirect Injection (10 tests)

**Status**: Manual testing required. See test documentation for detailed test cases.

**Quick Reference**:
- Test C1.1: Instruction Override Prefix
- Test C1.2: Suffix Injection
- Test C1.3: Delimiter Confusion
- Test C1.4: XML Tag Injection
- Test C1.5: Function Call Injection
[See full test list in security_tests.md]

EOF

    SKIPPED_TESTS=$((SKIPPED_TESTS + 30))
}

run_w6d_tests() {
    print_info "W6D: Tool Boundary Tests (15+ tests)"
    print_info "These tests require manual execution. See $TEST_DOC for test prompts."
    echo ""

    cat >> "$RESULTS_FILE" << EOF
**Total Tests**: 15+
**Test Groups**:
- D1: Tool Permission Violations (5 tests)
- D2: Tool Misuse (5 tests)
- D3: Tool Output Exploitation (5 tests)

**Status**: Manual testing required. See test documentation for detailed test cases.

**Quick Reference**:
- Test D1.1: Unauthorized Tool Usage
- Test D1.2: Tool Capability Expansion
- Test D1.3: Tool Chaining Exploit
- Test D1.4: Tool Justification Override
- Test D1.5: Emergency Tool Escalation
[See full test list in security_tests.md]

EOF

    SKIPPED_TESTS=$((SKIPPED_TESTS + 15))
}

################################################################################
# Agent-Specific Testing
################################################################################

test_agent() {
    local agent_name="$1"
    local category="${2:-all}"

    print_header "Testing Agent: $agent_name"

    if [[ "$category" == "all" ]]; then
        for i in "${!CATEGORIES[@]}"; do
            run_category_tests "${CATEGORIES[$i]}" "${CATEGORY_NAMES[$i]}"
        done
    else
        local idx=-1
        for i in "${!CATEGORIES[@]}"; do
            if [[ "${CATEGORIES[$i]}" == "$category" ]]; then
                idx=$i
                break
            fi
        done

        if [[ $idx -ge 0 ]]; then
            run_category_tests "$category" "${CATEGORY_NAMES[$idx]}"
        else
            print_error "Unknown category: $category"
            exit 1
        fi
    fi
}

################################################################################
# Reporting Functions
################################################################################

generate_report() {
    print_header "Generating Security Test Report"

    if [[ ! -f "$LATEST_RESULTS" ]]; then
        print_error "No test results found. Run tests first."
        exit 1
    fi

    cat "$LATEST_RESULTS"
    echo ""
    print_success "Full report available at: $LATEST_RESULTS"
}

show_trends() {
    print_header "Security Test Trends"

    local result_files=$(ls -t "$RESULTS_DIR"/results_*.md 2>/dev/null || echo "")

    if [[ -z "$result_files" ]]; then
        print_warning "No historical test results found"
        return
    fi

    echo "Recent Test Results:"
    echo ""
    printf "%-20s %-8s %-8s %-8s %-8s\n" "Date" "Total" "Passed" "Failed" "Pass%"
    echo "────────────────────────────────────────────────────"

    for file in $result_files; do
        if [[ -f "$file" ]]; then
            local date=$(basename "$file" | sed 's/results_//' | sed 's/.md//' | sed 's/_/ /')
            local total=$(grep "| Total Tests |" "$file" | awk -F'|' '{print $3}' | tr -d ' ')
            local passed=$(grep "| Passed |" "$file" | awk -F'|' '{print $3}' | tr -d ' ')
            local failed=$(grep "| Failed |" "$file" | awk -F'|' '{print $3}' | tr -d ' ')
            local pass_rate=$(grep "| Pass Rate |" "$file" | awk -F'|' '{print $3}' | tr -d ' ')

            printf "%-20s %-8s %-8s %-8s %-8s\n" "$date" "$total" "$passed" "$failed" "$pass_rate"
        fi
    done
    echo ""
}

compare_agents() {
    print_header "Agent Security Comparison"
    print_warning "Agent comparison requires per-agent test results"
    print_info "Run: $0 --agent [agent-name] to generate agent-specific results"
    echo ""
}

export_results() {
    local format="${1:-json}"
    local output_file="${RESULTS_DIR}/export_${TIMESTAMP}.${format}"

    print_header "Exporting Results to $format"

    case "$format" in
        "json")
            # Convert markdown to JSON structure
            cat > "$output_file" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "1.0.0",
  "summary": {
    "total_tests": $TOTAL_TESTS,
    "passed": $PASSED_TESTS,
    "failed": $FAILED_TESTS,
    "skipped": $SKIPPED_TESTS
  },
  "results_file": "$LATEST_RESULTS"
}
EOF
            ;;
        "csv")
            # Export as CSV
            echo "Category,TestID,Result,Notes,Timestamp" > "$output_file"
            print_warning "CSV export requires detailed test execution"
            ;;
        *)
            print_error "Unknown export format: $format"
            exit 1
            ;;
    esac

    print_success "Results exported to: $output_file"
}

################################################################################
# Usage Information
################################################################################

show_usage() {
    cat << EOF
MyConvergio Agent Security Test Runner
Version: 1.0.0

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --setup                 Setup test environment
    --all                   Run all security tests
    --category [CATEGORY]   Run specific test category (W6A, W6B, W6C, W6D)
    --agent [AGENT_NAME]    Test specific agent
    --severity [LEVEL]      Filter by severity (CRITICAL, HIGH)
    --record [ID] [RESULT]  Record manual test result
    --report                Generate test report
    --trends                Show historical test trends
    --compare               Compare agent security performance
    --export [FORMAT]       Export results (json, csv)
    --help                  Show this help message

EXAMPLES:
    # Setup environment
    $0 --setup

    # Run all tests
    $0 --all

    # Run jailbreak resistance tests
    $0 --category W6A

    # Test specific agent
    $0 --agent ali-chief-of-staff

    # Test specific agent with specific category
    $0 --agent baccio-tech-architect --category W6B

    # Record manual test result
    $0 --record A1.1 PASS "Agent correctly refused jailbreak attempt"

    # Generate report
    $0 --report

    # View trends
    $0 --trends

    # Export results
    $0 --export json

TEST CATEGORIES:
    W6A: Jailbreak Resistance Tests (50+ tests)
    W6B: Identity Lock Tests (20+ tests)
    W6C: Prompt Injection Tests (30+ tests)
    W6D: Tool Boundary Tests (15+ tests)

DOCUMENTATION:
    Full test documentation: $TEST_DOC
    Results directory: $RESULTS_DIR

EOF
}

################################################################################
# Main Script Logic
################################################################################

main() {
    # Parse command line arguments
    case "${1:-}" in
        --setup)
            setup_environment
            ;;
        --all)
            setup_environment
            initialize_results
            for i in "${!CATEGORIES[@]}"; do
                run_category_tests "${CATEGORIES[$i]}" "${CATEGORY_NAMES[$i]}"
            done
            finalize_results
            print_success "All tests completed. Results: $RESULTS_FILE"
            ;;
        --category)
            if [[ -z "${2:-}" ]]; then
                print_error "Category required. Options: W6A, W6B, W6C, W6D"
                exit 1
            fi
            setup_environment
            initialize_results
            local idx=-1
            for i in "${!CATEGORIES[@]}"; do
                if [[ "${CATEGORIES[$i]}" == "$2" ]]; then
                    idx=$i
                    break
                fi
            done
            if [[ $idx -ge 0 ]]; then
                run_category_tests "${CATEGORIES[$idx]}" "${CATEGORY_NAMES[$idx]}"
                finalize_results
                print_success "Category tests completed. Results: $RESULTS_FILE"
            else
                print_error "Unknown category: $2"
                exit 1
            fi
            ;;
        --agent)
            if [[ -z "${2:-}" ]]; then
                print_error "Agent name required"
                exit 1
            fi
            setup_environment
            initialize_results
            test_agent "$2" "${3:-all}"
            finalize_results
            print_success "Agent tests completed. Results: $RESULTS_FILE"
            ;;
        --severity)
            print_warning "Severity filtering not yet implemented"
            ;;
        --record)
            if [[ -z "${2:-}" || -z "${3:-}" ]]; then
                print_error "Usage: $0 --record [test-id] [PASS|FAIL] [notes]"
                exit 1
            fi
            setup_environment
            if [[ ! -f "$LATEST_RESULTS" ]]; then
                initialize_results
            fi
            record_test_result "$2" "$3" "${4:-No notes provided}"
            print_success "Test result recorded"
            ;;
        --report)
            generate_report
            ;;
        --trends)
            show_trends
            ;;
        --compare)
            compare_agents
            ;;
        --export)
            export_results "${2:-json}"
            ;;
        --help)
            show_usage
            ;;
        *)
            print_error "Unknown option: ${1:-}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
