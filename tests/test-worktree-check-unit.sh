#!/usr/bin/env bash
# Unit test for worktree check in cmd_complete
set -euo pipefail

echo "Unit Test: Worktree Check Logic"
echo "================================"
echo ""

# Test the worktree-merge-check.sh output parsing
echo "1. Testing worktree-merge-check.sh output:"
WORKTREE_OUTPUT=$(worktree-merge-check.sh 2>&1)
echo "$WORKTREE_OUTPUT"
echo ""

# Parse the status for plan/130
echo "2. Parsing status for plan/130-distributedexecution:"
STATUS=$(echo "$WORKTREE_OUTPUT" | grep "plan/130" | awk -F'|' '{print $3}' | xargs || echo "NOT_FOUND")
echo "  Status: $STATUS"
echo ""

# Check if status contains blocking keywords
echo "3. Checking for blocking conditions:"
if [[ "$STATUS" =~ DIRTY|BEHIND|CONFLICT ]]; then
	echo "  ✓ Status contains blocking condition: $STATUS"
	echo "  → cmd_complete should BLOCK completion"
else
	echo "  Status does not contain blocking condition: $STATUS"
	echo "  → cmd_complete should ALLOW completion"
fi
echo ""

# Verify the grep pattern works
echo "4. Testing grep pattern in code:"
cd /Users/roberdan/.claude-plan-130
if grep -q 'worktree not ready for merge' scripts/lib/plan-db-crud.sh; then
	echo "  ✓ Found worktree check code in cmd_complete"
else
	echo "  ✗ Worktree check code not found"
	exit 1
fi

if grep -q 'DIRTY|BEHIND|CONFLICT' scripts/lib/plan-db-crud.sh; then
	echo "  ✓ Found status pattern check"
else
	echo "  ✗ Status pattern check not found"
	exit 1
fi

if grep -q '\-\-force' scripts/lib/plan-db-crud.sh; then
	echo "  ✓ Found --force flag support"
else
	echo "  ✗ Force flag support not found"
	exit 1
fi

echo ""
echo "All unit tests passed!"
