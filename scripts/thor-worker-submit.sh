#!/bin/bash
# Thor Worker Submit Script
# Submits a validation request to Thor and waits for response
#
# Usage: ./scripts/thor-worker-submit.sh <worker_id> <task_ref> <claim>
#
# Example:
#   ./scripts/thor-worker-submit.sh "Claude-2" "Phase2-Task3" "JWT auth implemented"
#
# Copyright (c) 2025 Convergio.io
# Licensed under CC BY-NC-SA 4.0

set -e

QUEUE_DIR="/tmp/thor-queue"
TIMEOUT=300  # 5 minutes max wait

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <worker_id> <task_ref> <claim>"
    echo "Example: $0 'Claude-2' 'Phase2-Task3' 'JWT auth implemented'"
    exit 1
fi

WORKER_ID="$1"
TASK_REF="$2"
CLAIM="$3"

# Check queue exists
if [ ! -d "${QUEUE_DIR}" ]; then
    echo "ERROR: Thor queue not initialized. Run thor-queue-setup.sh first."
    exit 1
fi

# Generate request ID
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "╔══════════════════════════════════════════════════════════╗"
echo "║           THOR VALIDATION REQUEST                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Request ID: ${REQUEST_ID}"
echo "Worker: ${WORKER_ID}"
echo "Task: ${TASK_REF}"
echo ""

# Gather evidence automatically
echo "Gathering evidence..."

GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "not a git repo")
GIT_STATUS=$(git status --short 2>/dev/null | tr '\n' ' ' | sed 's/"/\\"/g' || echo "not a git repo")
GIT_LOG=$(git log -1 --oneline 2>/dev/null | sed 's/"/\\"/g' || echo "no commits")

# Escape claim for JSON (handle quotes and newlines)
CLAIM_ESCAPED=$(echo "${CLAIM}" | sed 's/"/\\"/g' | tr '\n' ' ')

# Create request JSON
REQUEST_FILE="${QUEUE_DIR}/requests/${REQUEST_ID}.json"

cat > "${REQUEST_FILE}" <<EOF
{
  "request_id": "${REQUEST_ID}",
  "timestamp": "${TIMESTAMP}",
  "worker_id": "${WORKER_ID}",
  "worker_title": "${WORKER_ID}",
  "request_type": "task_validation",
  "task": {
    "reference": "${TASK_REF}",
    "original_instructions": "See plan file for details"
  },
  "claim": {
    "summary": "${CLAIM_ESCAPED}"
  },
  "evidence": {
    "git_branch": "${GIT_BRANCH}",
    "git_status": "${GIT_STATUS}",
    "git_log_last": "${GIT_LOG}"
  },
  "self_check": {
    "submitted_by_worker": true
  }
}
EOF

echo "✓ Request submitted: ${REQUEST_FILE}"
echo ""

# Notify Thor via Kitty if available
if command -v kitty &> /dev/null; then
    kitty @ send-text --match title:Thor-QA "[VALIDATION REQUEST] ${REQUEST_ID} from ${WORKER_ID} - Task: ${TASK_REF}" 2>/dev/null && \
    kitty @ send-key --match title:Thor-QA Return 2>/dev/null || true
fi

# Wait for response
RESPONSE_FILE="${QUEUE_DIR}/responses/${REQUEST_ID}.json"
echo "Waiting for Thor's response..."
echo "(Timeout: ${TIMEOUT}s)"
echo ""

WAITED=0
while [ ! -f "${RESPONSE_FILE}" ]; do
    sleep 5
    WAITED=$((WAITED + 5))
    echo -ne "\r  Waiting... ${WAITED}s"

    if [ $WAITED -ge $TIMEOUT ]; then
        echo ""
        echo ""
        echo "ERROR: Thor did not respond within ${TIMEOUT}s"
        echo "Check if Thor is running in a Kitty tab."
        exit 1
    fi
done

echo ""
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           THOR RESPONSE RECEIVED                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Parse and display response
STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "${RESPONSE_FILE}" | head -1 | cut -d'"' -f4)

echo "Status: ${STATUS}"
echo ""

case "${STATUS}" in
    "APPROVED")
        echo "✅ APPROVED - You may proceed to the next task."
        ;;
    "REJECTED")
        echo "❌ REJECTED - Fix all issues and resubmit."
        echo ""
        echo "Issues found:"
        grep -o '"issues"[[:space:]]*:[[:space:]]*\[[^]]*\]' "${RESPONSE_FILE}" | head -1 || true
        ;;
    "CHALLENGED")
        echo "🔥 CHALLENGED - Provide requested evidence."
        ;;
    "ESCALATED")
        echo "🚨 ESCALATED - STOP. Roberto must intervene."
        ;;
    *)
        echo "Unknown status. See response file for details."
        ;;
esac

echo ""
echo "Full response: ${RESPONSE_FILE}"
echo ""
