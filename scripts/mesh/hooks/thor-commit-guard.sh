#!/bin/bash
# thor-commit-guard.sh - Blocks commits when active plan has unvalidated done tasks
# Version: 1.0.0
# Hook type: preToolUse (for git commit tool calls)
set -euo pipefail

DB_FILE="${HOME}/.claude/data/dashboard.db"

# Skip if no database
[[ ! -f "$DB_FILE" ]] && exit 0

# Get input from stdin (Claude Code hook format)
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // empty' 2>/dev/null) || true

# Only check on git commit operations
case "$TOOL_NAME" in
Bash)
	COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // .input.command // empty' 2>/dev/null) || true
	# Only trigger on git commit commands
	[[ "$COMMAND" != *"git commit"* ]] && exit 0
	;;
*)
	exit 0
	;;
esac

# Find active plans for current project
PROJECT_DIR=$(pwd)
FOLDER_NAME=$(basename "$PROJECT_DIR")
PROJECT_ID=$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

# Check for unvalidated done tasks in active plans
UNVALIDATED=$(sqlite3 "$DB_FILE" "
  SELECT t.task_id, t.title FROM tasks t
  JOIN waves w ON t.wave_id_fk = w.id
  JOIN plans p ON w.plan_id = p.id
  WHERE p.project_id = '$PROJECT_ID'
    AND p.status IN ('todo', 'doing')
    AND t.status = 'done'
    AND t.validated_at IS NULL
  LIMIT 10;
" 2>/dev/null) || true

if [[ -n "$UNVALIDATED" ]]; then
	echo "BLOCKED: Unvalidated tasks found. Run per-task Thor validation first:" >&2
	echo "$UNVALIDATED" | while IFS='|' read -r tid title; do
		echo "  - $tid: $title" >&2
	done
	echo "" >&2
	echo "Fix: plan-db.sh validate-task <task_id> <plan_id>" >&2
	# Output deny decision for Claude Code hook format
	echo '{"decision":"deny","reason":"Unvalidated done tasks exist. Run Thor per-task validation first."}' | jq -c .
	exit 2
fi

exit 0
