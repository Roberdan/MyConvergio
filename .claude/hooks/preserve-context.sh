#!/bin/bash
# PreCompact hook - preserve critical context before compaction
# v2.0.0: Full plan checkpoint + MEMORY.md update + recovery instructions
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HOOK_DIR/lib/common.sh" 2>/dev/null || true

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0

# 1. Auto-checkpoint active plan (writes to checkpoint file + MEMORY.md)
CHECKPOINT_RESULT=""
if command -v plan-checkpoint.sh &>/dev/null; then
	CHECKPOINT_RESULT=$(plan-checkpoint.sh save-auto 2>/dev/null || echo "")
fi

# 2. Read checkpoint content for injection
PRESERVED=""
if [[ -n "$CHECKPOINT_RESULT" ]] && [[ -f "$CHECKPOINT_RESULT" ]]; then
	PRESERVED=$(cat "$CHECKPOINT_RESULT")
fi

# 3. Fallback: extract plan ID from transcript if checkpoint didn't find active plan
if [[ -z "$PRESERVED" ]]; then
	PLAN_ID=$(jq -r '
		[.[] | select(.type == "human") | .message // empty | strings]
		| reverse | .[:20] | join(" ")
		| capture("plan[_-]?(?<id>[0-9]+)") | .id // empty
	' "$TRANSCRIPT_PATH" 2>/dev/null || echo "")

	if [[ -n "$PLAN_ID" ]]; then
		# Try to generate checkpoint from plan ID
		CHECKPOINT_RESULT=$(plan-checkpoint.sh save "$PLAN_ID" 2>/dev/null || echo "")
		if [[ -n "$CHECKPOINT_RESULT" ]] && [[ -f "$CHECKPOINT_RESULT" ]]; then
			PRESERVED=$(cat "$CHECKPOINT_RESULT")
		else
			# Minimal fallback
			CURRENT_TASK=""
			if check_dashboard 2>/dev/null; then
				CURRENT_TASK=$(sqlite3 "$DASHBOARD_DB" \
					"SELECT task_id || ': ' || title FROM tasks WHERE plan_id = '$PLAN_ID' AND status IN ('in_progress','submitted') LIMIT 3;" \
					2>/dev/null || echo "")
			fi
			PRESERVED="Active Plan: $PLAN_ID"
			[[ -n "$CURRENT_TASK" ]] && PRESERVED="$PRESERVED\nActive Tasks: $CURRENT_TASK"
		fi
	fi
fi

# 4. Add coordinator protocol reminder
if [[ -n "$PRESERVED" ]]; then
	PRESERVED="$PRESERVED

## Post-Compaction Recovery Protocol
1. Read checkpoint: \`plan-checkpoint.sh restore <plan_id>\`
2. Verify DB state: \`plan-db.sh execution-tree <plan_id>\`
3. Check worktree: \`cd <worktree_path> && git status\`
4. Resume: launch next pending task or run Thor on submitted tasks
5. DO NOT re-read files already processed — trust task-executor results"
fi

[ -z "$PRESERVED" ] && exit 0

jq -n --arg ctx "$PRESERVED" '{"additionalContext": $ctx}'
