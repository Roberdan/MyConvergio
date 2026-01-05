#!/bin/bash
# Master Collector - Runs all collectors and merges output into plan.json
# Usage: ./collect-all.sh [project_path] [--update-plan]
# Output: Combined JSON to stdout, optionally updates plan.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="${1:-.}"
UPDATE_PLAN=false

if [[ "${2:-}" == "--update-plan" ]]; then
    UPDATE_PLAN=true
fi

cd "$PROJECT_PATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Run collectors in parallel
log_info "Running collectors..."

GIT_OUTPUT=""
GITHUB_OUTPUT=""
TESTS_OUTPUT=""
DEBT_OUTPUT=""
QUALITY_OUTPUT=""

# Collector functions
run_git() {
    if [[ -x "$SCRIPT_DIR/collect-git.sh" ]]; then
        "$SCRIPT_DIR/collect-git.sh" "$PROJECT_PATH" 2>/dev/null || echo '{"collector":"git","status":"error"}'
    else
        echo '{"collector":"git","status":"skipped"}'
    fi
}

run_github() {
    if [[ -x "$SCRIPT_DIR/collect-github.sh" ]]; then
        "$SCRIPT_DIR/collect-github.sh" "$PROJECT_PATH" 2>/dev/null || echo '{"collector":"github","status":"error"}'
    else
        echo '{"collector":"github","status":"skipped"}'
    fi
}

run_tests() {
    if [[ -x "$SCRIPT_DIR/collect-tests.sh" ]]; then
        "$SCRIPT_DIR/collect-tests.sh" "$PROJECT_PATH" 2>/dev/null || echo '{"collector":"tests","status":"error"}'
    else
        echo '{"collector":"tests","status":"skipped"}'
    fi
}

run_debt() {
    if [[ -x "$SCRIPT_DIR/collect-debt.sh" ]]; then
        "$SCRIPT_DIR/collect-debt.sh" "$PROJECT_PATH" 2>/dev/null || echo '{"collector":"debt","status":"error"}'
    else
        echo '{"collector":"debt","status":"skipped"}'
    fi
}

run_quality() {
    if [[ -x "$SCRIPT_DIR/collect-quality.sh" ]]; then
        "$SCRIPT_DIR/collect-quality.sh" "$PROJECT_PATH" 2>/dev/null || echo '{"collector":"quality","status":"error"}'
    else
        echo '{"collector":"quality","status":"skipped"}'
    fi
}

# Run collectors (parallel where supported)
GIT_OUTPUT=$(run_git)
GITHUB_OUTPUT=$(run_github)
DEBT_OUTPUT=$(run_debt)
QUALITY_OUTPUT=$(run_quality)

log_info "Collectors completed"

# Build collector status
COLLECTORS_STATUS=$(jq -n \
    --argjson git "$(echo "$GIT_OUTPUT" | jq '{lastRun: .timestamp, status: .status}')" \
    --argjson github "$(echo "$GITHUB_OUTPUT" | jq '{lastRun: .timestamp, status: .status}')" \
    --argjson debt "$(echo "$DEBT_OUTPUT" | jq '{lastRun: .timestamp, status: .status}')" \
    --argjson quality "$(echo "$QUALITY_OUTPUT" | jq '{lastRun: .timestamp, status: .status}')" \
    '{git: $git, github: $github, debt: $debt, quality: $quality}'
)

# Extract data sections
GIT_DATA=$(echo "$GIT_OUTPUT" | jq '.data // {}')
GITHUB_DATA=$(echo "$GITHUB_OUTPUT" | jq '.data // {}')
DEBT_DATA=$(echo "$DEBT_OUTPUT" | jq '.data // {}')
QUALITY_DATA=$(echo "$QUALITY_OUTPUT" | jq '.data // {}')

# Build combined output
COMBINED=$(jq -n \
    --arg timestamp "$TIMESTAMP" \
    --argjson git "$GIT_DATA" \
    --argjson github "$GITHUB_DATA" \
    --argjson debt "$DEBT_DATA" \
    --argjson quality "$QUALITY_DATA" \
    --argjson collectors "$COLLECTORS_STATUS" \
    '{
        collectedAt: $timestamp,
        git: $git,
        github: $github,
        debt: $debt,
        quality: $quality,
        collectors: $collectors
    }'
)

# If --update-plan, merge into existing plan.json
if [[ "$UPDATE_PLAN" == true ]]; then
    PLAN_FILE="$PROJECT_PATH/plan.json"
    DASHBOARD_PLAN="$HOME/.claude/dashboard/plan.json"

    # Try project plan first, then dashboard
    if [[ -f "$PLAN_FILE" ]]; then
        TARGET="$PLAN_FILE"
    elif [[ -f "$DASHBOARD_PLAN" ]]; then
        TARGET="$DASHBOARD_PLAN"
    else
        log_error "No plan.json found to update"
        echo "$COMBINED"
        exit 0
    fi

    log_info "Updating $TARGET"

    # Merge collector data into plan
    UPDATED=$(jq --argjson collected "$COMBINED" '
        . + {
            git: (.git // {}) + $collected.git,
            debt: $collected.debt,
            quality: $collected.quality,
            collectors: $collected.collectors
        } | if $collected.github.pr then
            .github.pr = (.github.pr // {}) + $collected.github.pr
        else . end
    ' "$TARGET")

    echo "$UPDATED" > "$TARGET"
    log_info "Plan updated successfully"
    echo "$UPDATED"
else
    echo "$COMBINED"
fi
