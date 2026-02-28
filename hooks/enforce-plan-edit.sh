#!/usr/bin/env bash
# enforce-plan-edit.sh — Copilot CLI preToolUse hook
# Blocks edits on plan-tracked files unless running as task-executor.
# Internal filter: only acts on edit/write/multiEdit tool calls.
# Exit 0=allow, deny via jq JSON output + exit 0
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""' 2>/dev/null)

# Only check edit/write tools
case "$TOOL_NAME" in
edit | write | multiEdit | editFile | writeFile | multiEditFile) ;;
*) exit 0 ;;
esac

PLAN_FILE="${HOME}/.claude/data/active-plan-id.txt"

# No active plan file -> allow (safe fallback)
[ ! -f "$PLAN_FILE" ] && exit 0

# Read plan_id (first non-empty line)
PLAN_ID=$(grep -m1 . "$PLAN_FILE" 2>/dev/null || true)

# No plan active -> allow
[ -z "$PLAN_ID" ] && exit 0

FILES_CACHE="${HOME}/.claude/data/plan-${PLAN_ID}-files.txt"

# No files cache for this plan -> allow
[ ! -f "$FILES_CACHE" ] && exit 0

# Extract file_path from toolArgs
FILE_PATH=$(echo "$INPUT" | jq -r '.toolArgs.file_path // .toolArgs.filePath // empty' 2>/dev/null)

# No file path in input -> allow
[ -z "$FILE_PATH" ] && exit 0

# Normalize path: resolve ~/ to $HOME
if [[ "$FILE_PATH" == "~/"* ]]; then
	FILE_PATH="${HOME}/${FILE_PATH:2}"
elif [[ "$FILE_PATH" == "~" ]]; then
	FILE_PATH="${HOME}"
fi

# Resolve relative paths (if not absolute, prepend pwd)
if [[ "$FILE_PATH" != /* ]]; then
	FILE_PATH="${PWD}/${FILE_PATH}"
fi

# Check if file is in the plan's tracked files cache
if grep -qxF "$FILE_PATH" "$FILES_CACHE" 2>/dev/null; then
	# Allow if running inside task-executor
	if [ "${CLAUDE_TASK_EXECUTOR:-0}" = "1" ]; then
		exit 0
	fi
	jq -n --arg f "$FILE_PATH" --arg p "$PLAN_ID" \
		'{permissionDecision: "deny", permissionDecisionReason: ("BLOCKED: File " + $f + " is tracked by active plan " + $p + ". Use copilot-worker.sh or task-executor for plan files.")}'
	exit 0
fi

exit 0
