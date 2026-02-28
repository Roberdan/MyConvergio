#!/usr/bin/env bash
set -uo pipefail

# session-file-lock.sh — Copilot CLI preToolUse hook
# Acquires a session-based file lock before allowing file modifications.
# Prevents concurrent edits across sessions on the same worktree.
# Input: JSON via stdin (Copilot hook protocol)
# Output: JSON with permissionDecision on block

# Opt-out via env var
[[ "${CLAUDE_FILE_LOCK:-1}" == "0" ]] && exit 0

source ~/.claude/hooks/lib/file-lock-common.sh 2>/dev/null || exit 0

for cmd in jq sqlite3; do
	command -v "$cmd" >/dev/null 2>&1 || exit 0
done

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""' 2>/dev/null)
FILE_PATH=$(extract_file_path "$INPUT")

# Only enforce on edit/write tools
case "$TOOL_NAME" in
edit | write | editFile | writeFile | multiEdit) ;;
*) exit 0 ;;
esac

# Cannot lock without identity or target
[[ -z "$SESSION_ID" || -z "$FILE_PATH" ]] && exit 0

# Skip non-lockable paths
should_skip_path "$FILE_PATH" && exit 0

AGENT_NAME="${CLAUDE_AGENT_NAME:-copilot-cli}"

RESULT=$(try_acquire_lock "$FILE_PATH" "$SESSION_ID" "$AGENT_NAME") || {
	HOLDER_AGENT=$(echo "$RESULT" | jq -r '.held_by.agent // "unknown"' 2>/dev/null)
	HOLDER_AGE=$(echo "$RESULT" | jq -r '.held_by.age_sec // "?"' 2>/dev/null)
	MSG="File locked by $HOLDER_AGENT (age: ${HOLDER_AGE}s). Wait or run: file-lock.sh release \"$FILE_PATH\""
	jq -n --arg r "$MSG" '{permissionDecision: "deny", permissionDecisionReason: $r}'
	exit 0
}

# Acquired or re-entrant
exit 0
