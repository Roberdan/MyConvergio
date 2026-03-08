#!/usr/bin/env bash
set -euo pipefail

# advisory-suggest-alternatives.sh — Copilot CLI advisory hook
# Non-blocking tip: prefer LSP/codegraph for symbol-definition lookups.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // .tool_name // ""' 2>/dev/null)
TOOL_ARGS=$(echo "$INPUT" | jq -r '.toolArgs // .tool_input // {}' 2>/dev/null)
QUERY=$(echo "$TOOL_ARGS" | jq -r '.pattern // .query // .command // ""' 2>/dev/null)

case "$TOOL_NAME" in
grep | rg | Grep | Glob | glob | bash | shell) ;;
*) exit 0 ;;
esac

if echo "$QUERY" | grep -qE '\b[A-Z][A-Za-z0-9]+|[a-z]+_[a-z0-9_]+'; then
	jq -n '{
    permissionDecision: "allow",
    permissionDecisionReason: "Tip: LSP go-to-definition may be faster for symbol lookups. Also consider codegraph_search if .codegraph/ exists."
  }'
fi

exit 0
