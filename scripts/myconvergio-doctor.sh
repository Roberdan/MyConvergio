#!/bin/bash
# myconvergio-doctor.sh — Health check for MyConvergio installation
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
PASS=0
WARN=0
FAIL=0

check() {
	local name="$1" cmd="$2"
	if eval "$cmd" >/dev/null 2>&1; then
		echo -e "  ${GREEN}✓${NC} $name"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}✗${NC} $name"
		FAIL=$((FAIL + 1))
	fi
}

warn_check() {
	local name="$1" cmd="$2"
	if eval "$cmd" >/dev/null 2>&1; then
		echo -e "  ${GREEN}✓${NC} $name"
		PASS=$((PASS + 1))
	else
		echo -e "  ${YELLOW}⚠${NC} $name"
		WARN=$((WARN + 1))
	fi
}

echo "🩺 MyConvergio Health Check"
echo ""

echo "Prerequisites:"
check "bash available" "command -v bash"
check "git available" "command -v git"
check "make available" "command -v make"
warn_check "jq available" "command -v jq"
warn_check "sqlite3 available" "command -v sqlite3"
warn_check "bats available" "command -v bats"

echo ""
echo "Installation:"
CLAUDE_HOME="${HOME}/.claude"
check "~/.claude exists" "test -d $CLAUDE_HOME"
check "agents installed" "test -d $CLAUDE_HOME/agents"
warn_check "hooks installed" "test -d $CLAUDE_HOME/hooks"
warn_check "scripts installed" "test -d $CLAUDE_HOME/scripts"
warn_check "rules installed" "test -d $CLAUDE_HOME/rules"

echo ""
echo "Agents:"
if [ -d "$CLAUDE_HOME/agents" ]; then
	COUNT=$(find "$CLAUDE_HOME/agents" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
	check "$COUNT agent files found (expect 50+)" "[ $COUNT -ge 50 ]"
else
	echo -e "  ${RED}✗${NC} No agents directory"
	FAIL=$((FAIL + 1))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Results: ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL failed${NC}"

if [ $FAIL -gt 0 ]; then
	echo -e "${RED}Some checks failed. Run 'make install' to fix.${NC}"
	exit 1
elif [ $WARN -gt 0 ]; then
	echo -e "${YELLOW}Some optional components missing.${NC}"
	exit 0
else
	echo -e "${GREEN}All checks passed!${NC}"
	exit 0
fi
