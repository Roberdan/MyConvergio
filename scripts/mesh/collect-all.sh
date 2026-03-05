#!/bin/bash
set -euo pipefail
# Master Collector - Runs all collectors and merges output into plan.json
# Usage: ./collect-all.sh [project_path] [--update-plan]
# Output: Combined JSON to stdout, optionally updates plan.json

# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="${1:-.}"
LIMIT="${LIMIT:-150}"
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

# Run collectors in parallel
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/collect-all-XXXXXX")
trap "rm -rf '$tmpdir'" EXIT INT TERM

run_git >"$tmpdir/git.json" 2>/dev/null &
pid_git=$!
run_github >"$tmpdir/github.json" 2>/dev/null &
pid_github=$!
run_debt >"$tmpdir/debt.json" 2>/dev/null &
pid_debt=$!
run_quality >"$tmpdir/quality.json" 2>/dev/null &
pid_quality=$!

wait "$pid_git" "$pid_github" "$pid_debt" "$pid_quality" 2>/dev/null || true

GIT_OUTPUT=$(cat "$tmpdir/git.json" 2>/dev/null || echo '{}')
GITHUB_OUTPUT=$(cat "$tmpdir/github.json" 2>/dev/null || echo '{}')
DEBT_OUTPUT=$(cat "$tmpdir/debt.json" 2>/dev/null || echo '{}')
QUALITY_OUTPUT=$(cat "$tmpdir/quality.json" 2>/dev/null || echo '{}')

log_info "Collectors completed"

# Build collector status
GIT_STATUS=$(echo "$GIT_OUTPUT" | jq '{lastRun: .timestamp, status: .status}' 2>/dev/null) || GIT_STATUS='{"status":"error"}'
GITHUB_STATUS=$(echo "$GITHUB_OUTPUT" | jq '{lastRun: .timestamp, status: .status}' 2>/dev/null) || GITHUB_STATUS='{"status":"error"}'
DEBT_STATUS=$(echo "$DEBT_OUTPUT" | jq '{lastRun: .timestamp, status: .status}' 2>/dev/null) || DEBT_STATUS='{"status":"error"}'
QUALITY_STATUS=$(echo "$QUALITY_OUTPUT" | jq '{lastRun: .timestamp, status: .status}' 2>/dev/null) || QUALITY_STATUS='{"status":"error"}'

COLLECTORS_STATUS=$(
	jq -n \
		--argjson git "$GIT_STATUS" \
		--argjson github "$GITHUB_STATUS" \
		--argjson debt "$DEBT_STATUS" \
		--argjson quality "$QUALITY_STATUS" \
		'{git: $git, github: $github, debt: $debt, quality: $quality}'
)

# Extract data sections
GIT_DATA=$(echo "$GIT_OUTPUT" | jq '.data // {}' 2>/dev/null) || GIT_DATA='{}'
GITHUB_DATA=$(echo "$GITHUB_OUTPUT" | jq '.data // {}' 2>/dev/null) || GITHUB_DATA='{}'
DEBT_DATA=$(echo "$DEBT_OUTPUT" | jq '.data // {}' 2>/dev/null) || DEBT_DATA='{}'
QUALITY_DATA=$(echo "$QUALITY_OUTPUT" | jq '.data // {}' 2>/dev/null) || QUALITY_DATA='{}'

# Build combined output
COMBINED=$(
	jq -n \
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

	echo "$UPDATED" >"$TARGET"
	log_info "Plan updated successfully"
	echo "$UPDATED"
else
	echo "$COMBINED"
fi
