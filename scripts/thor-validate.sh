#!/bin/bash
# Thor Quick Validation - Runs all validations in one command
# Reduces tokens by running via bash instead of inline agent work
# Usage: thor-validate.sh <plan_id> [--full]

# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAN_ID="${1:?Usage: thor-validate.sh <plan_id> [--full]}"
FULL_CHECK="${2:-}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "THOR VALIDATION - Plan $PLAN_ID"
echo "=========================================="
echo ""

ERRORS=0

# 1. Database validation
echo "[1/4] Database integrity..."
if "$SCRIPT_DIR/plan-db.sh" validate "$PLAN_ID" >/tmp/thor_db_$$.log 2>&1; then
	echo -e "${GREEN}  PASS${NC}"
else
	echo -e "${RED}  FAIL - see /tmp/thor_db_$$.log${NC}"
	((ERRORS++))
fi

# 2. F-xx validation
echo "[2/4] F-xx requirements..."
if "$SCRIPT_DIR/plan-db.sh" validate-fxx "$PLAN_ID" >/tmp/thor_fxx_$$.log 2>&1; then
	echo -e "${GREEN}  PASS${NC}"
else
	echo -e "${RED}  FAIL - see /tmp/thor_fxx_$$.log${NC}"
	((ERRORS++))
fi

# 3. Build check (if --full)
if [[ "$FULL_CHECK" == "--full" ]]; then
	echo "[3/4] Build check..."
	if npm run lint 2>&1 | tail -10 >/tmp/thor_lint_$$.log &&
		npm run typecheck 2>&1 | tail -10 >/tmp/thor_type_$$.log &&
		npm run build 2>&1 | tail -10 >/tmp/thor_build_$$.log; then
		echo -e "${GREEN}  PASS${NC}"
	else
		echo -e "${RED}  FAIL - check logs in /tmp/thor_*_$$.log${NC}"
		((ERRORS++))
	fi
else
	echo "[3/4] Build check... SKIPPED (use --full)"
fi

# 4. File size check (project source files, not ~/.claude scripts)
# Resolve project path (default: current directory)
PROJECT_PATH="${PROJECT_PATH:-.}"
PROJECT_PATH=$(cd "$PROJECT_PATH" 2>/dev/null && pwd) || {
	echo -e "${RED}  FAIL - invalid project path${NC}"
	((ERRORS++))
	PROJECT_PATH=""
}

echo "[4/4] File sizes (<250 lines)..."
LARGE_FILES=""
if [[ -n "$PROJECT_PATH" ]] && [[ -d "$PROJECT_PATH/src" ]]; then
	LARGE_FILES=$(find "$PROJECT_PATH/src" -name "*.ts" -o -name "*.tsx" 2>/dev/null |
		grep -v node_modules | grep -v '.test.' |
		while read -r f; do
			lines=$(/usr/bin/wc -l <"$f" 2>/dev/null | tr -d ' ')
			[[ $lines -gt 250 ]] && echo "$f: $lines"
		done)
fi

if [[ -z "$LARGE_FILES" ]]; then
	echo -e "${GREEN}  PASS${NC}"
else
	echo -e "${YELLOW}  WARNING - Large files:${NC}"
	echo "$LARGE_FILES" | head -5
	((ERRORS++))
fi

echo ""
echo "=========================================="
if [[ $ERRORS -eq 0 ]]; then
	echo -e "${GREEN}THOR VALIDATION: PASSED${NC}"
	exit 0
else
	echo -e "${RED}THOR VALIDATION: FAILED ($ERRORS issues)${NC}"
	exit 1
fi
