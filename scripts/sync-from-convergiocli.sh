#!/bin/bash

# =============================================================================
# MYCONVERGIO SYNC FROM CONVERGIOCLI
# =============================================================================
# Syncs agent definitions from the ConvergioCLI repository
# Source: https://github.com/Roberdan/convergio-cli/tree/main/src/agents/definitions
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_DIR="$ROOT_DIR/.claude/agents"
TEMP_DIR="/tmp/convergiocli-sync-$$"

# Source repository
REPO_URL="https://github.com/Roberdan/convergio-cli.git"
SOURCE_PATH="src/agents/definitions"

# Parse arguments
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --dry-run   Show what would be synced without making changes"
            echo "  --verbose   Show detailed output"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo -e "${BLUE}MyConvergio Agent Sync${NC}"
echo "Source: $REPO_URL"
echo "Target: $TARGET_DIR"
echo ""

# Clone repository with sparse checkout
echo -e "${BLUE}Fetching latest agents from ConvergioCLI...${NC}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

git clone --depth 1 --filter=blob:none --sparse "$REPO_URL" repo 2>/dev/null
cd repo
git sparse-checkout set "$SOURCE_PATH" 2>/dev/null

if [ ! -d "$SOURCE_PATH" ]; then
    echo -e "${RED}Error: Could not find $SOURCE_PATH in repository${NC}"
    exit 1
fi

# Count files
SOURCE_COUNT=$(find "$SOURCE_PATH" -name '*.md' | wc -l | tr -d ' ')
TARGET_COUNT=$(find "$TARGET_DIR" -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' 2>/dev/null | wc -l | tr -d ' ')

echo -e "${BLUE}Found $SOURCE_COUNT agents in ConvergioCLI${NC}"
echo -e "${BLUE}Current $TARGET_COUNT agents in MyConvergio${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN - No changes will be made${NC}"
    echo ""
fi

# Compare and sync
NEW_COUNT=0
UPDATED_COUNT=0
UNCHANGED_COUNT=0

for src_file in $(find "$SOURCE_PATH" -name '*.md'); do
    filename=$(basename "$src_file")

    # Skip non-agent files
    if [[ "$filename" == "README.md" ]] || [[ "$filename" == "index.md" ]]; then
        continue
    fi

    # Determine target category (from source path)
    rel_path="${src_file#$SOURCE_PATH/}"
    category=$(dirname "$rel_path")

    if [ "$category" = "." ]; then
        # Root level file, put in core_utility
        category="core_utility"
    fi

    target_file="$TARGET_DIR/$category/$filename"

    if [ ! -f "$target_file" ]; then
        echo -e "${GREEN}NEW: $category/$filename${NC}"
        NEW_COUNT=$((NEW_COUNT + 1))

        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$TARGET_DIR/$category"
            cp "$src_file" "$target_file"
        fi
    elif ! diff -q "$src_file" "$target_file" >/dev/null 2>&1; then
        echo -e "${YELLOW}UPDATED: $category/$filename${NC}"
        UPDATED_COUNT=$((UPDATED_COUNT + 1))

        if [ "$DRY_RUN" = false ]; then
            cp "$src_file" "$target_file"
        fi

        if [ "$VERBOSE" = true ]; then
            echo "  Diff:"
            diff "$target_file" "$src_file" | head -10 || true
            echo ""
        fi
    else
        UNCHANGED_COUNT=$((UNCHANGED_COUNT + 1))
        if [ "$VERBOSE" = true ]; then
            echo -e "  UNCHANGED: $category/$filename"
        fi
    fi
done

echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  New agents:       ${GREEN}$NEW_COUNT${NC}"
echo -e "  Updated agents:   ${YELLOW}$UPDATED_COUNT${NC}"
echo -e "  Unchanged agents: $UNCHANGED_COUNT"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo -e "${YELLOW}Run without --dry-run to apply changes${NC}"
else
    if [ $NEW_COUNT -gt 0 ] || [ $UPDATED_COUNT -gt 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Sync complete${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Review changes: git diff"
        echo "  2. Commit: git add -A && git commit -m 'feat: sync agents from ConvergioCLI'"
    else
        echo ""
        echo -e "${GREEN}✅ Already up to date${NC}"
    fi
fi
