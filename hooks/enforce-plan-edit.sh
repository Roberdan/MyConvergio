#!/bin/bash
# enforce-plan-edit.sh - PreToolUse hook on Edit/Write/MultiEdit
# Blocks edits on plan-tracked files unless running as task-executor.
# Exit 0=allow, Exit 2=block
# Version: 1.0.0
set -uo pipefail

PLAN_FILE="${HOME}/.claude/data/active-plan-id.txt"

# C-05: No active plan file -> allow (safe fallback)
[ ! -f "$PLAN_FILE" ] && exit 0

# Read plan_id (first non-empty line)
PLAN_ID=$(grep -m1 . "$PLAN_FILE" 2>/dev/null || true)

# No plan active -> allow
[ -z "$PLAN_ID" ] && exit 0

FILES_CACHE="${HOME}/.claude/data/plan-${PLAN_ID}-files.txt"

# No files cache for this plan -> allow
[ ! -f "$FILES_CACHE" ] && exit 0

# Read JSON input from stdin
INPUT=$(cat)

# Extract file_path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

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
	echo "BLOCKED: File ${FILE_PATH} is tracked by active plan ${PLAN_ID}. Use Task(subagent_type=\"task-executor\") for plan files." >&2
	exit 2
fi

exit 0
