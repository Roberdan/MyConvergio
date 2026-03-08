#!/usr/bin/env bash
set -euo pipefail

# enforce-standards.sh — Copilot CLI preToolUse hook
# Mirrors Claude Code's prefer-ci-summary.sh enforcement for Copilot CLI.
# Blocks token-wasteful commands and suggests efficient alternatives.
#
# Input: JSON via stdin (Copilot hook protocol)
# Output: JSON with permissionDecision (deny/allow)

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""')
TOOL_ARGS=$(echo "$INPUT" | jq -r '.toolArgs // ""')

# Only enforce on shell/bash tool calls
if [[ "$TOOL_NAME" != "bash" && "$TOOL_NAME" != "shell" ]]; then
	exit 0
fi

# Extract command from tool args
COMMAND=$(echo "$TOOL_ARGS" | jq -r '.command // ""')
if [[ -z "$COMMAND" ]]; then
	exit 0
fi

# Extract last command in chain (handles "cd /path && actual_command")
BASE_CMD=$(echo "$COMMAND" | sed 's/|.*//' | sed 's/.*&&//' | sed 's/.*;//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

deny() {
	local reason="$1"
	jq -n --arg r "$reason" '{permissionDecision: "deny", permissionDecisionReason: $r}'
	exit 0
}

# --- ALLOW: digest scripts always pass ---
echo "$COMMAND" | grep -qE "digest\.sh|service-digest" && exit 0
echo "$COMMAND" | grep -qE "ci-summary\.sh --(quick|full|all|lint|types|build|unit|i18n|e2e|a11y)" && exit 0

# --- BLOCK: verbose CI commands ---
if echo "$BASE_CMD" | grep -qE "^gh run (view|list)"; then
	deny "TOKEN-WASTE: Use 'service-digest.sh ci' instead of 'gh run view'."
fi

if echo "$BASE_CMD" | grep -qE "^gh pr (view|list)"; then
	deny "TOKEN-WASTE: Use 'service-digest.sh pr' instead of 'gh pr view'."
fi

if echo "$BASE_CMD" | grep -qE "^vercel (logs|inspect|ls)"; then
	deny "TOKEN-WASTE: Use 'service-digest.sh deploy' instead."
fi

# --- BLOCK: raw npm install/ci ---
if echo "$BASE_CMD" | grep -qE "^npm (install|ci)( |$)"; then
	deny "TOKEN-WASTE: Use 'npm-digest.sh install' instead."
fi

# --- BLOCK: raw npm audit ---
if echo "$BASE_CMD" | grep -qE "^npm audit( |$)"; then
	deny "TOKEN-WASTE: Use 'audit-digest.sh' instead."
fi

# --- BLOCK: raw npm run build ---
if echo "$BASE_CMD" | grep -qE "^npm run build( |$)"; then
	if [ -f "./scripts/ci-summary.sh" ]; then
		deny "TOKEN-WASTE: Use './scripts/ci-summary.sh --build' or '--quick' (lint+types)."
	else
		deny "TOKEN-WASTE: Use 'build-digest.sh' instead."
	fi
fi

# --- BLOCK: raw lint/typecheck/test:unit ---
if echo "$BASE_CMD" | grep -qE "^npm run (lint|typecheck|test:unit)( |$)"; then
	if [ -f "./scripts/ci-summary.sh" ]; then
		deny "TOKEN-WASTE: Use './scripts/ci-summary.sh --quick' (lint+types) or '--full' (all)."
	else
		deny "TOKEN-WASTE: Use test-digest.sh instead."
	fi
fi

# --- BLOCK: raw test runners ---
if echo "$BASE_CMD" | grep -qE "^(npx vitest|npx jest|npx playwright test)( |$)"; then
	deny "TOKEN-WASTE: Use 'test-digest.sh' for compact output."
fi

# --- BLOCK: git diff (except --stat) ---
if echo "$BASE_CMD" | grep -qE "^git diff"; then
	if echo "$BASE_CMD" | grep -qE "^git diff --stat( |$)"; then
		exit 0
	fi
	deny "TOKEN-WASTE: Use 'git-digest.sh --full' or 'diff-digest.sh'."
fi

# --- BLOCK: git status / git log ---
if echo "$BASE_CMD" | grep -qE "^git (status|log)( |$)"; then
	deny "TOKEN-WASTE: Use 'git-digest.sh' (or '--full' for details)."
fi

# --- BLOCK: raw prisma migrate ---
if echo "$BASE_CMD" | grep -qE "^(npx )?prisma migrate"; then
	deny "TOKEN-WASTE: Use 'migration-digest.sh status' instead."
fi

# --- ALLOW: everything else ---
exit 0
