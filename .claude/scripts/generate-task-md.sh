#!/bin/bash
# Task Markdown Generation Script
# Usage: ./generate-task-md.sh <project> <plan_id> <wave> <task_id> <task_name> <assignee> <estimate>
# Example: ./generate-task-md.sh my-project 8 0 T01 "Setup database migration" "CLAUDE 2" "1h"

set -e

PROJECT=$1
PLAN_ID=$2
WAVE=$3
TASK_ID=$4
TASK_NAME=$5
ASSIGNEE=$6
ESTIMATE=$7

if [ -z "$PROJECT" ] || [ -z "$PLAN_ID" ] || [ -z "$WAVE" ] || [ -z "$TASK_ID" ] || [ -z "$TASK_NAME" ]; then
  echo "❌ Usage: $0 <project> <plan_id> <wave> <task_id> <task_name> [assignee] [estimate]"
  echo "Example: $0 my-project 8 0 T01 'Setup database migration' 'CLAUDE 2' '1h'"
  exit 1
fi

ASSIGNEE=${ASSIGNEE:-"TBD"}
ESTIMATE=${ESTIMATE:-"TBD"}

PLAN_DIR=~/.claude/plans/active/${PROJECT}/plan-${PLAN_ID}
WAVE_DIR=${PLAN_DIR}/waves/W${WAVE}
TASK_DIR=${WAVE_DIR}/tasks

mkdir -p ${TASK_DIR}

# Generate slug from task name
TASK_SLUG=$(echo "${TASK_NAME}" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
TASK_FILE=${TASK_DIR}/${TASK_ID}-${TASK_SLUG}.md

# Generate task markdown
cat > "${TASK_FILE}" <<EOF
# Task: ${TASK_ID} - ${TASK_NAME}

**Wave:** W${WAVE}
**Status:** pending
**Priority:** P1
**Assignee:** ${ASSIGNEE}
**Estimate:** ${ESTIMATE}
**Created:** $(date +"%Y-%m-%d %H:%M %Z")

---

## Description

[Description to be filled by planner]

## Acceptance Criteria

- [ ] Criterion 1 (to be defined)
- [ ] Criterion 2 (to be defined)
- [ ] Criterion 3 (to be defined)

## Dependencies

- **Depends on:** None
- **Blocks:** None

## Files Affected

- _To be documented during planning_

## Technical Notes

- _To be documented during planning_

---

## Execution Log

_This section is automatically populated during task execution by the executor tracking system._

### Activity Timeline

| Timestamp | Event | Details |
|-----------|-------|---------|
| _TBD_ | _TBD_ | _TBD_ |

---

## File Changes

_This section is automatically populated during task execution._

\`\`\`diff
# Changes will be tracked here
\`\`\`

---

## Validation

_Populated after task completion_

### Verification Checklist

- [ ] Lint passed (\`npm run lint\`)
- [ ] Typecheck passed (\`npm run typecheck\`)
- [ ] Build passed (\`npm run build\`)
- [ ] Tests passed (if applicable)
- [ ] Acceptance criteria met
- [ ] Code reviewed (if multi-Claude)
- [ ] Documentation updated (if required)

### Verification Output

\`\`\`
_Command outputs will be pasted here_
\`\`\`

---

## Links

- **Wave:** [W${WAVE}-wave-name.md](../../W${WAVE}-wave-name.md)
- **Plan:** [plan-${PLAN_ID}.md](../../../../plan-${PLAN_ID}.md)
- **Dashboard:** [View in Dashboard](http://localhost:31415?project=${PROJECT}&task=${TASK_ID})

---

**Last Updated:** $(date +"%Y-%m-%d %H:%M %Z")
EOF

echo "✅ Generated: ${TASK_FILE}"

# Update database with markdown_path (if dashboard is running)
RESPONSE=$(curl -s -X POST "http://localhost:31415/api/project/${PROJECT}/task/${TASK_ID}/update-markdown" \
  -H "Content-Type: application/json" \
  -d "{\"markdown_path\": \"${TASK_FILE}\"}" 2>&1)

if echo "$RESPONSE" | grep -q "success"; then
  echo "✅ Database updated with markdown_path"
elif echo "$RESPONSE" | grep -q "error"; then
  # Task doesn't exist yet - this is OK, will be created when planner runs
  echo "⚠️  Task not yet in database (will be created during planning)"
else
  echo "⚠️  Dashboard may not be running"
  echo "   Start dashboard to enable automatic database updates"
fi

echo ""
echo "📝 Task markdown file created at: ${TASK_FILE}"
echo "📊 View in dashboard: http://localhost:31415?project=${PROJECT}&task=${TASK_ID}"
