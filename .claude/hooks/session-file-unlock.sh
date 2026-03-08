#!/usr/bin/env bash
set -uo pipefail

# session-file-unlock.sh — Copilot CLI sessionEnd hook
# Releases all file locks held by this session on exit.

MYCONVERGIO_HOME="${MYCONVERGIO_HOME:-$HOME/.myconvergio}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HOOK_DIR/lib/file-lock-common.sh" 2>/dev/null || exit 0

for cmd in jq sqlite3; do
	command -v "$cmd" >/dev/null 2>&1 || exit 0
done

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

[[ -z "$SESSION_ID" ]] && exit 0

# Release locks async
{
	RESULT=$(try_release_locks "$SESSION_ID")
	COUNT=$(echo "$RESULT" | jq -r '.released_count // 0' 2>/dev/null)
	if [[ "$COUNT" -gt 0 ]]; then
		echo "[$(date '+%H:%M:%S')] [session-file-unlock] Released $COUNT lock(s)" \
			>>"${MYCONVERGIO_HOME}/logs/hooks.log" 2>/dev/null
	fi
} &

exit 0
