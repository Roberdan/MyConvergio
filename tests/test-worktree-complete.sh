#!/usr/bin/env bash
# Test: worktree merge check blocks plan completion
# Manual test - verifies cmd_complete checks worktree state
set -euo pipefail

echo "Manual Test: Worktree Merge Check in cmd_complete"
echo "=================================================="
echo ""

# Check current worktree status
echo "1. Current worktree status:"
worktree-merge-check.sh 2>&1 | grep -E "(plan/130|READY|DIRTY|BEHIND|CONFLICT|ALREADY_MERGED)" || echo "  No active worktrees found"
echo ""

# Test with actual plan 130 (this plan)
echo "2. Checking plan 130 worktree_path:"
WORKTREE_PATH=$(plan-db.sh get-worktree 130 2>&1 || echo "NULL")
echo "  worktree_path: $WORKTREE_PATH"
echo ""

# Attempt to complete plan 130 (should fail - we're still working on it)
echo "3. Attempting to complete plan 130 (should block - worktree not merged):"
if plan-db.sh complete 130 2>&1; then
	echo "  ✗ UNEXPECTED: Plan completed without worktree check"
	exit 1
else
	echo "  ✓ EXPECTED: Plan completion blocked (either validation missing or worktree check)"
fi
echo ""

echo "Test verification:"
echo "- Once implementation is added, cmd_complete should check worktree state"
echo "- Expected behavior: block if worktree is DIRTY, BEHIND, or has CONFLICT"
echo "- Expected behavior: allow if worktree is READY or ALREADY_MERGED"
echo "- Expected behavior: bypass check with --force flag"
