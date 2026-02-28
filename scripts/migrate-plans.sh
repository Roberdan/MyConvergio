#!/bin/bash
set -euo pipefail
# ARCHIVED: Migration already applied. Kept for reference only.
# This script should not be run again on existing databases.
#
# Migrate Plans - Import plans from a project to centralized kanban structure
# Usage: ./migrate-plans.sh <project_path> [--plan-name "PlanName"]

# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"
REGISTRY_FILE="${CLAUDE_HOME}/plans/registry.json"

PROJECT_PATH="${1:-.}"
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
PLAN_NAME=""

# Parse args
shift || true
while [[ $# -gt 0 ]]; do
	case $1 in
	--plan-name)
		PLAN_NAME="$2"
		shift 2
		;;
	*) shift ;;
	esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1" >&2; }

# Generate project_id from folder name
FOLDER_NAME=$(basename "$PROJECT_PATH")
PROJECT_ID=$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

log_step "Migrating plans from: $PROJECT_PATH"
log_info "Project ID: $PROJECT_ID"

# Step 1: Register project if not exists
if ! jq -e ".projects[\"$PROJECT_ID\"]" "$REGISTRY_FILE" >/dev/null 2>&1; then
	log_step "Registering project..."
	"$SCRIPT_DIR/register-project.sh" "$PROJECT_PATH" >/dev/null
fi

# Step 2: Create kanban structure
PLAN_FOLDER="${CLAUDE_HOME}/plans/${PROJECT_ID}"
mkdir -p "$PLAN_FOLDER"/{todo,doing,done}

# Step 3: Find and migrate plans
PLANS_DIR="${PROJECT_PATH}/docs/plans"
if [[ ! -d "$PLANS_DIR" ]]; then
	log_warn "No docs/plans/ folder found in project"
	exit 1
fi

MIGRATED=0

# Check for kanban structure in source
for STATUS in done doing todo; do
	SRC_DIR="${PLANS_DIR}/${STATUS}"
	if [[ -d "$SRC_DIR" ]]; then
		shopt -s nullglob
		for PLAN_FILE in "$SRC_DIR"/*.md "$SRC_DIR"/*.json; do
			[[ -f "$PLAN_FILE" ]] || continue
			BASENAME=$(basename "$PLAN_FILE")
			cp "$PLAN_FILE" "$PLAN_FOLDER/$STATUS/$BASENAME"
			log_info "Migrated: $STATUS/$BASENAME"
			((MIGRATED++))
		done
		shopt -u nullglob
	fi
done

# Migrate root-level plans (determine status from content or default to doing)
shopt -s nullglob
for PLAN_FILE in "$PLANS_DIR"/*.md "$PLANS_DIR"/*.json; do
	[[ -f "$PLAN_FILE" ]] || continue
	BASENAME=$(basename "$PLAN_FILE")

	# Skip README
	[[ "$BASENAME" == "README.md" ]] && continue

	# Determine target folder based on content
	if grep -qi "status.*completed\|TOTAL.*100%" "$PLAN_FILE" 2>/dev/null; then
		TARGET="done"
	elif grep -qi "status.*in.progress\|🔄\|DOING" "$PLAN_FILE" 2>/dev/null; then
		TARGET="doing"
	else
		TARGET="todo"
	fi

	cp "$PLAN_FILE" "$PLAN_FOLDER/$TARGET/$BASENAME"
	log_info "Migrated: $TARGET/$BASENAME"
	((MIGRATED++))
done
shopt -u nullglob

# Step 4: Create/update current.json
ACTIVE_PLAN=$(ls "$PLAN_FOLDER/doing/" 2>/dev/null | head -1 | sed 's/\.[^.]*$//' || echo "")

jq -n \
	--arg active "$ACTIVE_PLAN" \
	--arg updated "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
	'{
        "active_plan": (if $active == "" then null else $active end),
        "last_completed": null,
        "updated": $updated
    }' >"$PLAN_FOLDER/current.json"

# Step 5: Update registry with current plan
if [[ -n "$ACTIVE_PLAN" ]]; then
	UPDATED_REGISTRY=$(jq --arg id "$PROJECT_ID" --arg plan "$ACTIVE_PLAN" \
		'.projects[$id].current_plan = $plan' "$REGISTRY_FILE")
	echo "$UPDATED_REGISTRY" >"$REGISTRY_FILE"
fi

log_step "Migration complete: $MIGRATED plans migrated"
echo ""
echo "Structure:"
ls -la "$PLAN_FOLDER"/

jq -n \
	--arg project_id "$PROJECT_ID" \
	--argjson migrated "$MIGRATED" \
	--arg active "$ACTIVE_PLAN" \
	'{
        "status": "success",
        "project_id": $project_id,
        "plans_migrated": $migrated,
        "active_plan": (if $active == "" then null else $active end)
    }'
