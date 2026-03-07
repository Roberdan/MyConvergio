#!/usr/bin/env bash
set -euo pipefail

# enforce-line-limit.sh — Copilot CLI postToolUse hook
# Blocks Write/Edit operations that produce files exceeding 250 lines.
# Input: JSON via stdin (Copilot hook protocol)

MAX_LINES=250

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // .tool_name // ""' 2>/dev/null)

# Extract file_path from current and legacy hook payloads
FILE=$(echo "$INPUT" | jq -r '.toolArgs.file_path // .toolArgs.filePath // .tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

# Only check edit/write tools when a tool name is present.
case "$TOOL_NAME" in
"" | edit | write | editFile | writeFile) ;;
*) exit 0 ;;
esac

# Skip non-code files
case "$FILE" in
*.lock | *.sum | *.min.js | *.min.css | package-lock.json | yarn.lock) exit 0 ;;
*/node_modules/* | */vendor/* | */.git/* | */dist/* | */build/*) exit 0 ;;
*.db | *.sqlite | *.sqlite3) exit 0 ;;
esac

LINE_COUNT=$(/usr/bin/wc -l <"$FILE" 2>/dev/null | tr -d '[:space:]')
LINE_COUNT=${LINE_COUNT:-0}

if [ "$LINE_COUNT" -gt "$MAX_LINES" ] 2>/dev/null; then
	echo "BLOCKED: File exceeds $MAX_LINES line limit ($LINE_COUNT lines)"
	echo "File: $FILE"
	echo ""
	echo "ACTION REQUIRED: Split this file into smaller modules."
	echo "This limit is NON-NEGOTIABLE (Core Rule #6)."
	exit 1
fi

exit 0
