#!/usr/bin/env bash
# pre-merge-gate.sh v1.0.0 — Quality gate before push/merge
# Runs automatically via PreToolUse hook on git push, or manually.
# Works with any repo (Claude Code, Copilot, any model).
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

pass() { echo -e "${GREEN}PASS${NC} $1"; }
fail() { echo -e "${RED}FAIL${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YELLOW}WARN${NC} $1"; WARNINGS=$((WARNINGS + 1)); }

echo "=== Pre-Merge Quality Gate ==="
echo ""

# Gate 1: Clean working tree (no unstaged modifications)
DIRTY=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY" -gt 0 ]; then
  fail "Working tree has $DIRTY unstaged modified files"
  echo "  Files:"
  git diff --name-only 2>/dev/null | head -10 | sed 's/^/    /'
  [ "$DIRTY" -gt 10 ] && echo "    ... and $((DIRTY - 10)) more"
else
  pass "Working tree clean (no unstaged changes)"
fi

# Gate 2: No untracked project files (ignore .claude/, .copilot-tracking/, etc.)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v '^\.claude/' | grep -v '^\.copilot-tracking/' | grep -v '^\.agent-workflow/' | wc -l | tr -d ' ')
if [ "$UNTRACKED" -gt 0 ]; then
  warn "$UNTRACKED untracked project files (review before merge)"
  git ls-files --others --exclude-standard 2>/dev/null | grep -v '^\.claude/' | grep -v '^\.copilot-tracking/' | grep -v '^\.agent-workflow/' | head -5 | sed 's/^/    /'
else
  pass "No untracked project files"
fi

# Gate 3: Type-check (frontend — if tsconfig.app.json exists)
if [ -f "webapp/frontend/tsconfig.app.json" ]; then
  echo -n "Running TypeScript type-check... "
  if cd webapp/frontend && npx tsc --noEmit -p tsconfig.app.json 2>/dev/null; then
    cd - > /dev/null
    pass "TypeScript type-check"
  else
    cd - > /dev/null
    TS_ERRORS=$(cd webapp/frontend && npx tsc --noEmit -p tsconfig.app.json 2>&1 | grep -c 'error TS' || true)
    cd - > /dev/null 2>/dev/null
    fail "TypeScript: $TS_ERRORS errors"
  fi
elif [ -f "tsconfig.app.json" ]; then
  echo -n "Running TypeScript type-check... "
  if npx tsc --noEmit -p tsconfig.app.json 2>/dev/null; then
    pass "TypeScript type-check"
  else
    fail "TypeScript type-check failed"
  fi
else
  pass "No tsconfig.app.json — skipping type-check"
fi

# Gate 4: Python tests (if pytest available)
if [ -f "pyproject.toml" ] || [ -f "webapp/tests" ] || [ -d "tests" ]; then
  PYTEST_CMD=""
  if [ -f ".venv/bin/python" ]; then
    PYTEST_CMD=".venv/bin/python -m pytest"
  elif command -v pytest &>/dev/null; then
    PYTEST_CMD="pytest"
  fi
  if [ -n "$PYTEST_CMD" ]; then
    echo -n "Running Python tests... "
    if $PYTEST_CMD -m "not integration" -q --tb=no 2>/dev/null | tail -1 | grep -q "passed"; then
      PASSED=$($PYTEST_CMD -m "not integration" -q --tb=no 2>/dev/null | tail -1)
      pass "pytest: $PASSED"
    else
      fail "pytest failed"
    fi
  fi
fi

# Gate 5: Version sync check
if [ -f "VERSION.md" ]; then
  V_MD=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' VERSION.md | head -1)
  if [ -f "scripts/python/pyproject.toml" ]; then
    V_TOML=$(grep -oE 'version = "[0-9]+\.[0-9]+\.[0-9]+"' scripts/python/pyproject.toml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [ "$V_MD" = "$V_TOML" ]; then
      pass "Version sync: $V_MD (VERSION.md = pyproject.toml)"
    else
      fail "Version mismatch: VERSION.md=$V_MD, pyproject.toml=$V_TOML"
    fi
  fi
  if [ -f "package.json" ]; then
    V_PKG=$(grep -oE '"version": "[0-9]+\.[0-9]+\.[0-9]+"' package.json | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [ "$V_MD" = "$V_PKG" ]; then
      pass "Version sync: $V_MD (VERSION.md = package.json)"
    else
      fail "Version mismatch: VERSION.md=$V_MD, package.json=$V_PKG"
    fi
  fi
fi

# Gate 6: Stash hygiene
STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
if [ "$STASH_COUNT" -gt 3 ]; then
  warn "$STASH_COUNT stashes accumulated — clean up after merge"
else
  pass "Stash count OK ($STASH_COUNT)"
fi

echo ""
echo "=== Results: $ERRORS errors, $WARNINGS warnings ==="

if [ "$ERRORS" -gt 0 ]; then
  echo -e "${RED}BLOCKED${NC} — fix $ERRORS errors before merge"
  exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
  echo -e "${YELLOW}PROCEED WITH CAUTION${NC} — $WARNINGS warnings"
  exit 0
fi

echo -e "${GREEN}ALL GATES PASSED${NC}"
exit 0
