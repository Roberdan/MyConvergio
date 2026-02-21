#!/usr/bin/env bash
# Test: orchestrator config and scripts existence
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

# Test 1: orchestrator.yaml exists
if [ -f "${SCRIPT_DIR}/config/orchestrator.yaml" ]; then
	echo "PASS: orchestrator.yaml exists"
else
	echo "FAIL: orchestrator.yaml not found"
	failures=$((failures + 1))
fi

# Test 2: delegate.sh exists and is executable
if [ -x "${SCRIPT_DIR}/scripts/delegate.sh" ]; then
	echo "PASS: delegate.sh exists and is executable"
else
	echo "FAIL: delegate.sh not found or not executable"
	failures=$((failures + 1))
fi

# Test 3: delegate.sh uses CLAUDE_HOME or HOME
if grep -q 'CLAUDE_HOME\|HOME' "${SCRIPT_DIR}/scripts/delegate.sh"; then
	echo "PASS: delegate.sh uses CLAUDE_HOME/HOME"
else
	echo "FAIL: delegate.sh missing CLAUDE_HOME/HOME"
	failures=$((failures + 1))
fi

# Test 4: All worker scripts exist
for worker in copilot-worker.sh opencode-worker.sh gemini-worker.sh; do
	if [ -f "${SCRIPT_DIR}/scripts/${worker}" ]; then
		echo "PASS: ${worker} exists"
	else
		echo "FAIL: ${worker} not found"
		failures=$((failures + 1))
	fi
done

exit $failures
