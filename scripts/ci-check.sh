#!/usr/bin/env bash
set -euo pipefail

# ci-check.sh - Compact GitHub CI status (token-efficient)
# Fetches job statuses + error extracts from failed jobs.
# Target: ~10-40 lines output. Designed for AI agent consumption.
#
# Usage:
#   ./scripts/ci-check.sh              # latest run on current branch
#   ./scripts/ci-check.sh <run-id>     # specific run
#   ./scripts/ci-check.sh --all        # latest run on any branch

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
MODE="${1:-}"
RUN_ID=""

# Resolve run ID
if [[ "$MODE" =~ ^[0-9]+$ ]]; then
  RUN_ID="$MODE"
elif [[ "$MODE" == "--all" ]]; then
  RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
else
  RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId \
    --jq '.[0].databaseId')
fi

if [[ -z "$RUN_ID" ]]; then
  echo "No CI runs found."
  exit 1
fi

# Fetch run metadata
RUN_JSON=$(gh run view "$RUN_ID" --json status,conclusion,headBranch,headSha,event,name,createdAt)
RUN_STATUS=$(echo "$RUN_JSON" | jq -r '.status')
RUN_CONCLUSION=$(echo "$RUN_JSON" | jq -r '.conclusion // "in_progress"')
RUN_BRANCH=$(echo "$RUN_JSON" | jq -r '.headBranch')
RUN_SHA=$(echo "$RUN_JSON" | jq -r '.headSha[:7]')
RUN_NAME=$(echo "$RUN_JSON" | jq -r '.name')

echo "=== GitHub CI: Run #$RUN_ID ==="
echo "$RUN_NAME | $RUN_BRANCH @ $RUN_SHA | $RUN_STATUS ($RUN_CONCLUSION)"
echo ""

# Fetch job statuses
JOBS_JSON=$(gh run view "$RUN_ID" --json jobs --jq '.jobs')
TOTAL_JOBS=$(echo "$JOBS_JSON" | jq 'length')
FAILED_JOBS=0
SKIPPED_JOBS=0

# Print job matrix
for i in $(seq 0 $((TOTAL_JOBS - 1))); do
  JOB_NAME=$(echo "$JOBS_JSON" | jq -r ".[$i].name")
  JOB_STATUS=$(echo "$JOBS_JSON" | jq -r ".[$i].status")
  JOB_CONCLUSION=$(echo "$JOBS_JSON" | jq -r ".[$i].conclusion // \"running\"")

  case "$JOB_CONCLUSION" in
    success)   echo "[PASS] $JOB_NAME" ;;
    failure)
      echo "[FAIL] $JOB_NAME"
      FAILED_JOBS=$((FAILED_JOBS + 1))
      ;;
    skipped)
      echo "[SKIP] $JOB_NAME"
      SKIPPED_JOBS=$((SKIPPED_JOBS + 1))
      ;;
    cancelled)  echo "[STOP] $JOB_NAME" ;;
    running)    echo "[ .. ] $JOB_NAME ($JOB_STATUS)" ;;
    *)          echo "[????] $JOB_NAME ($JOB_CONCLUSION)" ;;
  esac
done

echo ""

# If any jobs failed, extract error details
if [[ "$FAILED_JOBS" -gt 0 ]]; then
  echo "--- Failed job errors (deduplicated) ---"
  FAILED_LOG=$(gh run view "$RUN_ID" --log-failed 2>/dev/null || true)

  if [[ -n "$FAILED_LOG" ]]; then
    # Extract per-job errors: strip ANSI, timestamps, noise, dedup by message
    echo "$FAILED_LOG" | \
      perl -pe 's/\e\[[0-9;]*m//g' | \
      perl -pe 's/^[^\t]*\t[^\t]*\t//' | \
      perl -pe 's/\xef\xbb\xbf//g' | \
      sed 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:.]*Z //' | \
      sed 's/##\[group\].*//; s/##\[error\]/ERROR: /' | \
      grep -iE "error|FAIL|P2002|Unique constraint|MISSING_MESSAGE|timed out|AssertionError" | \
      grep -viE "Downloading|Setting up|Cache|Restore|Post job|Process completed|exit code|echo |##\[group\]" | \
      sed 's/^[[:space:]]*//' | \
      sed 's/"timestamp":"[^"]*",\{0,1\}//' | \
      sed 's/\[WebServer\] //g' | \
      sort -u | \
      head -20
  else
    echo "(no logs available yet - run may still be in progress)"
  fi

  echo ""
  echo "BLOCKED: $FAILED_JOBS job(s) failed"
  exit 1
elif [[ "$RUN_STATUS" == "in_progress" ]]; then
  echo "IN PROGRESS ($((TOTAL_JOBS - SKIPPED_JOBS)) jobs running)"
  exit 0
else
  echo "ALL GREEN ($TOTAL_JOBS jobs passed)"
  exit 0
fi
