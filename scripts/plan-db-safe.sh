#!/bin/bash
# plan-db-safe.sh - Safe wrapper around plan-db.sh
# Pre-checks before allowing update-task to "done" status
# Usage: plan-db-safe.sh <any plan-db.sh args>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$HOME/.claude/data/dashboard.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

fail() {
	echo -e "${RED}[BLOCKED]${NC} $1" >&2
	exit 1
}
warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
ok() { echo -e "${GREEN}[OK]${NC} $1" >&2; }

# Check if this is an update-task <id> done call
is_done_transition() {
	[[ "${1:-}" == "update-task" ]] && [[ "${3:-}" == "done" ]]
}

# Pre-checks for marking task as done
pre_check_done() {
	local task_id="$1"

	# 1. Get task files from DB
	local files
	files=$(sqlite3 "$DB_FILE" \
		"SELECT json_extract(value, '$.files') FROM tasks, json_each(tasks.description)
     WHERE tasks.id = $task_id LIMIT 1;" 2>/dev/null || echo "")

	# Fallback: get files from task title/description pattern
	if [[ -z "$files" || "$files" == "null" ]]; then
		warn "No files metadata in DB for task $task_id (skipping file check)"
	else
		# Parse JSON array of files
		local file_list
		file_list=$(echo "$files" | jq -r '.[]?' 2>/dev/null || echo "")
		if [[ -n "$file_list" ]]; then
			local missing=0
			while IFS= read -r f; do
				[[ -z "$f" ]] && continue
				if [[ ! -f "$f" ]]; then
					fail "File '$f' listed in task but does not exist"
					missing=1
				fi
			done <<<"$file_list"
			[[ $missing -eq 1 ]] && return 1
			ok "All task files exist"
		fi
	fi

	# 2. Check for lint errors on staged/modified files
	if command -v npx >/dev/null 2>&1 && [[ -f "package.json" ]]; then
		local changed
		changed=$(git diff --name-only --diff-filter=ACMR 2>/dev/null | grep -E '\.(ts|tsx|js|jsx)$' || true)
		if [[ -n "$changed" ]]; then
			if ! echo "$changed" | xargs npx eslint --quiet --no-error-on-unmatched-pattern 2>/dev/null; then
				fail "Lint errors on modified files. Fix before marking done."
			fi
			ok "Lint check passed"
		fi
	fi

	# 3. Check no untracked test files
	local untracked_tests
	untracked_tests=$(git ls-files --others --exclude-standard 2>/dev/null |
		grep -E '\.(test|spec)\.(ts|tsx|js|jsx)$' || true)
	if [[ -n "$untracked_tests" ]]; then
		fail "Untracked test files found (git add them):\n$untracked_tests"
	fi

	ok "Pre-checks passed for task $task_id"
}

# Main
if is_done_transition "$@"; then
	pre_check_done "${2:?task_id required}"
fi

# Delegate to real plan-db.sh
exec "$SCRIPT_DIR/plan-db.sh" "$@"
