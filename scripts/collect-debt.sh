#!/bin/bash
# Technical Debt Collector - Finds TODO, FIXME, HACK, DEFERRED, SKIPPED
# Usage: ./collect-debt.sh [project_path]
# Output: JSON to stdout

set -euo pipefail

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Patterns to search
PATTERNS=("TODO" "FIXME" "HACK" "DEFERRED" "SKIPPED" "XXX" "BUG" "OPTIMIZE")

# File extensions to search
EXTENSIONS=("ts" "tsx" "js" "jsx" "py" "go" "rs" "java" "cpp" "c" "h" "rb" "php" "swift" "kt" "scala" "md")

# Build grep pattern
PATTERN_REGEX=$(IFS="|"; echo "${PATTERNS[*]}")

# Build extension filter
EXT_FILTER=""
for ext in "${EXTENSIONS[@]}"; do
    EXT_FILTER="$EXT_FILTER --include=*.$ext"
done

# Search for debt items
DEBT_ITEMS='[]'
if command -v rg &> /dev/null; then
    # Use ripgrep if available (faster)
    DEBT_ITEMS=$(rg -n --no-heading --color=never \
        -e "TODO" -e "FIXME" -e "HACK" -e "DEFERRED" -e "SKIPPED" -e "XXX" -e "BUG" -e "OPTIMIZE" \
        -g "*.ts" -g "*.tsx" -g "*.js" -g "*.jsx" -g "*.py" -g "*.go" -g "*.rs" -g "*.md" \
        --glob '!node_modules' --glob '!.git' --glob '!dist' --glob '!build' --glob '!coverage' \
        . 2>/dev/null | head -200 | awk -F: '{
            file=$1; line=$2; text=$0; sub(/^[^:]+:[^:]+:/, "", text);
            gsub(/"/, "\\\"", text);
            # Determine type
            type="todo"
            if (text ~ /FIXME/) type="fixme"
            else if (text ~ /HACK/) type="hack"
            else if (text ~ /DEFERRED/) type="deferred"
            else if (text ~ /SKIPPED/) type="skipped"
            else if (text ~ /XXX/) type="todo"
            else if (text ~ /BUG/) type="fixme"
            else if (text ~ /OPTIMIZE/) type="todo"
            print "{\"file\":\"" file "\",\"line\":" line ",\"text\":\"" text "\",\"type\":\"" type "\"}"
        }' | jq -s '.' || echo '[]')
else
    # Fallback to grep
    DEBT_ITEMS=$(grep -rn --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
        --include="*.py" --include="*.go" --include="*.md" \
        -E "(TODO|FIXME|HACK|DEFERRED|SKIPPED|XXX|BUG|OPTIMIZE)" \
        --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
        . 2>/dev/null | head -200 | awk -F: '{
            file=$1; line=$2; text=$0; sub(/^[^:]+:[^:]+:/, "", text);
            gsub(/"/, "\\\"", text);
            type="todo"
            if (text ~ /FIXME/) type="fixme"
            else if (text ~ /HACK/) type="hack"
            else if (text ~ /DEFERRED/) type="deferred"
            else if (text ~ /SKIPPED/) type="skipped"
            print "{\"file\":\"" file "\",\"line\":" line ",\"text\":\"" text "\",\"type\":\"" type "\"}"
        }' | jq -s '.' || echo '[]')
fi

# Group by type
BY_TYPE=$(echo "$DEBT_ITEMS" | jq '{
    todo: [.[] | select(.type == "todo")],
    fixme: [.[] | select(.type == "fixme")],
    hack: [.[] | select(.type == "hack")],
    deferred: [.[] | select(.type == "deferred")],
    skipped: [.[] | select(.type == "skipped")]
}')

# Count total
TOTAL=$(echo "$DEBT_ITEMS" | jq 'length')

# Build output
jq -n \
    --arg collector "debt" \
    --arg timestamp "$TIMESTAMP" \
    --argjson total "$TOTAL" \
    --argjson byType "$BY_TYPE" \
    --argjson items "$DEBT_ITEMS" \
    '{
        collector: $collector,
        timestamp: $timestamp,
        status: "success",
        data: {
            total: $total,
            byType: $byType,
            lastScan: $timestamp
        }
    }'
