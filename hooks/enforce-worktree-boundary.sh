#!/usr/bin/env bash
# enforce-worktree-boundary.sh — PreToolUse hook (Edit|Write|MultiEdit)
# Blocks edits to files OUTSIDE the active plan's worktree.
# If no plan active or no worktree set, allows all (safe fallback).
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""' 2>/dev/null)

# Only check edit/write tools
case "$TOOL_NAME" in
edit | write | multiEdit | editFile | writeFile | multiEditFile) ;;
*) exit 0 ;;
esac

DB_FILE="${HOME}/.claude/data/dashboard.db"
PLAN_FILE="${HOME}/.claude/data/active-plan-id.txt"

# No active plan -> allow
[ ! -f "$PLAN_FILE" ] && exit 0
PLAN_ID=$(grep -m1 -E '^[0-9]+$' "$PLAN_FILE" 2>/dev/null || true)
[ -z "$PLAN_ID" ] && exit 0
[ ! -f "$DB_FILE" ] && exit 0

# Get worktree path: try wave worktree first (via current task), then plan worktree
TASK_DB_ID="${CLAUDE_TASK_DB_ID:-}"
WORKTREE=""

if [[ -n "$TASK_DB_ID" ]]; then
	# Wave-level worktree from current task's wave
	WORKTREE=$(sqlite3 "$DB_FILE" \
		"SELECT w.worktree_path FROM waves w
		 JOIN tasks t ON t.wave_id_fk = w.id
		 WHERE t.id = $TASK_DB_ID AND w.worktree_path IS NOT NULL AND w.worktree_path <> ''
		 LIMIT 1;" 2>/dev/null || echo "")
fi

# Fallback to plan-level worktree
if [[ -z "$WORKTREE" ]]; then
	WORKTREE=$(sqlite3 "$DB_FILE" \
		"SELECT worktree_path FROM plans WHERE id = $PLAN_ID AND worktree_path IS NOT NULL AND worktree_path <> '';" 2>/dev/null || echo "")
fi

# No worktree configured -> allow (config repos, legacy plans)
[ -z "$WORKTREE" ] && exit 0

# Expand tilde
[[ "$WORKTREE" == "~/"* ]] && WORKTREE="${HOME}/${WORKTREE:2}"
[[ "$WORKTREE" == "~" ]] && WORKTREE="$HOME"

# Resolve to absolute path
WORKTREE=$(cd "$WORKTREE" 2>/dev/null && pwd || echo "$WORKTREE")

# No directory -> allow
[ ! -d "$WORKTREE" ] && exit 0

# Extract file_path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.toolArgs.file_path // .toolArgs.filePath // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# Normalize: expand tilde
[[ "$FILE_PATH" == "~/"* ]] && FILE_PATH="${HOME}/${FILE_PATH:2}"
# Resolve relative paths
[[ "$FILE_PATH" != /* ]] && FILE_PATH="${PWD}/${FILE_PATH}"
# Resolve symlinks + normalize
FILE_PATH=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && echo "$(pwd)/$(basename "$FILE_PATH")" || echo "$FILE_PATH")

# Check: file must be inside worktree
if [[ "$FILE_PATH" == "$WORKTREE"/* || "$FILE_PATH" == "$WORKTREE" ]]; then
	exit 0
fi

# Also allow ~/.claude/ edits (config repo, hooks, rules — always accessible)
if [[ "$FILE_PATH" == "${HOME}/.claude"/* ]]; then
	exit 0
fi

jq -n --arg f "$FILE_PATH" --arg wt "$WORKTREE" --arg p "$PLAN_ID" \
	'{permissionDecision: "deny", permissionDecisionReason: ("BLOCKED: File " + $f + " is OUTSIDE plan " + $p + " worktree (" + $wt + "). Agents must work ONLY inside their assigned worktree.")}'
exit 0
