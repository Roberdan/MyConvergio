#!/bin/bash
set -euo pipefail
# Track Plan Change - Records plan modifications for learning/optimization
# Usage: ./track-plan-change.sh <project_id> <plan_name> <change_type> [--reason "text"] [--tasks-before N] [--tasks-after N]
# Change types: created, user_edit, scope_add, scope_remove, blocker, replan, task_split, completed

# Version: 1.1.0
set -euo pipefail

CLAUDE_HOME="${HOME}/.claude"
DB_FILE="${CLAUDE_HOME}/data/dashboard.db"

# Required args
PROJECT_ID="${1:-}"
PLAN_NAME="${2:-}"
CHANGE_TYPE="${3:-}"

if [[ -z "$PROJECT_ID" || -z "$PLAN_NAME" || -z "$CHANGE_TYPE" ]]; then
	echo "Usage: $0 <project_id> <plan_name> <change_type> [options]" >&2
	echo "Types: created, user_edit, scope_add, scope_remove, blocker, replan, task_split, completed" >&2
	exit 1
fi

# Validate change type
VALID_TYPES="created user_edit scope_add scope_remove blocker replan task_split completed"
if [[ ! " $VALID_TYPES " =~ " $CHANGE_TYPE " ]]; then
	echo "Invalid change_type: $CHANGE_TYPE" >&2
	echo "Valid types: $VALID_TYPES" >&2
	exit 1
fi

shift 3

# Optional args
REASON=""
TASKS_BEFORE=""
TASKS_AFTER=""
DIFF_SUMMARY=""

while [[ $# -gt 0 ]]; do
	case $1 in
	--reason)
		REASON="$2"
		shift 2
		;;
	--tasks-before)
		TASKS_BEFORE="$2"
		shift 2
		;;
	--tasks-after)
		TASKS_AFTER="$2"
		shift 2
		;;
	--diff)
		DIFF_SUMMARY="$2"
		shift 2
		;;
	*) shift ;;
	esac
done

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# SQL escape helper
sql_escape() { echo "${1//\'/\'\'}"; }

# Get current version number
SAFE_PROJECT_ID=$(sql_escape "$PROJECT_ID")
SAFE_PLAN_NAME=$(sql_escape "$PLAN_NAME")
CURRENT_VERSION=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) FROM plan_versions WHERE project_id='$SAFE_PROJECT_ID' AND plan_name='$SAFE_PLAN_NAME'")
NEW_VERSION=$((CURRENT_VERSION + 1))

# Get git commit hash if in repo
GIT_HASH=""
PLAN_FOLDER="${CLAUDE_HOME}/plans/${PROJECT_ID}"
if [[ -d "${CLAUDE_HOME}/.git" ]]; then
	cd "$CLAUDE_HOME"
	GIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "")
fi

# Build SQL values
TASKS_BEFORE_SQL="${TASKS_BEFORE:-NULL}"
TASKS_AFTER_SQL="${TASKS_AFTER:-NULL}"

# Escape remaining string variables for SQL
SAFE_CHANGE_TYPE=$(sql_escape "$CHANGE_TYPE")
REASON_ESC=$(sql_escape "$REASON")
DIFF_ESC=$(sql_escape "$DIFF_SUMMARY")
SAFE_GIT_HASH=$(sql_escape "$GIT_HASH")

# Insert version record
sqlite3 "$DB_FILE" <<EOF
INSERT INTO plan_versions (
    project_id,
    plan_name,
    version,
    change_type,
    change_reason,
    tasks_before,
    tasks_after,
    diff_summary,
    git_commit_hash,
    created_at
) VALUES (
    '$SAFE_PROJECT_ID',
    '$SAFE_PLAN_NAME',
    $NEW_VERSION,
    '$SAFE_CHANGE_TYPE',
    $([ -n "$REASON" ] && echo "'$REASON_ESC'" || echo "NULL"),
    $TASKS_BEFORE_SQL,
    $TASKS_AFTER_SQL,
    $([ -n "$DIFF_SUMMARY" ] && echo "'$DIFF_ESC'" || echo "NULL"),
    $([ -n "$GIT_HASH" ] && echo "'$SAFE_GIT_HASH'" || echo "NULL"),
    '$TIMESTAMP'
);
EOF

# Also update plans table status if needed
if [[ "$CHANGE_TYPE" == "created" ]]; then
	PLAN_FILE="${PLAN_FOLDER}/${PLAN_NAME}.md"
	SAFE_PLAN_FILE=$(sql_escape "$PLAN_FILE")
	sqlite3 "$DB_FILE" <<EOF
INSERT INTO plans (project_id, plan_name, plan_file, status, tasks_total, created_at)
VALUES ('$SAFE_PROJECT_ID', '$SAFE_PLAN_NAME', '$SAFE_PLAN_FILE', 'active', ${TASKS_AFTER:-0}, '$TIMESTAMP')
ON CONFLICT(project_id, plan_name) DO UPDATE SET
    status = 'active',
    tasks_total = ${TASKS_AFTER:-tasks_total};
EOF
elif [[ "$CHANGE_TYPE" == "completed" ]]; then
	sqlite3 "$DB_FILE" <<EOF
UPDATE plans SET status = 'completed', completed_at = '$TIMESTAMP', tasks_done = tasks_total
WHERE project_id = '$SAFE_PROJECT_ID' AND plan_name = '$SAFE_PLAN_NAME';
EOF
fi

# Auto-commit to git if configured
if [[ -d "${CLAUDE_HOME}/.git" && -n "$GIT_HASH" ]]; then
	cd "$CLAUDE_HOME"
	if [[ -n $(git status --porcelain "plans/${PROJECT_ID}/" 2>/dev/null) ]]; then
		git add "plans/${PROJECT_ID}/" 2>/dev/null || true
		git commit -m "plan(${PROJECT_ID}): ${CHANGE_TYPE} - ${PLAN_NAME} v${NEW_VERSION}" \
			-m "${REASON:-No reason provided}" \
			-m "🤖 Generated with [Claude Code](https://claude.com/claude-code)" 2>/dev/null || true
		NEW_GIT_HASH=$(git rev-parse HEAD)
		sqlite3 "$DB_FILE" "UPDATE plan_versions SET git_commit_hash='$NEW_GIT_HASH' WHERE project_id='$SAFE_PROJECT_ID' AND plan_name='$SAFE_PLAN_NAME' AND version=$NEW_VERSION"
	fi
fi

# Output result
jq -n \
	--arg project "$PROJECT_ID" \
	--arg plan "$PLAN_NAME" \
	--argjson version "$NEW_VERSION" \
	--arg type "$CHANGE_TYPE" \
	--arg reason "$REASON" \
	--arg git "$GIT_HASH" \
	'{
        "status": "success",
        "project_id": $project,
        "plan_name": $plan,
        "version": $version,
        "change_type": $type,
        "reason": (if $reason != "" then $reason else null end),
        "git_commit": (if $git != "" then $git else null end)
    }'
