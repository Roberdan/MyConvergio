#!/bin/bash
set -euo pipefail
# Generate self-contained prompt for Copilot CLI worker
# Usage: copilot-task-prompt.sh <db_task_id>
# Output: prompt string to stdout (pipe to copilot -p)

# Version: 2.1.0
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

# Fetch completed tasks with output_data from same plan (inter-task context)
PRIOR_OUTPUTS=$(sqlite3 "$DB_FILE" "
	SELECT group_concat(
		t.task_id || ': ' || COALESCE(t.output_data, ''),
		char(10)
	) FROM tasks t
	JOIN waves w ON t.wave_id_fk = w.id
	WHERE t.plan_id = $PLAN_ID
	  AND t.status = 'done'
	  AND t.output_data IS NOT NULL
	  AND t.output_data <> ''
	ORDER BY w.position, t.task_id;
")

# Check for PR feedback from previous wave (overlapping wave protocol)
PR_FEEDBACK=""
PREV_WAVE_INFO=$(sqlite3 "$DB_FILE" "
	SELECT pw.id, pw.pr_number, pw.merge_mode
	FROM waves pw
	WHERE pw.plan_id = $PLAN_ID
	  AND pw.position < (SELECT cw.position FROM waves cw JOIN tasks ct ON ct.wave_id_fk = cw.id WHERE ct.id = $TASK_ID)
	  AND pw.merge_mode = 'async'
	ORDER BY pw.position DESC LIMIT 1;
" 2>/dev/null || true)
if [[ -n "$PREV_WAVE_INFO" ]]; then
	PREV_WAVE_ID=$(echo "$PREV_WAVE_INFO" | cut -d'|' -f1)
	FEEDBACK_FILE="${HOME}/.claude/data/pr-feedback-wave-${PREV_WAVE_ID}.txt"
	if [[ -f "$FEEDBACK_FILE" ]]; then
		PR_FEEDBACK=$(cat "$FEEDBACK_FILE" 2>/dev/null | head -50)
	fi
fi

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

## !! MANDATORY COMPLETION — READ THIS FIRST !!

**You MUST run this command when your work is done. This is NON-NEGOTIABLE.**
**If you skip this, the plan dashboard will show 0% progress.**

\`\`\`bash
plan-db-safe.sh update-task $TASK_ID done "Summary of what was done" --tokens 0 --output-data '{"summary":"what was done","artifacts":["file1.ts"]}'
\`\`\`

Use \`plan-db-safe.sh\` (NOT \`plan-db.sh\`). \`plan-db.sh\` will REJECT done status.

## Setup
\`\`\`bash
export PATH="\$HOME/.claude/scripts:\$PATH"
cd "$WT" && pwd
worktree-guard.sh "$WT"
worktree-safety.sh audit "$WT" 2>/dev/null || true
plan-db-safe.sh update-task $TASK_ID in_progress "Started by Copilot"
\`\`\`

## Rules
1. Work ONLY in: $WT — NEVER checkout main/master
2. If \`worktree-guard.sh\` fails, STOP immediately
3. TDD: tests FIRST, then implement

## Task
**Wave**: $WAVE | **Task**: $TID | **Framework**: $FW | **Plan**: $PLAN_ID

**Do**: $TITLE

$DESC

## Prior Task Outputs
$(if [[ -n "$PRIOR_OUTPUTS" ]]; then echo "$PRIOR_OUTPUTS"; else echo "None."; fi)

## Previous Wave PR Feedback
$(if [[ -n "$PR_FEEDBACK" ]]; then
echo "⚠️ The previous wave's PR had review feedback. Do NOT repeat these issues:"
echo ""
echo "$PR_FEEDBACK"
else echo "None."; fi)

## Test Criteria
$TC

## TDD Workflow
1. Write FAILING tests based on test criteria above
2. Run tests, confirm they FAIL (RED)
3. Implement minimum code to make tests PASS (GREEN)
4. Refactor if needed

## Coding Standards
- Max 250 lines per file. Split if exceeds.
- No TODO, FIXME, @ts-ignore in new code
- English for all code and comments

## !! FINAL STEP — DO NOT SKIP !!

Run this BEFORE you finish. If you already ran it above, verify with:
\`\`\`bash
sqlite3 ~/.claude/data/dashboard.db "SELECT status FROM tasks WHERE id=$TASK_ID;"
# Must show: done
\`\`\`

If NOT done, run:
\`\`\`bash
plan-db-safe.sh update-task $TASK_ID done "Summary" --tokens 0
\`\`\`
PROMPT
