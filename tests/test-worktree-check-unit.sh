#!/usr/bin/env bash
# Unit test for worktree check in cmd_complete
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Unit Test: Worktree Check Logic"
echo "================================"
echo ""

# Test the worktree-merge-check.sh output parsing
echo "1. Testing worktree-merge-check.sh output:"
WORKTREE_OUTPUT=$(worktree-merge-check.sh 2>&1)
echo "$WORKTREE_OUTPUT"
echo ""

# Verify the grep pattern works in plan-db-crud.sh
echo "2. Testing grep pattern in code:"
if grep -q 'worktree not ready for merge' "$SCRIPT_DIR/scripts/lib/plan-db-crud.sh"; then
	echo "  PASS: Found worktree check code in cmd_complete"
else
	echo "  FAIL: Worktree check code not found"
	exit 1
fi

if grep -q 'DIRTY|BEHIND|CONFLICT' "$SCRIPT_DIR/scripts/lib/plan-db-crud.sh"; then
	echo "  PASS: Found status pattern check"
else
	echo "  FAIL: Status pattern check not found"
	exit 1
fi

if grep -q '\-\-force' "$SCRIPT_DIR/scripts/lib/plan-db-crud.sh"; then
	echo "  PASS: Found --force flag support"
else
	echo "  FAIL: Force flag support not found"
	exit 1
fi

echo ""
echo "All unit tests passed!"
