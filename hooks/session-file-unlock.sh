#!/bin/bash
# session-file-unlock.sh - Claude Code Stop hook
# Releases all file locks held by this session on exit.
# Version: 1.0.0
set -uo pipefail

source ~/.claude/hooks/lib/common.sh 2>/dev/null || true
source ~/.claude/hooks/lib/file-lock-common.sh 2>/dev/null || exit 0

check_deps jq sqlite3 || exit 0

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

[[ -z "$SESSION_ID" ]] && exit 0

# Release locks async (don't delay session shutdown)
{
	RESULT=$(try_release_locks "$SESSION_ID")
	COUNT=$(echo "$RESULT" | jq -r '.released_count // 0' 2>/dev/null)
	if [[ "$COUNT" -gt 0 ]]; then
		log_hook "session-file-unlock" "Released $COUNT lock(s) for session ${SESSION_ID:0:12}"
	fi
} &

exit 0
