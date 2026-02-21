#!/bin/bash
# RED test: dashboard-delegation.sh must define render_delegation_stats, source delegation_log, be <250 lines, and be sourced in dashboard-mini.sh

set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

# 1. Syntax check
bash -n /Users/roberdan/.claude-convergio-orchestrator/scripts/lib/dashboard-delegation.sh || fail "dashboard-delegation.sh syntax error"

# 2. Must reference delegation_log
! grep -q 'delegation_log' /Users/roberdan/.claude-convergio-orchestrator/scripts/lib/dashboard-delegation.sh && fail "Missing delegation_log reference"

# 3. Must be sourced in dashboard-mini.sh
! grep -q 'dashboard-delegation' /Users/roberdan/.claude-convergio-orchestrator/scripts/dashboard-mini.sh && fail "Not sourced in dashboard-mini.sh"

# 4. Must be <250 lines
wc -l /Users/roberdan/.claude-convergio-orchestrator/scripts/lib/dashboard-delegation.sh | awk '{print $1}' | grep -E '^[0-9]{1,3}$' || fail "dashboard-delegation.sh exceeds 250 lines"

echo "RED: All checks failed as expected (file not implemented)"
