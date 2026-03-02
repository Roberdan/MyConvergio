#!/bin/bash
# file-lock-common.sh - Shared utilities for session file lock hooks
# Used by both Claude Code and Copilot CLI hooks.
# Version: 1.0.0

FILE_LOCK_SCRIPT="${HOME}/.claude/scripts/file-lock.sh"

# Extract file_path from hook JSON input (handles both platforms)
# Claude Code: .tool_input.file_path | Copilot CLI: .toolArgs.file_path/.filePath
extract_file_path() {
	local input="$1"
	local fp
	fp=$(echo "$input" | jq -r '
		.tool_input.file_path //
		.toolArgs.file_path //
		.toolArgs.filePath //
		empty
	' 2>/dev/null)
	echo "$fp"
}

# Check if a path should be skipped (non-lockable files)
should_skip_path() {
	local fp="$1"
	case "$fp" in
	*.lock | *.sum | package-lock.json | yarn.lock) return 0 ;;
	*/node_modules/* | */.git/* | */dist/* | */build/*) return 0 ;;
	*.db | *.sqlite | *.sqlite3) return 0 ;;
	/tmp/* | /var/*) return 0 ;;
	*.min.js | *.min.css) return 0 ;;
	"") return 0 ;;
	esac
	return 1
}

# Acquire a session lock. Returns 0 on success, 1 on block.
# Usage: try_acquire_lock <file_path> <session_id> <agent_name>
try_acquire_lock() {
	local file="$1" session_id="$2" agent="${3:-session-agent}"
	"$FILE_LOCK_SCRIPT" acquire-session "$file" "$session_id" "$agent" 5 2>&1
}

# Release all locks for a session.
# Usage: try_release_locks <session_id>
try_release_locks() {
	local session_id="$1"
	"$FILE_LOCK_SCRIPT" release-session "$session_id" 2>/dev/null
}

# Format a blocked message for user feedback
format_block_message() {
	local file="$1" result="$2"
	local holder_agent holder_sid holder_age
	holder_agent=$(echo "$result" | jq -r '.held_by.agent // "unknown"' 2>/dev/null)
	holder_sid=$(echo "$result" | jq -r '.held_by.session_id // "unknown"' 2>/dev/null)
	holder_age=$(echo "$result" | jq -r '.held_by.age_sec // "?"' 2>/dev/null)
	echo "BLOCKED: File locked by another session." >&2
	echo "  File: $file" >&2
	echo "  Holder: $holder_agent (session: ${holder_sid:0:12}..., age: ${holder_age}s)" >&2
	echo "  Wait for the other session to finish editing this file." >&2
	echo "  Manual release: file-lock.sh release \"$file\"" >&2
}
