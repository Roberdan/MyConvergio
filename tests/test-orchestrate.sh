#!/bin/bash
# RED test for orchestrate.sh --use-delegate flag
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
	echo "FAIL: $1"
	exit 1
}

# Test: help text mentions --use-delegate and delegate.sh
if ! grep -q -- '--use-delegate' ./scripts/orchestrate.sh; then
	fail "--use-delegate flag missing in orchestrate.sh"
fi
if ! grep -q -- 'delegate.sh' ./scripts/orchestrate.sh; then
	fail "delegate.sh not mentioned in orchestrate.sh"
fi

# Test: bash syntax check
if ! bash -n ./scripts/orchestrate.sh; then
	fail "orchestrate.sh fails bash syntax check"
fi

echo "PASS: orchestrate.sh --use-delegate flag verified"
