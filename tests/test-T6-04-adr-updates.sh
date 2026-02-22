#!/usr/bin/env bash
# Test T6-04: Verify ADR updates

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORKTREE="/Users/roberdan/.claude-plan-189"
ADR_DIR="$WORKTREE/docs/adr"

echo "Testing ADR 0003 updates..."
# Test for February 2026 Update section
if ! grep -q "February 2026 Update" "$ADR_DIR/0003-opus46-configuration-upgrade.md"; then
  echo "FAIL: ADR 0003 missing 'February 2026 Update' section"
  exit 1
fi

# Test for Opus 4.6 validation mention
if ! grep -qi "opus 4.6 validation" "$ADR_DIR/0003-opus46-configuration-upgrade.md"; then
  echo "FAIL: ADR 0003 missing Opus 4.6 validation content"
  exit 1
fi

# Test for thinking token monitoring
if ! grep -qi "thinking token" "$ADR_DIR/0003-opus46-configuration-upgrade.md"; then
  echo "FAIL: ADR 0003 missing thinking token monitoring content"
  exit 1
fi

# Test for 18 models mention
if ! grep -q "18 models" "$ADR_DIR/0003-opus46-configuration-upgrade.md"; then
  echo "FAIL: ADR 0003 missing 18 models reference"
  exit 1
fi

echo "✓ ADR 0003 tests passed"

echo "Testing ADR 0009 updates..."
# Test for @import optimization section
if ! grep -q "@import Optimization" "$ADR_DIR/0009-compact-markdown-format.md"; then
  echo "FAIL: ADR 0009 missing @import optimization section"
  exit 1
fi

# Test for T0-01 reference
if ! grep -q "T0-01" "$ADR_DIR/0009-compact-markdown-format.md"; then
  echo "FAIL: ADR 0009 missing T0-01 reference"
  exit 1
fi

# Test for lazy-load clarification
if ! grep -qi "NOT lazy" "$ADR_DIR/0009-compact-markdown-format.md"; then
  echo "FAIL: ADR 0009 missing lazy-load clarification"
  exit 1
fi

# Test for token cost strategy
if ! grep -qi "token cost" "$ADR_DIR/0009-compact-markdown-format.md"; then
  echo "FAIL: ADR 0009 missing token cost strategy"
  exit 1
fi

# Test for v2.0.0 format reference
if ! grep -q "v2.0.0" "$ADR_DIR/0009-compact-markdown-format.md"; then
  echo "FAIL: ADR 0009 missing v2.0.0 format reference"
  exit 1
fi

echo "✓ ADR 0009 tests passed"

echo "Testing ADR 0005 updates..."
# Test for ADR 0016 reference
if ! grep -q "ADR 0016" "$ADR_DIR/0005-multi-agent-concurrency-control.md" && \
   ! grep -q "ADR-0016" "$ADR_DIR/0005-multi-agent-concurrency-control.md"; then
  echo "FAIL: ADR 0005 missing ADR 0016 reference"
  exit 1
fi

# Test for Layer 5 expansion reference
if ! grep -q "Layer 5" "$ADR_DIR/0005-multi-agent-concurrency-control.md"; then
  echo "FAIL: ADR 0005 missing Layer 5 context (already exists, but verify reference)"
  exit 1
fi

echo "✓ ADR 0005 tests passed"

echo "All tests passed!"
exit 0
