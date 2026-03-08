#!/usr/bin/env python3
"""Migration 008: add GitHub tracking columns and tables."""

from __future__ import annotations

import sqlite3
from pathlib import Path

DB_PATH = Path.home() / ".claude" / "data" / "dashboard.db"


def _column_exists(conn: sqlite3.Connection, table: str, column: str) -> bool:
    rows = conn.execute(f"PRAGMA table_info({table});").fetchall()
    return any(row[1] == column for row in rows)


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, ddl: str) -> None:
    if not _column_exists(conn, table, column):
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {ddl};")


def ensure_github_schema(db_path: str | Path = DB_PATH) -> None:
    """Apply schema changes required for GitHub execution tracking."""
    path = Path(db_path).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path), timeout=5)
    try:
        conn.execute("PRAGMA foreign_keys = ON;")

        _ensure_column(conn, "tasks", "commit_sha", "commit_sha TEXT")
        _ensure_column(conn, "tasks", "lines_added", "lines_added INTEGER")
        _ensure_column(conn, "tasks", "lines_removed", "lines_removed INTEGER")
        _ensure_column(conn, "tasks", "files_changed", "files_changed INTEGER")
        _ensure_column(conn, "plans", "github_issue", "github_issue INTEGER")

        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS plan_commits (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plan_id INTEGER NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
                task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
                commit_sha TEXT NOT NULL,
                commit_message TEXT,
                lines_added INTEGER DEFAULT 0,
                lines_removed INTEGER DEFAULT 0,
                files_changed INTEGER DEFAULT 0,
                authored_at DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(plan_id, commit_sha)
            );

            CREATE INDEX IF NOT EXISTS idx_plan_commits_plan_id
              ON plan_commits(plan_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_plan_commits_task_id
              ON plan_commits(task_id);

            CREATE TABLE IF NOT EXISTS github_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plan_id INTEGER REFERENCES plans(id) ON DELETE CASCADE,
                task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
                event_type TEXT NOT NULL,
                event_action TEXT,
                github_id TEXT,
                payload_json TEXT,
                status TEXT NOT NULL DEFAULT 'pending'
                  CHECK(status IN ('pending', 'processed', 'failed', 'ignored')),
                event_at DATETIME,
                processed_at DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX IF NOT EXISTS idx_github_events_plan_status
              ON github_events(plan_id, status, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_github_events_type
              ON github_events(event_type, created_at DESC);
            """
        )
        conn.commit()
    finally:
        conn.close()


def main() -> int:
    ensure_github_schema(DB_PATH)
    print(f"[OK] GitHub schema migration complete: {DB_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
