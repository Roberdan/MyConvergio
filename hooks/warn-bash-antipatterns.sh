#!/bin/bash
# Block bash commands that have dedicated tool replacements
# Hook type: PreToolUse on Bash
# Version: 2.0.0 — upgraded from warn (exit 0) to block (exit 2)
# Why: warnings were ignored, wasting 3-4 tool calls per violation
set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Extract first command (before pipe)
FIRST_CMD=$(echo "$COMMAND" | sed 's/|.*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

# === BLOCK: standalone grep/rg → use Grep tool ===
if echo "$FIRST_CMD" | grep -qE "^(grep|rg) " 2>/dev/null; then
	echo "BLOCKED: Use Grep tool instead of $(echo "$FIRST_CMD" | awk '{print $1}') in Bash." >&2
	echo "The Grep tool is faster and doesn't count against Bash permissions." >&2
	exit 2
fi

# === BLOCK: cat/head/tail for file reading → use Read tool ===
if echo "$FIRST_CMD" | grep -qE "^cat [^|<>]+$" 2>/dev/null; then
	echo "BLOCKED: Use Read tool instead of cat." >&2
	exit 2
fi
if echo "$FIRST_CMD" | grep -qE "^(head|tail) " 2>/dev/null; then
	echo "BLOCKED: Use Read tool (with offset/limit) instead of head/tail." >&2
	exit 2
fi

# === BLOCK: find → use Glob tool ===
if echo "$FIRST_CMD" | grep -qE "^find " 2>/dev/null; then
	echo "BLOCKED: Use Glob tool instead of find." >&2
	exit 2
fi

# === BLOCK: sed -i → use Edit tool ===
if echo "$FIRST_CMD" | grep -qE "^sed (-i|.* -i)" 2>/dev/null; then
	echo "BLOCKED: Use Edit tool instead of sed -i." >&2
	exit 2
fi

# === BLOCK: standalone sqlite3 → use db-query.sh ===
if echo "$FIRST_CMD" | grep -qE "^sqlite3 " 2>/dev/null; then
	echo "BLOCKED: Use db-query.sh for custom SQL or db-digest.sh for standard queries." >&2
	exit 2
fi

# === WARN ONLY: piped grep/head/tail ===
# These are sometimes legitimate (script output truncation, filtering).
# Standalone grep/head/tail are BLOCKED above. Pipes are just warnings.
if echo "$COMMAND" | grep -qE '\|[[:space:]]*(grep|rg) ' 2>/dev/null; then
	echo "Hint: Consider using Grep tool instead of piping to grep." >&2
	exit 0
fi

# === WARN: zsh != in double-quoted sqlite3 ===
if echo "$COMMAND" | grep -qE 'sqlite3.*"[^"]*!=.*"' 2>/dev/null; then
	echo "BLOCKED: '!=' inside double-quoted sqlite3 breaks in zsh (! expansion)." >&2
	echo "Fix: Use SQL '<>' or 'NOT IN (...)' instead of '!='." >&2
	exit 2
fi

# === WARN: echo/printf for file writing → use Write tool ===
if echo "$FIRST_CMD" | grep -qE "^(echo|printf) " 2>/dev/null && echo "$COMMAND" | grep -qE ">" 2>/dev/null; then
	echo "BLOCKED: Use Write tool instead of echo/printf redirect." >&2
	exit 2
fi

exit 0
