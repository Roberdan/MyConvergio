#!/bin/bash
# guard-settings.sh — Copilot CLI version
# PostToolUse hook: auto-strips codegraph CLI hooks from settings.json after Edit/Write.
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only run after edit/write tools
case "$TOOL_NAME" in
Edit | Write | editFile | writeFile) ;;
*) exit 0 ;;
esac

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && FILE="${CLAUDE_FILE_PATH:-}"

# Only act on settings.json files
case "$FILE" in
*settings.json) ;;
*) exit 0 ;;
esac

[ ! -f "$FILE" ] && exit 0

# Auto-strip codegraph CLI commands (MCP-only, no binary exists)
if grep -qE '"codegraph ' "$FILE" 2>/dev/null; then
	CLEANED=$(jq '
		walk(if type == "array" then
			map(if type == "object" and (.command // "" | test("^codegraph "))
				then empty else . end)
			else . end) |
		walk(if type == "object" and has("hooks") and
			(.hooks | type == "array") and (.hooks | length == 0)
			then empty else . end)
	' "$FILE" 2>/dev/null)

	if [ -n "$CLEANED" ] && echo "$CLEANED" | python3 -m json.tool >/dev/null 2>&1; then
		echo "$CLEANED" >"$FILE"
		echo "AUTO-FIXED: Stripped codegraph CLI hooks from $FILE"
	fi
fi

exit 0
