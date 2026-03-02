#!/bin/bash
# session-file-lock.sh - Claude Code PreToolUse hook for Edit|Write|MultiEdit
# Acquires a session-based file lock before allowing file modifications.
# Prevents concurrent edits across sessions on the same worktree.
# Exit 0=allow, Exit 2=block
# Version: 1.0.0
set -uo pipefail

# Opt-out via env var
[[ "${CLAUDE_FILE_LOCK:-1}" == "0" ]] && exit 0

source ~/.claude/hooks/lib/common.sh 2>/dev/null || true
source ~/.claude/hooks/lib/file-lock-common.sh 2>/dev/null || {
	exit 0 # Missing library = allow (graceful degradation)
}

check_deps jq sqlite3 || exit 0

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
FILE_PATH=$(extract_file_path "$INPUT")

# Cannot lock without identity or target
[[ -z "$SESSION_ID" || -z "$FILE_PATH" ]] && exit 0

# Skip non-lockable paths
should_skip_path "$FILE_PATH" && exit 0

AGENT_NAME="${CLAUDE_AGENT_NAME:-claude-code}"

RESULT=$(try_acquire_lock "$FILE_PATH" "$SESSION_ID" "$AGENT_NAME") || {
	format_block_message "$FILE_PATH" "$RESULT"
	exit 2
}

# Acquired or re-entrant
exit 0
