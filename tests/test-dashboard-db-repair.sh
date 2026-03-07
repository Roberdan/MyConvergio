#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/dashboard-db-repair.sh"
TMPDIR="$(mktemp -d)"
DBROOT="$TMPDIR/data"
BACKUPS="$TMPDIR/.claude/backups"
mkdir -p "$DBROOT" "$BACKUPS"
DB="$DBROOT/dashboard.db"

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

sqlite3 "$DB" <<'SQL'
PRAGMA foreign_keys=OFF;
CREATE TABLE projects (id TEXT PRIMARY KEY);
CREATE TABLE plans (
  id INTEGER PRIMARY KEY,
  project_id TEXT,
  name TEXT,
  status TEXT,
  tasks_done INTEGER DEFAULT 0,
  tasks_total INTEGER DEFAULT 0,
  execution_host TEXT
);
CREATE TABLE waves (
  id INTEGER PRIMARY KEY,
  plan_id INTEGER,
  wave_id TEXT,
  status TEXT,
  tasks_done INTEGER DEFAULT 0,
  tasks_total INTEGER DEFAULT 0,
  completed_at TEXT
);
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY,
  plan_id INTEGER,
  wave_id_fk INTEGER,
  task_id TEXT,
  status TEXT
);
CREATE TABLE plan_versions (
  id INTEGER PRIMARY KEY,
  plan_id INTEGER
);

INSERT INTO projects (id) VALUES ('proj');
INSERT INTO plans (id, project_id, name, status, tasks_done, tasks_total, execution_host) VALUES
  (1, 'proj', 'Real Plan', 'doing', 99, 99, 'm1mario'),
  (2, 'ghost', 'Empty Invalid Plan', 'todo', 1, 1, 'ghost-host');
INSERT INTO waves (id, plan_id, wave_id, status, tasks_done, tasks_total) VALUES
  (10, 1, 'W1', 'pending', 9, 9);
INSERT INTO tasks (id, plan_id, wave_id_fk, task_id, status) VALUES
  (100, 1, 10, 'T1', 'done'),
  (101, 1, 10, 'T2', 'pending');
INSERT INTO plan_versions (id, plan_id) VALUES (1, 999), (2, 1);
SQL

CLAUDE_DATA="$DBROOT" HOME="$TMPDIR" bash "$SCRIPT" --apply >/dev/null

orphan_versions=$(sqlite3 "$DB" "SELECT COUNT(*) FROM plan_versions WHERE plan_id NOT IN (SELECT id FROM plans)")
bad_plans=$(sqlite3 "$DB" "SELECT COUNT(*) FROM plans WHERE project_id NOT IN (SELECT id FROM projects)")
plan_row=$(sqlite3 "$DB" "SELECT status || '|' || tasks_done || '|' || tasks_total || '|' || COALESCE(execution_host,'') FROM plans WHERE id=1")
wave_row=$(sqlite3 "$DB" "SELECT status || '|' || tasks_done || '|' || tasks_total FROM waves WHERE id=10")
backup_count=$(find "$BACKUPS" -type f | wc -l | tr -d ' ')

[[ "$orphan_versions" == "0" ]] || { echo "FAIL: orphan plan_versions remain"; exit 1; }
[[ "$bad_plans" == "0" ]] || { echo "FAIL: invalid empty plans remain"; exit 1; }
[[ "$plan_row" == "todo|1|2|" ]] || { echo "FAIL: plan not normalized ($plan_row)"; exit 1; }
[[ "$wave_row" == "in_progress|1|2" ]] || { echo "FAIL: wave not normalized ($wave_row)"; exit 1; }
[[ "$backup_count" == "1" ]] || { echo "FAIL: backup not created"; exit 1; }

echo "PASS: dashboard-db-repair normalized DB state"
