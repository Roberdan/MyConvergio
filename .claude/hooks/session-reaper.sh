#!/usr/bin/env bash
set -uo pipefail

# session-reaper.sh — Copilot CLI sessionEnd hook
# Kills orphaned shell processes when a session ends.
# Version: 1.0.0

MYCONVERGIO_HOME="${MYCONVERGIO_HOME:-$HOME/.myconvergio}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(cd "$HOOK_DIR/.." && pwd)"
REAPER_SCRIPT="${MYCONVERGIO_SESSION_REAPER_SCRIPT:-$CLAUDE_DIR/scripts/session-reaper.sh}"
if [[ ! -x "$REAPER_SCRIPT" ]]; then
	REAPER_SCRIPT="${MYCONVERGIO_HOME}/scripts/session-reaper.sh"
fi

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

# Run reaper async (don't delay session shutdown)
{
	# Session is ending — kill all orphaned processes immediately
	[[ -x "$REAPER_SCRIPT" ]] && "$REAPER_SCRIPT" --max-age 0 2>/dev/null
} &

exit 0
