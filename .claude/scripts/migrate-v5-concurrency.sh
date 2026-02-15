#!/bin/bash
# ARCHIVED: Migration already applied. Kept for reference only.
# This script should not be run again on existing databases.
#
# Migration v5: Add concurrency control tables
# Tables: file_locks, file_snapshots, merge_queue
# Idempotent: safe to run multiple times
# Version: 1.1.0
set -euo pipefail

DB_FILE="${HOME}/.claude/data/dashboard.db"

[[ ! -f "$DB_FILE" ]] && echo "DB not found at $DB_FILE" && exit 1

sqlite3 "$DB_FILE" <<'SQL'
-- File-level locking for concurrent agent work
CREATE TABLE IF NOT EXISTS file_locks (
    id INTEGER PRIMARY KEY,
    file_path TEXT NOT NULL UNIQUE,
    task_id TEXT,
    plan_id INTEGER,
    agent_name TEXT DEFAULT 'unknown',
    pid INTEGER NOT NULL,
    host TEXT NOT NULL,
    acquired_at DATETIME DEFAULT (datetime('now')),
    heartbeat_at DATETIME DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_file_locks_task ON file_locks(task_id);
CREATE INDEX IF NOT EXISTS idx_file_locks_plan ON file_locks(plan_id);

-- File hash snapshots for stale context detection
CREATE TABLE IF NOT EXISTS file_snapshots (
    id INTEGER PRIMARY KEY,
    task_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_hash TEXT NOT NULL,
    branch TEXT,
    snapshot_at DATETIME DEFAULT (datetime('now')),
    UNIQUE(task_id, file_path)
);

CREATE INDEX IF NOT EXISTS idx_snapshots_task ON file_snapshots(task_id);

-- Merge queue for sequential safe merging
CREATE TABLE IF NOT EXISTS merge_queue (
    id INTEGER PRIMARY KEY,
    branch TEXT NOT NULL UNIQUE,
    worktree_path TEXT,
    plan_id INTEGER,
    priority INTEGER DEFAULT 0,
    status TEXT CHECK(status IN ('queued','processing','done','failed','cancelled'))
        DEFAULT 'queued',
    queued_at DATETIME DEFAULT (datetime('now')),
    started_at DATETIME,
    completed_at DATETIME,
    result TEXT,
    error TEXT
);

CREATE INDEX IF NOT EXISTS idx_merge_queue_status ON merge_queue(status, priority DESC, id);
SQL

echo '{"migrated":"v5-concurrency","tables":["file_locks","file_snapshots","merge_queue"]}'
