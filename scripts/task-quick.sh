#!/bin/bash
# Quick Task Operations - Reduces token usage for common operations
# Usage: task-quick.sh <command> [args]
#
# Commands:
#   start <task_id>     - Mark task in_progress
#   done <task_id>      - Mark task done
#   status              - Show current task status
#   next                - Show next pending task

# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${HOME}/.claude/data/dashboard.db"

case "${1:-help}" in
    start)
        TASK_ID="${2:?task_id required}"
        "$SCRIPT_DIR/plan-db.sh" update-task "$TASK_ID" in_progress "Started via task-quick"
        sqlite3 "$DB_FILE" "SELECT task_id, title FROM tasks WHERE id = $TASK_ID;"
        ;;
    done)
        TASK_ID="${2:?task_id required}"
        NOTES="${3:-Completed via task-quick}"
        "$SCRIPT_DIR/plan-db.sh" update-task "$TASK_ID" done "$NOTES"
        sqlite3 "$DB_FILE" "SELECT task_id, title, status FROM tasks WHERE id = $TASK_ID;"
        ;;
    status)
        echo "=== In Progress ==="
        sqlite3 -column "$DB_FILE" "
            SELECT t.id, t.task_id, t.title, w.wave_id
            FROM tasks t JOIN waves w ON t.wave_id_fk = w.id
            WHERE t.status = 'in_progress' LIMIT 5;
        "
        ;;
    next)
        echo "=== Next Pending ==="
        sqlite3 -column "$DB_FILE" "
            SELECT t.id, t.task_id, t.title, w.wave_id, p.name as plan
            FROM tasks t
            JOIN waves w ON t.wave_id_fk = w.id
            JOIN plans p ON w.plan_id = p.id
            WHERE t.status = 'pending' AND p.status = 'doing'
            ORDER BY w.position, t.id LIMIT 3;
        "
        ;;
    *)
        echo "Usage: task-quick.sh <start|done|status|next> [args]"
        ;;
esac
