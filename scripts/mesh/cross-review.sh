#!/bin/bash
# cross-review.sh - Gate 10: Independent cross-review of wave deliverables
# Launches fresh antagonistic review for cross-file consistency.
# Usage: cross-review.sh <plan_id> <wave_db_id> [--provider copilot|claude]
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$HOME/.claude/data/dashboard.db"
REPORT_DIR="$HOME/.claude/data/cross-reviews"

if [[ $# -lt 2 ]]; then
	echo "Usage: cross-review.sh <plan_id> <wave_db_id> [--provider copilot|claude]" >&2
	exit 1
fi

PLAN_ID="$1"
WAVE_DB_ID="$2"
shift 2

PROVIDER="copilot"
while [[ $# -gt 0 ]]; do
	case "$1" in
	--provider)
		PROVIDER="${2:-copilot}"
		shift 2
		;;
	*) shift ;;
	esac
done

WAVE_ID=$(sqlite3 "$DB_FILE" \
	"SELECT wave_id FROM waves WHERE id = $WAVE_DB_ID;" 2>/dev/null || echo "unknown")

WORKTREE=$(sqlite3 "$DB_FILE" \
	"SELECT worktree_path FROM waves WHERE id = $WAVE_DB_ID;" 2>/dev/null || echo "")
if [[ -z "$WORKTREE" ]]; then
	WORKTREE=$(sqlite3 "$DB_FILE" \
		"SELECT worktree_path FROM plans WHERE id = $PLAN_ID;" 2>/dev/null || echo "")
fi
if [[ -z "$WORKTREE" || ! -d "$WORKTREE" ]]; then
	echo "ERROR: No worktree for plan $PLAN_ID wave $WAVE_DB_ID" >&2
	exit 1
fi

CHANGED_FILES=$(git -C "$WORKTREE" diff --name-only main...HEAD 2>/dev/null ||
	git -C "$WORKTREE" diff --name-only HEAD~5...HEAD 2>/dev/null || echo "")
if [[ -z "$CHANGED_FILES" ]]; then
	echo "INFO: No changed files — skipping cross-review" >&2
	exit 0
fi

TASK_CONTEXT=$(sqlite3 "$DB_FILE" \
	"SELECT task_id || ': ' || title FROM tasks WHERE wave_id_fk = $WAVE_DB_ID;" 2>/dev/null || echo "")

PROMPT="You are a CRITICAL REVIEWER. Find problems, not confirm success.

Review Wave $WAVE_ID of Plan $PLAN_ID. Changed files:
$CHANGED_FILES

Tasks completed:
$TASK_CONTEXT

Check:
1. Cross-file consistency: versions, counts, names must match across ALL files
2. Content accuracy: verify claims against actual source files
3. Link integrity: every internal markdown reference must resolve
4. Line limits: max 250 lines per file
5. Requirement coverage: each task must be verifiably fulfilled
6. No TODO, FIXME, or incomplete sections

For each issue:
CRITICAL: [file:line] description — blocks merge
WARNING: [file:line] description — should fix
INFO: [file:line] description — minor

End with exactly: VERDICT: PASS or VERDICT: FAIL"

mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/plan-${PLAN_ID}-wave-${WAVE_ID}.md"
REVIEW_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')
echo "[cross-review] Gate 10: provider=$PROVIDER wave=$WAVE_ID files=$FILE_COUNT" >&2

REVIEW_OUTPUT=""
if [[ "$PROVIDER" == "copilot" ]] && command -v copilot >/dev/null 2>&1; then
	REVIEW_OUTPUT=$(cd "$WORKTREE" && copilot --yolo --model claude-opus-4.6 -p "$PROMPT" 2>/dev/null) || true
elif command -v claude >/dev/null 2>&1; then
	REVIEW_OUTPUT=$(cd "$WORKTREE" && claude -p "$PROMPT" --output-format text 2>/dev/null) || true
else
	echo "WARN: No review provider available — skipping Gate 10" >&2
	exit 0
fi

if [[ -z "$REVIEW_OUTPUT" ]]; then
	echo "WARN: Empty review output — treating as UNKNOWN" >&2
	VERDICT="UNKNOWN"
	CRITICAL_COUNT=0
else
	VERDICT="UNKNOWN"
	if echo "$REVIEW_OUTPUT" | grep -qi "VERDICT:.*PASS"; then
		VERDICT="PASS"
	elif echo "$REVIEW_OUTPUT" | grep -qi "VERDICT:.*FAIL"; then
		VERDICT="FAIL"
	fi
	CRITICAL_COUNT=$(echo "$REVIEW_OUTPUT" | grep -ci "^CRITICAL:" 2>/dev/null) || CRITICAL_COUNT=0
fi

cat >"$REPORT_FILE" <<EOF
# Cross-Review: Plan $PLAN_ID Wave $WAVE_ID

| Field | Value |
|-------|-------|
| Provider | $PROVIDER |
| Timestamp | $REVIEW_TS |
| Verdict | $VERDICT |
| Critical | $CRITICAL_COUNT |

## Output

$REVIEW_OUTPUT
EOF

echo "[cross-review] Verdict: $VERDICT (${CRITICAL_COUNT} critical) — report: $REPORT_FILE" >&2

if [[ "$VERDICT" == "FAIL" || "$CRITICAL_COUNT" -gt 0 ]]; then
	exit 1
fi
exit 0
