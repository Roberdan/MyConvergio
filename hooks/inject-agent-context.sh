#!/bin/bash
# SubagentStart hook - inject common context into subagents
# Replaces boilerplate removed from individual agent files
# Version: 1.1.0
set -euo pipefail

source ~/.claude/hooks/lib/common.sh 2>/dev/null || true

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
[ -z "$AGENT_TYPE" ] && exit 0

# Core constitution for all agents
CONTEXT="## Constitution
- Verify before claim: Read file before answering. No fabrication.
- Act, don't suggest: Implement changes directly.
- Minimum complexity: Only what's requested.
- Max 250 lines/file: Split if exceeds.
- Language: Code/comments in English, conversation in Italian."

# Add security reference for code-executing agents
case "$AGENT_TYPE" in
task-executor* | Bash | app-release-manager* | mirrorbuddy*)
	CONTEXT="${CONTEXT}
## Security
- Parameterized queries only (no raw SQL)
- No secrets in code or logs
- CSP headers required for web
- TLS 1.2+ for external calls
- RBAC enforcement on all endpoints"
	;;
esac

# Output JSON with additionalContext
jq -n --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
