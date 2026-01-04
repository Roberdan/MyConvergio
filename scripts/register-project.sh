#!/bin/bash
# Register Project - Adds/updates a project in the centralized registry
# Usage: ./register-project.sh [project_path] [--name "Display Name"]
# Auto-detects: project_id (from folder), git remote, GitHub URL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"
REGISTRY_FILE="${CLAUDE_HOME}/plans/registry.json"
DB_FILE="${CLAUDE_HOME}/data/dashboard.db"

PROJECT_PATH="${1:-.}"
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
DISPLAY_NAME=""

# Parse args
shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --name) DISPLAY_NAME="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }

# Generate project_id from folder name (slugify)
FOLDER_NAME=$(basename "$PROJECT_PATH")
PROJECT_ID=$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

# Default display name
if [[ -z "$DISPLAY_NAME" ]]; then
    DISPLAY_NAME="$FOLDER_NAME"
fi

# Detect git info
GIT_REMOTE=""
GIT_BRANCH=""
GITHUB_URL=""
ICON_PATH=""

if [[ -d "${PROJECT_PATH}/.git" ]]; then
    cd "$PROJECT_PATH"
    GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

    # Extract GitHub URL from remote
    if [[ "$GIT_REMOTE" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        GITHUB_ORG="${BASH_REMATCH[1]}"
        GITHUB_REPO="${BASH_REMATCH[2]%.git}"
        GITHUB_URL="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}"
    fi
fi

# Detect icon from CLAUDE.md or auto-detect
cd "$PROJECT_PATH"
if [[ -f "CLAUDE.md" ]]; then
    ICON_PATH=$(grep -E "^icon:\s*" CLAUDE.md 2>/dev/null | sed 's/^icon:\s*//' | tr -d ' ' || echo "")
fi

# Auto-detect icon if not in CLAUDE.md
if [[ -z "$ICON_PATH" ]]; then
    for pattern in "public/logo"*.png "public/logo"*.svg "assets/icon"*.png ".claude/icon.png" "favicon".*; do
        # shellcheck disable=SC2086
        FOUND=$(ls $pattern 2>/dev/null | head -1 || echo "")
        if [[ -n "$FOUND" ]]; then
            ICON_PATH="$FOUND"
            break
        fi
    done
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create plans folder for this project if not exists
PLAN_FOLDER="${CLAUDE_HOME}/plans/${PROJECT_ID}"
mkdir -p "$PLAN_FOLDER"

# Check if project exists in registry
if jq -e ".projects[\"$PROJECT_ID\"]" "$REGISTRY_FILE" > /dev/null 2>&1; then
    log_info "Updating existing project: $PROJECT_ID"
    ACTION="updated"
else
    log_info "Registering new project: $PROJECT_ID"
    ACTION="registered"
fi

# Update registry.json
UPDATED_REGISTRY=$(jq --arg id "$PROJECT_ID" \
    --arg name "$DISPLAY_NAME" \
    --arg path "$PROJECT_PATH" \
    --arg remote "$GIT_REMOTE" \
    --arg branch "$GIT_BRANCH" \
    --arg github "$GITHUB_URL" \
    --arg icon "$ICON_PATH" \
    --arg ts "$TIMESTAMP" \
    '
    .projects[$id] = {
        "name": $name,
        "path": $path,
        "git_remote": $remote,
        "git_branch": $branch,
        "github_url": $github,
        "icon_path": $icon,
        "current_plan": (if .projects[$id] then .projects[$id].current_plan else null end),
        "last_active": $ts,
        "registered_at": (if .projects[$id] then .projects[$id].registered_at else $ts end)
    } | .meta.lastUpdated = $ts
    ' "$REGISTRY_FILE")

echo "$UPDATED_REGISTRY" > "$REGISTRY_FILE"

# Update SQLite database
if [[ -f "$DB_FILE" ]]; then
    sqlite3 "$DB_FILE" <<EOF
INSERT INTO projects (id, name, path, branch, github_url, icon_path, created_at, updated_at)
VALUES ('$PROJECT_ID', '$DISPLAY_NAME', '$PROJECT_PATH', '$GIT_BRANCH', '$GITHUB_URL', '$ICON_PATH', '$TIMESTAMP', '$TIMESTAMP')
ON CONFLICT(id) DO UPDATE SET
    name = excluded.name,
    path = excluded.path,
    branch = excluded.branch,
    github_url = excluded.github_url,
    icon_path = excluded.icon_path,
    updated_at = excluded.updated_at;
EOF
    log_info "Database updated"
fi

# Output result as JSON
jq -n \
    --arg action "$ACTION" \
    --arg id "$PROJECT_ID" \
    --arg name "$DISPLAY_NAME" \
    --arg path "$PROJECT_PATH" \
    --arg remote "$GIT_REMOTE" \
    --arg github "$GITHUB_URL" \
    --arg icon "$ICON_PATH" \
    --arg plan_folder "$PLAN_FOLDER" \
    '{
        "status": "success",
        "action": $action,
        "project": {
            "id": $id,
            "name": $name,
            "path": $path,
            "git_remote": $remote,
            "github_url": $github,
            "icon_path": $icon,
            "plan_folder": $plan_folder
        }
    }'

log_info "Project $ACTION: $PROJECT_ID"
log_info "Plans folder: $PLAN_FOLDER"
[[ -n "$GITHUB_URL" ]] && log_info "GitHub: $GITHUB_URL"
[[ -n "$ICON_PATH" ]] && log_info "Icon: $ICON_PATH"
