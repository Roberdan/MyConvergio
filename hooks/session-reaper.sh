#!/usr/bin/env bash
set -uo pipefail

# session-reaper.sh — Copilot CLI sessionEnd hook
# Kills orphaned shell processes when a session ends.
# Version: 1.0.0

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

# Run reaper async (don't delay session shutdown)
{
	# Session is ending — kill all orphaned processes immediately
	"$HOME/.claude/scripts/session-reaper.sh" --max-age 0 2>/dev/null
} &

exit 0
