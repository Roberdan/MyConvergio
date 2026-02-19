#!/bin/bash
# Pre-push hook — Quality gates before push
# Runs: env-var audit, debt check, typecheck, tests
# ADAPT: Change paths, test commands, thresholds
set -uo pipefail

# ADAPT: Project paths
FRONTEND_DIR="webapp/frontend"
SCRIPTS_DIR="$FRONTEND_DIR/scripts"
PYTHON_DIR="webapp"
PYTHON_TEST_CMD="python -m pytest -x -q --timeout=30"

FAILED=0
warn() { echo "[pre-push] WARNING: $1" >&2; }
fail() {
	echo "[pre-push] FAILED: $1" >&2
	FAILED=1
}

# --- Gate 1: Environment variable audit ---
if [ -x "$SCRIPTS_DIR/env-var-audit.sh" ]; then
	"$SCRIPTS_DIR/env-var-audit.sh" || warn "Frontend env-var audit failed"
fi
# ADAPT: Backend env-var audit
if [ -x "scripts/python/quality/env-var-audit.sh" ]; then
	scripts/python/quality/env-var-audit.sh || warn "Backend env-var audit failed"
fi

# --- Gate 2: Duplicate commit detection ---
BRANCH=$(git branch --show-current 2>/dev/null || echo "HEAD")
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
	LAST_MSG=$(git log -1 --format=%s 2>/dev/null)
	DUPES=$(git log origin/main..HEAD --format=%s 2>/dev/null | grep -cF "$LAST_MSG" || echo 0)
	[ "$DUPES" -gt 1 ] && warn "Duplicate commit message detected: '$LAST_MSG'"
fi

# --- Gate 3: Technical debt check ---
if [ -x "$SCRIPTS_DIR/debt-check.sh" ]; then
	"$SCRIPTS_DIR/debt-check.sh" || fail "Debt thresholds exceeded"
fi

# --- Gate 4: TypeScript typecheck ---
# ADAPT: Typecheck command
if [ -d "$FRONTEND_DIR" ]; then
	npm --prefix "$FRONTEND_DIR" run typecheck 2>&1 | tail -5 || fail "TypeScript errors"
fi

# --- Gate 5: Tests ---
# ADAPT: Test commands
if [ -d "$FRONTEND_DIR" ]; then
	npm --prefix "$FRONTEND_DIR" run test -- --run 2>&1 | tail -10 || fail "Frontend tests"
fi
# ADAPT: Python tests
if [ -d "$PYTHON_DIR" ]; then
	(cd "$PYTHON_DIR" && $PYTHON_TEST_CMD 2>&1 | tail -10) || fail "Backend tests"
fi

[ $FAILED -ne 0 ] && echo "[pre-push] Push blocked. Fix failures above." && exit 1
echo "[pre-push] All gates passed"
