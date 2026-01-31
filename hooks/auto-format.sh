#!/bin/bash
# Auto-format hook for Claude Code
# Runs after Edit/Write/MultiEdit to format code automatically
# PostToolUse hook receives JSON on stdin

# Read JSON input from stdin
INPUT=$(cat)

# Extract file_path from tool_input
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && FILE="${CLAUDE_FILE_PATH:-}"

# Exit if no file path
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0

# Format based on extension
case "$FILE" in
  *.py)
    command -v black >/dev/null && black -q "$FILE" 2>/dev/null
    ;;
  *.js|*.jsx|*.ts|*.tsx|*.json|*.css|*.scss|*.md)
    command -v prettier >/dev/null && prettier --write "$FILE" 2>/dev/null
    ;;
  *.swift)
    command -v swift-format >/dev/null && swift-format format -i "$FILE" 2>/dev/null
    ;;
  *.go)
    command -v gofmt >/dev/null && gofmt -w "$FILE" 2>/dev/null
    ;;
  *.rs)
    command -v rustfmt >/dev/null && rustfmt "$FILE" 2>/dev/null
    ;;
  *.sh|*.bash)
    command -v shfmt >/dev/null && shfmt -w "$FILE" 2>/dev/null
    ;;
esac

exit 0
