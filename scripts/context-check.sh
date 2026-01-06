#!/bin/bash
# Context Optimization Check - Identifies token-heavy files
# Usage: context-check.sh [--fix]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CLAUDE_DIR="${HOME}/.claude"
FIX_MODE="${1:-}"
TOTAL_BYTES=0
ISSUES=0

echo "=========================================="
echo "CONTEXT OPTIMIZATION CHECK"
echo "=========================================="
echo ""

# 1. Check CLAUDE.md size
echo "[1/5] CLAUDE.md..."
SIZE=$(stat -f%z "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null || echo 0)
TOTAL_BYTES=$((TOTAL_BYTES + SIZE))
if [[ $SIZE -gt 5000 ]]; then
    echo -e "${YELLOW}  WARNING: ${SIZE} bytes (target <5KB)${NC}"
    ((ISSUES++))
else
    echo -e "${GREEN}  OK: ${SIZE} bytes${NC}"
fi

# 2. Check rules/ folder
echo "[2/5] Rules folder..."
RULES_SIZE=0
for f in "$CLAUDE_DIR/rules"/*.md; do
    [[ -f "$f" ]] && RULES_SIZE=$((RULES_SIZE + $(stat -f%z "$f")))
done
TOTAL_BYTES=$((TOTAL_BYTES + RULES_SIZE))
if [[ $RULES_SIZE -gt 30000 ]]; then
    echo -e "${RED}  ERROR: ${RULES_SIZE} bytes (target <30KB)${NC}"
    ((ISSUES++))
else
    echo -e "${GREEN}  OK: ${RULES_SIZE} bytes${NC}"
fi

# 3. Check for duplicate files
echo "[3/5] Duplicate patterns..."
DUPES=$(find "$CLAUDE_DIR/rules" -name "*.md" -type f 2>/dev/null | \
    xargs -I{} basename {} | sort | uniq -d)
if [[ -n "$DUPES" ]]; then
    echo -e "${RED}  ERROR: Duplicates found: $DUPES${NC}"
    ((ISSUES++))
else
    echo -e "${GREEN}  OK: No duplicates${NC}"
fi

# 4. Check large files (>250 lines)
echo "[4/5] File sizes..."
LARGE=$(find "$CLAUDE_DIR" -name "*.md" -type f 2>/dev/null | while read f; do
    lines=$(cat "$f" 2>/dev/null | /usr/bin/wc -l | tr -d ' ')
    [[ $lines -gt 250 ]] && echo "$(basename "$f"): $lines"
done | head -5)
if [[ -n "$LARGE" ]]; then
    echo -e "${YELLOW}  WARNING: Large files:${NC}"
    echo "$LARGE"
    ((ISSUES++))
else
    echo -e "${GREEN}  OK: All <250 lines${NC}"
fi

# 5. Total context estimate
echo "[5/5] Estimated context..."
# Rules + CLAUDE.md loaded at start
# Approx 4 chars per token
TOKENS=$((TOTAL_BYTES / 4))
if [[ $TOKENS -gt 10000 ]]; then
    echo -e "${YELLOW}  WARNING: ~${TOKENS} tokens at startup${NC}"
else
    echo -e "${GREEN}  OK: ~${TOKENS} tokens${NC}"
fi

echo ""
echo "=========================================="
echo "Total startup context: ~${TOKENS} tokens"
if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}OPTIMIZATION: GOOD${NC}"
else
    echo -e "${YELLOW}OPTIMIZATION: $ISSUES issues found${NC}"
fi
echo ""
echo "Tips:"
echo "- Keep rules/ minimal, detailed docs in reference/detailed/ (not auto-loaded)"
echo "- Split large files into smaller modules"
echo "- Start new conversations for fresh context"
