#!/bin/bash
# hardening-check.sh — Quick repo hardening audit (JSON output)
# v1.0.0 | Used by planner to decide if Wave 0 hardening is needed
# Usage: hardening-check.sh [--project-root <path>]
set -euo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

PASSED=0
FAILED=0
GAPS=()

check() {
	local name="$1" condition="$2" severity="$3"
	if eval "$condition" >/dev/null 2>&1; then
		PASSED=$((PASSED + 1))
	else
		FAILED=$((FAILED + 1))
		GAPS+=("{\"name\":\"$name\",\"severity\":\"$severity\"}")
	fi
}

# Detect project type
HAS_NODE=false
HAS_PYTHON=false
HAS_DB=false
[ -f "package.json" ] || [ -f "webapp/frontend/package.json" ] && HAS_NODE=true
[ -f "requirements.txt" ] || [ -f "webapp/requirements.txt" ] || [ -f "pyproject.toml" ] && HAS_PYTHON=true
[ -f "alembic.ini" ] || [ -d "webapp/alembic" ] || [ -d "prisma" ] && HAS_DB=true

# === Git Hooks ===
check "pre-commit-exists" "test -f .husky/pre-commit || test -f .githooks/pre-commit" "critical"
check "pre-commit-multi-check" "test -f .husky/pre-commit && [ \$(wc -l < .husky/pre-commit) -gt 5 ]" "warning"
check "pre-push-exists" "test -f .husky/pre-push || test -f .githooks/pre-push" "warning"
check "commit-msg-hook" "test -f .husky/commit-msg || test -f .githooks/commit-msg" "info"

# === Linting ===
if $HAS_NODE; then
	check "eslint-config" \
		"find . -maxdepth 3 -name 'eslint.config.*' -o -name '.eslintrc*' 2>/dev/null | head -1 | grep -q ." \
		"critical"
	check "prettier-config" \
		"find . -maxdepth 3 -name '.prettierrc*' -o -name 'prettier.config.*' 2>/dev/null | head -1 | grep -q ." \
		"info"
fi
if $HAS_PYTHON; then
	check "python-linter" "test -f ruff.toml || test -f pyproject.toml || test -f .flake8 || test -f setup.cfg" "critical"
fi

# === Secrets Scanning ===
check "secrets-scan-script" \
	"test -f scripts/quality/secrets-scan.sh || test -f scripts/secrets-scan.sh || test -f .pre-commit-config.yaml" \
	"critical"

# === Environment Variables ===
check "env-example" "test -f .env.example || test -f webapp/.env.example" "warning"
check "env-var-audit" \
	"test -f scripts/quality/env-var-audit.sh || test -f scripts/env-var-audit.sh" \
	"info"

# === Debt Enforcement ===
check "debt-check-script" \
	"find . -maxdepth 4 -name 'debt-check*.sh' 2>/dev/null | head -1 | grep -q ." \
	"warning"

# === PR Template ===
check "pr-template-exists" "test -f .github/pull_request_template.md" "warning"
check "pr-template-verification" \
	"test -f .github/pull_request_template.md && grep -q 'Verification Evidence' .github/pull_request_template.md" \
	"warning"

# === ADR Structure ===
check "adr-directory" "test -d docs/adr || test -d doc/adr || test -d adr" "info"
check "adr-index" \
	"test -f docs/adr/INDEX.md || test -f doc/adr/INDEX.md || test -f adr/INDEX.md" \
	"info"

# === Output JSON ===
TOTAL=$((PASSED + FAILED))
if [ ${#GAPS[@]} -gt 0 ]; then
	GAPS_JSON=$(printf '%s,' "${GAPS[@]}" | sed 's/,$//')
else
	GAPS_JSON=""
fi

cat <<EOF
{
  "project_root": "$PROJECT_ROOT",
  "project_type": {
    "node": $HAS_NODE,
    "python": $HAS_PYTHON,
    "database": $HAS_DB
  },
  "score": "$PASSED/$TOTAL",
  "passed": $PASSED,
  "failed": $FAILED,
  "status": "$([ $FAILED -eq 0 ] && echo "pass" || echo "gaps_found")",
  "gaps": [$GAPS_JSON]
}
EOF
