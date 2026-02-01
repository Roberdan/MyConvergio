#!/bin/bash
# Generate self-contained prompt for Copilot CLI worker
# Usage: copilot-task-prompt.sh <db_task_id>
# Output: prompt string to stdout (pipe to copilot -p)

set -euo pipefail

TASK_ID="${1:-}"
if [[ -z "$TASK_ID" ]]; then
	echo "Usage: copilot-task-prompt.sh <db_task_id>" >&2
	exit 1
fi

DB_FILE="${HOME}/.claude/data/dashboard.db"

# Fetch task + wave + plan info in one query
TASK_JSON=$(sqlite3 "$DB_FILE" "
	SELECT json_object(
		'task_id', t.task_id, 'title', t.title,
		'description', COALESCE(t.description,''),
		'test_criteria', COALESCE(t.test_criteria,''),
		'wave_id', w.wave_id, 'wave_name', w.name,
		'plan_id', t.plan_id, 'plan_name', p.name,
		'worktree_path', COALESCE(p.worktree_path,''),
		'db_task_id', t.id
	) FROM tasks t
	JOIN waves w ON t.wave_id_fk = w.id
	JOIN plans p ON t.plan_id = p.id
	WHERE t.id = $TASK_ID;
")

if [[ -z "$TASK_JSON" ]]; then
	echo "Task $TASK_ID not found" >&2
	exit 1
fi

# Parse fields
TITLE=$(echo "$TASK_JSON" | jq -r '.title')
DESC=$(echo "$TASK_JSON" | jq -r '.description')
TC=$(echo "$TASK_JSON" | jq -r '.test_criteria')
WAVE=$(echo "$TASK_JSON" | jq -r '.wave_id')
TID=$(echo "$TASK_JSON" | jq -r '.task_id')
WT_RAW=$(echo "$TASK_JSON" | jq -r '.worktree_path')
PLAN_ID=$(echo "$TASK_JSON" | jq -r '.plan_id')

# Expand worktree path
WT="${WT_RAW/#\~/$HOME}"

# Detect test framework
FW="unknown"
if [[ -f "$WT/package.json" ]]; then
	if grep -q '"vitest"' "$WT/package.json" 2>/dev/null; then
		FW="vitest"
	elif grep -q '"jest"' "$WT/package.json" 2>/dev/null; then
		FW="jest"
	else FW="node"; fi
elif [[ -f "$WT/pyproject.toml" ]]; then
	FW="pytest"
elif [[ -f "$WT/Cargo.toml" ]]; then
	FW="cargo"
fi

# Generate prompt
cat <<PROMPT
# Task Execution: $TID ($TITLE)

## CRITICAL RULES
1. Work ONLY in: $WT
2. NEVER checkout or work on main/master branch
3. Run \`worktree-guard.sh "$WT"\` FIRST. If it fails, STOP.
4. Follow TDD: write tests FIRST, then implement

## Setup
\`\`\`bash
export PATH="\$HOME/.claude/scripts:\$PATH"
cd "$WT" && pwd
worktree-guard.sh "$WT"
plan-db.sh update-task $TASK_ID in_progress "Started by Copilot"
\`\`\`

## Task
**Wave**: $WAVE | **Task**: $TID | **Framework**: $FW

**Do**: $TITLE

$DESC

## Test Criteria
$TC

## TDD Workflow
1. Write FAILING tests based on test criteria above
2. Run tests, confirm they FAIL (RED)
3. Implement minimum code to make tests PASS (GREEN)
4. Refactor if needed

## Completion
\`\`\`bash
plan-db.sh update-task $TASK_ID done "Summary of what was done" --tokens 0
\`\`\`

## Coding Standards
- Max 250 lines per file. Split if exceeds.
- No TODO, FIXME, @ts-ignore in new code
- English for all code and comments
- Conventional commits if committing
PROMPT
