#!/bin/bash
# Thor Queue Monitor Script
# Monitors the validation queue and shows pending requests
#
# Usage: ./scripts/thor-monitor.sh [--watch]
#
# Copyright (c) 2025 Convergio.io
# Licensed under CC BY-NC-SA 4.0

QUEUE_DIR="/tmp/thor-queue"

show_status() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║           THOR QUEUE MONITOR - $(date +%H:%M:%S)                  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""

    # Check if queue exists
    if [ ! -d "${QUEUE_DIR}" ]; then
        echo "ERROR: Queue not initialized. Run thor-queue-setup.sh"
        return 1
    fi

    # Count requests
    PENDING=$(ls -1 "${QUEUE_DIR}/requests/" 2>/dev/null | wc -l | tr -d ' ')
    RESPONDED=$(ls -1 "${QUEUE_DIR}/responses/" 2>/dev/null | wc -l | tr -d ' ')

    echo "QUEUE STATUS"
    echo "════════════"
    echo "  Pending requests:  ${PENDING}"
    echo "  Responses ready:   ${RESPONDED}"
    echo ""

    # Show pending requests
    if [ "${PENDING}" -gt 0 ]; then
        echo "PENDING REQUESTS"
        echo "════════════════"
        for req in "${QUEUE_DIR}/requests/"*.json; do
            if [ -f "$req" ]; then
                REQ_ID=$(basename "$req" .json)
                WORKER=$(grep -o '"worker_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$req" 2>/dev/null | head -1 | cut -d'"' -f4)
                TASK=$(grep -o '"reference"[[:space:]]*:[[:space:]]*"[^"]*"' "$req" 2>/dev/null | head -1 | cut -d'"' -f4)
                echo "  ⏳ ${REQ_ID:0:8}... | ${WORKER:-unknown} | ${TASK:-unknown}"
            fi
        done
        echo ""
    fi

    # Show recent audit entries
    echo "RECENT VALIDATIONS (last 10)"
    echo "════════════════════════════"
    if [ -f "${QUEUE_DIR}/audit.jsonl" ]; then
        tail -10 "${QUEUE_DIR}/audit.jsonl" | while read -r line; do
            STATUS=$(echo "$line" | grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
            WORKER=$(echo "$line" | grep -o '"worker"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
            TASK=$(echo "$line" | grep -o '"task"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)

            case "${STATUS}" in
                "APPROVED") ICON="✅" ;;
                "REJECTED") ICON="❌" ;;
                "CHALLENGED") ICON="🔥" ;;
                "ESCALATED") ICON="🚨" ;;
                *) ICON="📋" ;;
            esac

            echo "  ${ICON} ${WORKER:-sys} | ${TASK:-event} | ${STATUS:-info}"
        done
    else
        echo "  No validations yet"
    fi
    echo ""

    # Show retry counts
    if [ -f "${QUEUE_DIR}/state/retry-counts.json" ]; then
        RETRIES=$(cat "${QUEUE_DIR}/state/retry-counts.json")
        if [ "$RETRIES" != "{}" ]; then
            echo "RETRY COUNTS"
            echo "════════════"
            echo "$RETRIES" | tr ',' '\n' | tr -d '{}' | while read -r entry; do
                if [ -n "$entry" ]; then
                    echo "  ⚠️  $entry"
                fi
            done
            echo ""
        fi
    fi
}

# Main
if [ "$1" == "--watch" ]; then
    while true; do
        show_status
        echo "Refreshing every 5s... (Ctrl+C to stop)"
        sleep 5
    done
else
    show_status
fi
