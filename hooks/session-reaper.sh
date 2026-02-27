#!/bin/bash
# session-reaper.sh - Claude Code Stop hook
# Kills orphaned shell processes when a session ends.
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)

# Find which shell-snapshot this session uses
# The session's temp dir pattern helps identify its processes
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

# Run reaper async (don't delay session shutdown)
{
	# Session is ending — kill all orphaned processes immediately
	"$HOME/.claude/scripts/session-reaper.sh" --max-age 0 2>/dev/null
} &

exit 0
