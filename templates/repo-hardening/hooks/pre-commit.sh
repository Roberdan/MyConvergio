#!/bin/bash
# Pre-commit hook — Multi-phase: validate THEN format
# Phase 1: Read-only checks (secrets, lint errors). Fails fast.
# Phase 2: Auto-fixes (lint-staged, formatting). Only runs if Phase 1 passes.
# ADAPT: Change FRONTEND_DIR, PYTHON_DIR, test runner, lint commands
set -uo pipefail

# ADAPT: Project paths
FRONTEND_DIR="webapp/frontend"
PYTHON_DIR="webapp"
SCRIPTS_DIR="$FRONTEND_DIR/scripts"

# --- Phase 1: Validation (read-only, no file modifications) ---
echo "[pre-commit] Phase 1: Validation"

# Secrets scan (staged files only)
if [ -x "$SCRIPTS_DIR/secrets-scan.sh" ]; then
	"$SCRIPTS_DIR/secrets-scan.sh" || {
		echo "[BLOCKED] Secrets detected in staged files. Remove before committing."
		exit 1
	}
fi

# ADAPT: Python linting (if applicable)
STAGED_PY=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.py$' || true)
if [ -n "$STAGED_PY" ]; then
	if command -v ruff >/dev/null 2>&1; then
		echo "$STAGED_PY" | xargs ruff check --no-fix --quiet 2>/dev/null || {
			echo "[BLOCKED] Python lint errors. Fix before committing."
			exit 1
		}
	fi
fi

echo "[pre-commit] Phase 1: OK"

# --- Phase 2: Auto-fixes (formatting, lint --fix) ---
echo "[pre-commit] Phase 2: Formatting"

# ADAPT: lint-staged command
if [ -d "$FRONTEND_DIR" ]; then
	npm --prefix "$FRONTEND_DIR" exec lint-staged
fi

# ADAPT: Python formatting (if applicable)
if [ -n "$STAGED_PY" ]; then
	if command -v black >/dev/null 2>&1; then
		echo "$STAGED_PY" | xargs black --quiet 2>/dev/null
		echo "$STAGED_PY" | xargs git add
	fi
fi

echo "[pre-commit] Done"
