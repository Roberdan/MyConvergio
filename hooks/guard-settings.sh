#!/bin/bash
# Guard settings.json against known bad patterns
# PostToolUse hook - runs after Edit/Write on settings.json
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && FILE="${CLAUDE_FILE_PATH:-}"

# Only check settings.json
case "$FILE" in
*settings.json) ;;
*) exit 0 ;;
esac

[ ! -f "$FILE" ] && exit 0

# Block codegraph CLI commands (MCP-only, no binary exists)
if grep -qE '"codegraph (mark-dirty|sync-if-dirty|init|serve)"' "$FILE" 2>/dev/null; then
	echo "BLOCKED: codegraph CLI command found in $FILE"
	echo "CodeGraph is MCP-only (via mcp.json). There is NO codegraph binary."
	echo "Remove any 'codegraph ...' commands from hooks."
	exit 1
fi

exit 0
