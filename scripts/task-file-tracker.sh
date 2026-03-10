#!/usr/bin/env bash
# task-file-tracker.sh v1.0.0 — Track files modified by each task
# Survives compaction (writes to SQLite DB, not context).
# Called by PostToolUse hook after Edit/Write, or manually.
set -euo pipefail

DB_PATH="${DB_PATH:-$HOME/.claude/data/dashboard.db}"
USAGE="Usage: task-file-tracker.sh <command> [args]
Commands:
  track <task_db_id> <file_path> <action>  Record file modification
  list <task_db_id>                         List files for a task
  list-plan <plan_id>                       List all files for a plan
  overlap <plan_id>                         Detect file overlap between tasks
  clean <task_db_id>                        Remove tracking for a task"

cmd="${1:-}"
[ -z "$cmd" ] && echo "$USAGE" && exit 1

ensure_table() {
  sqlite3 "$DB_PATH" "CREATE TABLE IF NOT EXISTS task_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    action TEXT NOT NULL DEFAULT 'edit',
    recorded_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(task_id, file_path)
  );"
}

case "$cmd" in
  track)
    TASK_ID="${2:?task_db_id required}"
    FILE_PATH="${3:?file_path required}"
    ACTION="${4:-edit}"
    ensure_table
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO task_files (task_id, file_path, action)
      VALUES ($TASK_ID, '$FILE_PATH', '$ACTION');"
    echo "Tracked: task=$TASK_ID file=$FILE_PATH action=$ACTION"
    ;;

  list)
    TASK_ID="${2:?task_db_id required}"
    ensure_table
    sqlite3 -column -header "$DB_PATH" \
      "SELECT file_path, action, recorded_at FROM task_files WHERE task_id = $TASK_ID ORDER BY file_path;"
    ;;

  list-plan)
    PLAN_ID="${2:?plan_id required}"
    ensure_table
    sqlite3 -column -header "$DB_PATH" \
      "SELECT t.task_id, t.title, tf.file_path, tf.action
       FROM task_files tf
       JOIN tasks t ON tf.task_id = t.id
       WHERE t.plan_id = $PLAN_ID
       ORDER BY t.task_id, tf.file_path;"
    ;;

  overlap)
    PLAN_ID="${2:?plan_id required}"
    ensure_table
    echo "=== File Overlap Detection (Plan $PLAN_ID) ==="
    OVERLAPS=$(sqlite3 "$DB_PATH" \
      "SELECT tf.file_path, GROUP_CONCAT(t.task_id, ', ') as tasks, COUNT(DISTINCT tf.task_id) as task_count
       FROM task_files tf
       JOIN tasks t ON tf.task_id = t.id
       WHERE t.plan_id = $PLAN_ID
       GROUP BY tf.file_path
       HAVING COUNT(DISTINCT tf.task_id) > 1
       ORDER BY task_count DESC;" 2>/dev/null)
    if [ -z "$OVERLAPS" ]; then
      echo "No file overlaps detected."
    else
      echo "WARNING: Files touched by multiple tasks:"
      echo "$OVERLAPS" | while IFS='|' read -r file tasks count; do
        echo "  $file — $count tasks: [$tasks]"
      done
      echo ""
      echo "These files WILL conflict at merge. Serialize affected tasks."
    fi
    ;;

  clean)
    TASK_ID="${2:?task_db_id required}"
    ensure_table
    COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM task_files WHERE task_id = $TASK_ID;")
    sqlite3 "$DB_PATH" "DELETE FROM task_files WHERE task_id = $TASK_ID;"
    echo "Cleaned $COUNT file records for task $TASK_ID"
    ;;

  *)
    echo "$USAGE"
    exit 1
    ;;
esac
