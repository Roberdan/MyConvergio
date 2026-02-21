#!/bin/bash
# thor-audit-log.sh - Persist Thor validation results to audit log
# Usage: thor-audit-log.sh <plan_id> <task_id> <wave_id> <gates_passed> <gates_failed> <validated_by> <duration_ms> <confidence_score>
# Version: 1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../data"
AUDIT_LOG="$DATA_DIR/thor-audit.jsonl"

# Parse arguments
PLAN_ID="${1:?plan_id required}"
TASK_ID="${2:?task_id required}"
WAVE_ID="${3:?wave_id required}"
GATES_PASSED="${4:-[]}"
GATES_FAILED="${5:-[]}"
VALIDATED_BY="${6:-thor}"
DURATION_MS="${7:-0}"
CONFIDENCE_SCORE="${8:-0.0}"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Generate ISO 8601 timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build JSON line (compact, no newlines)
JSON_LINE=$(cat <<EOF
{"timestamp":"$TIMESTAMP","plan_id":$PLAN_ID,"task_id":"$TASK_ID","wave_id":"$WAVE_ID","gates_passed":$GATES_PASSED,"gates_failed":$GATES_FAILED,"validated_by":"$VALIDATED_BY","duration_ms":$DURATION_MS,"confidence_score":$CONFIDENCE_SCORE}
EOF
)

# Atomic append using flock
# Use temp file + mv for atomicity if flock not available
if command -v flock >/dev/null 2>&1; then
	# Use flock for locking
	(
		flock -x 200
		echo "$JSON_LINE" >>"$AUDIT_LOG"
	) 200>"$AUDIT_LOG.lock"
else
	# Fallback: temp file + mv (less atomic but better than nothing)
	TEMP_FILE="$AUDIT_LOG.tmp.$$"
	echo "$JSON_LINE" >"$TEMP_FILE"
	cat "$TEMP_FILE" >>"$AUDIT_LOG"
	rm -f "$TEMP_FILE"
fi

exit 0
