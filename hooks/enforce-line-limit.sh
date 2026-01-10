#!/bin/bash
# Enforce 250 line limit - MANDATORY
# Blocks Write operations that exceed the limit

MAX_LINES=250
FILE="${CLAUDE_FILE_PATH:-}"

# Exit OK if no file or file doesn't exist
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0

# Skip non-code files
case "$FILE" in
  *.lock|*.sum|*.min.js|*.min.css|package-lock.json|yarn.lock)
    exit 0 ;;
  # Skip generated/vendor
  */node_modules/*|*/vendor/*|*/.git/*|*/dist/*|*/build/*)
    exit 0 ;;
  # Skip database files
  *.db|*.sqlite|*.sqlite3)
    exit 0 ;;
esac

# Count lines (use /usr/bin/wc to avoid custom wc aliases)
LINE_COUNT=$(/usr/bin/wc -l < "$FILE" 2>/dev/null | tr -d '[:space:]')
LINE_COUNT=${LINE_COUNT:-0}

if [ "$LINE_COUNT" -gt "$MAX_LINES" ] 2>/dev/null; then
  echo "BLOCKED: File exceeds $MAX_LINES line limit ($LINE_COUNT lines)"
  echo "File: $FILE"
  echo ""
  echo "ACTION REQUIRED: Split this file into smaller modules."
  echo "This limit is NON-NEGOTIABLE per CLAUDE.md Core Rule #6."
  exit 1
fi

exit 0
