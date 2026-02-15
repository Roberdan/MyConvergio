#!/bin/bash
# Planner Init - Single-call project context bootstrap
# Returns JSON with everything the planner needs in ONE call
# Usage: planner-init.sh [project_path]

# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${HOME}/.claude/data/dashboard.db"

PROJECT_PATH="${1:-$(pwd)}"
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

# Derive project ID from folder name (same logic as register-project.sh)
FOLDER_NAME=$(basename "$PROJECT_PATH")
PROJECT_ID=$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

# SQL escape helper
sql_escape() { echo "${1//\'/\'\'}"; }
SAFE_PROJECT_ID=$(sql_escape "$PROJECT_ID")

# Auto-register if not in DB
PROJECT_EXISTS=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM projects WHERE id='$SAFE_PROJECT_ID';" 2>/dev/null || echo "0")
if [[ "$PROJECT_EXISTS" == "0" ]]; then
	"$SCRIPT_DIR/register-project.sh" "$PROJECT_PATH" >/dev/null 2>&1 || true
fi

# Git info
GIT_BRANCH=$(cd "$PROJECT_PATH" && git branch --show-current 2>/dev/null || echo "none")
GIT_REMOTE=$(cd "$PROJECT_PATH" && git remote get-url origin 2>/dev/null || echo "")

# Combined DB query: project name + active plans + recent plans
PLAN_DATA=$(sqlite3 -json "$DB_FILE" "
    SELECT
        (SELECT COALESCE(name, '') FROM projects WHERE id='$SAFE_PROJECT_ID') as project_name,
        (SELECT COALESCE(json_group_array(json_object(
            'id', id, 'name', name, 'status', status,
            'progress', tasks_done || '/' || tasks_total,
            'worktree_path', COALESCE(worktree_path, '')
        )), '[]') FROM (
            SELECT * FROM plans
            WHERE project_id='$SAFE_PROJECT_ID' AND status IN ('todo','doing')
            ORDER BY id DESC LIMIT 5
        )) as active_plans,
        (SELECT COALESCE(json_group_array(json_object(
            'id', id, 'name', name,
            'completed_at', COALESCE(completed_at, '')
        )), '[]') FROM (
            SELECT * FROM plans
            WHERE project_id='$SAFE_PROJECT_ID' AND status='done'
            ORDER BY completed_at DESC LIMIT 3
        )) as recent_plans
;" 2>/dev/null || echo '[{}]')

PROJECT_NAME=$(echo "$PLAN_DATA" | jq -r '.[0].project_name // ""' 2>/dev/null)
[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME="$FOLDER_NAME"
ACTIVE_PLANS=$(echo "$PLAN_DATA" | jq -r '.[0].active_plans // "[]"' 2>/dev/null || echo "[]")
RECENT_PLANS=$(echo "$PLAN_DATA" | jq -r '.[0].recent_plans // "[]"' 2>/dev/null || echo "[]")

# Worktrees
WORKTREES="[]"
if cd "$PROJECT_PATH" && git rev-parse --git-dir >/dev/null 2>&1; then
	WORKTREES=$(git worktree list --porcelain 2>/dev/null |
		grep "^worktree " | sed 's/^worktree //' |
		jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
fi

# Project structure checks
HAS_ADR=$([[ -d "$PROJECT_PATH/docs/adr" ]] && echo "true" || echo "false")
HAS_CHANGELOG=$([[ -f "$PROJECT_PATH/CHANGELOG.md" ]] && echo "true" || echo "false")

# Prompt files (avoid pipefail double-output: ls fails + jq already emitted [])
PROMPT_FILES=$(ls "$PROJECT_PATH/.copilot-tracking/prompt-"*.md 2>/dev/null) || PROMPT_FILES=""
if [[ -n "$PROMPT_FILES" ]]; then
	PROMPT_FILES=$(echo "$PROMPT_FILES" | jq -R -s 'split("\n") | map(select(length > 0))')
else
	PROMPT_FILES="[]"
fi

# Detect test framework
FRAMEWORK="unknown"
if [[ -f "$PROJECT_PATH/package.json" ]]; then
	if grep -q '"vitest"' "$PROJECT_PATH/package.json" 2>/dev/null; then
		FRAMEWORK="vitest"
	elif grep -q '"jest"' "$PROJECT_PATH/package.json" 2>/dev/null; then
		FRAMEWORK="jest"
	elif grep -q '"playwright"' "$PROJECT_PATH/package.json" 2>/dev/null; then
		FRAMEWORK="playwright"
	else
		FRAMEWORK="node"
	fi
elif [[ -f "$PROJECT_PATH/pyproject.toml" ]]; then
	FRAMEWORK="pytest"
elif [[ -f "$PROJECT_PATH/Cargo.toml" ]]; then
	FRAMEWORK="cargo"
fi

# Plan folder (ensure exists)
PLAN_FOLDER="${HOME}/.claude/plans/${PROJECT_ID}"
mkdir -p "$PLAN_FOLDER"

# Output JSON
jq -n \
	--arg pid "$PROJECT_ID" \
	--arg pname "$PROJECT_NAME" \
	--arg path "$PROJECT_PATH" \
	--arg branch "$GIT_BRANCH" \
	--arg remote "$GIT_REMOTE" \
	--arg plan_folder "$PLAN_FOLDER" \
	--argjson active "$ACTIVE_PLANS" \
	--argjson recent "$RECENT_PLANS" \
	--argjson worktrees "$WORKTREES" \
	--argjson has_adr "$HAS_ADR" \
	--argjson has_changelog "$HAS_CHANGELOG" \
	--argjson prompts "$PROMPT_FILES" \
	--arg fw "$FRAMEWORK" \
	'{
        project_id: $pid,
        project_name: $pname,
        path: $path,
        branch: $branch,
        remote: $remote,
        plan_folder: $plan_folder,
        active_plans: $active,
        recent_plans: $recent,
        worktrees: $worktrees,
        has_adr: $has_adr,
        has_changelog: $has_changelog,
        prompt_files: $prompts,
        framework: $fw
    }'
