#!/usr/bin/env bash
# enforce-execution-preflight.sh — block risky plan commands without fresh readiness snapshot
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""' 2>/dev/null)
[[ "$TOOL_NAME" != "bash" && "$TOOL_NAME" != "shell" ]] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.toolArgs.command // ""' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

RISKY_PATTERN='execute-plan\.sh|copilot-worker\.sh|plan-db\.sh[[:space:]]+start|plan-db\.sh[[:space:]]+validate-(task|wave)|wave-worktree\.sh[[:space:]]+(merge|batch)'
if ! echo "$COMMAND" | grep -qE "$RISKY_PATTERN"; then
	exit 0
fi

if echo "$COMMAND" | grep -q 'execution-preflight\.sh'; then
	exit 0
fi

PLAN_ID=$(echo "$COMMAND" | sed -nE 's/.*plan-db\.sh[[:space:]]+start[[:space:]]+([0-9]+).*/\1/p')
if [[ -z "$PLAN_ID" ]]; then
	PLAN_ID=$(echo "$COMMAND" | sed -nE 's/.*execute-plan\.sh[[:space:]]+([0-9]+).*/\1/p')
fi
if [[ -z "$PLAN_ID" ]]; then
	PLAN_ID=$(echo "$COMMAND" | sed -nE 's/.*copilot-worker\.sh[[:space:]]+([0-9]+).*/\1/p')
fi
if [[ -z "$PLAN_ID" && -f "$HOME/.claude/data/active-plan-id.txt" ]]; then
	PLAN_ID=$(grep -m1 -E '^[0-9]+$' "$HOME/.claude/data/active-plan-id.txt" 2>/dev/null || true)
fi

[[ -z "$PLAN_ID" ]] && exit 0

SNAPSHOT="$HOME/.claude/data/execution-preflight/plan-${PLAN_ID}.json"
if [[ ! -f "$SNAPSHOT" ]]; then
	jq -n --arg plan_id "$PLAN_ID" '{
	  permissionDecision: "deny",
	  permissionDecisionReason: ("BLOCKED: missing execution preflight snapshot for plan " + $plan_id + ". Run execution-preflight.sh --plan-id " + $plan_id + " <worktree> before risky plan commands.")
	}'
	exit 0
fi

NOW=$(date +%s)
GENERATED_EPOCH=$(jq -r '.generated_epoch // 0' "$SNAPSHOT" 2>/dev/null || echo 0)
AGE=$((NOW - GENERATED_EPOCH))
if [[ "$AGE" -gt 1800 ]]; then
	jq -n --arg plan_id "$PLAN_ID" --arg age "$AGE" '{
	  permissionDecision: "deny",
	  permissionDecisionReason: ("BLOCKED: execution preflight for plan " + $plan_id + " is stale (" + $age + "s). Refresh preflight before continuing.")
	}'
	exit 0
fi

if jq -e '.warnings | index("dirty_worktree")' "$SNAPSHOT" >/dev/null 2>&1; then
	jq -n --arg plan_id "$PLAN_ID" '{
	  permissionDecision: "deny",
	  permissionDecisionReason: ("BLOCKED: plan " + $plan_id + " has dirty_worktree in the latest execution preflight snapshot.")
	}'
	exit 0
fi

if jq -e '.warnings | index("gh_auth_not_ready")' "$SNAPSHOT" >/dev/null 2>&1; then
	jq -n --arg plan_id "$PLAN_ID" '{
	  permissionDecision: "deny",
	  permissionDecisionReason: ("BLOCKED: plan " + $plan_id + " has gh_auth_not_ready in the latest execution preflight snapshot.")
	}'
	exit 0
fi

exit 0
