#!/bin/bash
# Thor Queue Setup Script
# Initializes the validation queue for Thor-based quality gating
#
# Usage: ./scripts/thor-queue-setup.sh
#
# Copyright (c) 2025 Convergio.io
# Licensed under CC BY-NC-SA 4.0

set -e

QUEUE_DIR="/tmp/thor-queue"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║           THOR QUEUE INITIALIZATION                       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Create directory structure
echo "Creating queue directories..."
mkdir -p "${QUEUE_DIR}/requests"
mkdir -p "${QUEUE_DIR}/responses"
mkdir -p "${QUEUE_DIR}/state"

# Initialize state files
echo "Initializing state files..."
touch "${QUEUE_DIR}/audit.jsonl"
echo '{}' > "${QUEUE_DIR}/state/retry-counts.json"

# Set permissions (readable/writable by all - adjust as needed)
chmod -R 777 "${QUEUE_DIR}"

# Log initialization
INIT_LOG=$(cat <<EOF
{"event":"queue_initialized","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","host":"$(hostname)"}
EOF
)
echo "${INIT_LOG}" >> "${QUEUE_DIR}/audit.jsonl"

echo ""
echo "✓ Queue directories created:"
echo "  ${QUEUE_DIR}/requests/    - Workers submit here"
echo "  ${QUEUE_DIR}/responses/   - Thor responds here"
echo "  ${QUEUE_DIR}/state/       - State tracking"
echo "  ${QUEUE_DIR}/audit.jsonl  - Audit log"
echo ""
echo "✓ Thor Queue initialized successfully at $(date)"
echo ""
echo "Next steps:"
echo "  1. Start Thor in a dedicated Kitty tab: @thor-quality-assurance-guardian"
echo "  2. Workers can now submit validation requests"
echo ""
