#!/usr/bin/env bash
# env-vault-guard.sh — Copilot CLI preToolUse hook
# Blocks git commit when staged files contain high-risk secret patterns.
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // .tool_name // ""' 2>/dev/null)

if [[ "$TOOL_NAME" != "bash" && "$TOOL_NAME" != "shell" && "$TOOL_NAME" != "Bash" ]]; then
	exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.toolArgs.command // .tool_input.command // ""' 2>/dev/null)
if ! echo "$COMMAND" | grep -qE '(^|[;&[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
	exit 0
fi

PATTERNS='API_KEY=|SECRET=|PASSWORD=|CONNECTION_STRING=|private_key|token'
FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

for f in $FILES; do
	[ -f "$f" ] || continue
	if grep -E "$PATTERNS" "$f" >/dev/null 2>&1; then
		jq -n --arg r "BLOCKED: Secret-like pattern found in staged file: $f" \
			'{permissionDecision: "deny", permissionDecisionReason: $r}'
		exit 0
	fi
done

if [[ -f .gitignore ]] && ! grep -q '^.env$' .gitignore 2>/dev/null; then
	echo "[WARNING] .env not in .gitignore" >&2
fi

if [[ -f env_vault_log ]]; then
	last=$(tail -1 env_vault_log 2>/dev/null | awk '{print $1}')
	now=$(date +%s)
	if [[ "$last" =~ ^[0-9]+$ ]]; then
		diff=$((now - last))
		[ "$diff" -gt $((7 * 24 * 3600)) ] && echo "[WARNING] env_vault_log backup is stale (>7d)" >&2
	fi
fi

exit 0
