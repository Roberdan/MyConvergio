-- Dashboard SQLite Schema
-- Version: 2.0 | Created: 3 Gennaio 2026

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  path TEXT NOT NULL,
  branch TEXT DEFAULT 'main',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Snapshots: full plan.json captures
CREATE TABLE IF NOT EXISTS snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  plan_json TEXT NOT NULL,
  captured_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Metrics history for trend analysis
CREATE TABLE IF NOT EXISTS metrics_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  metric_name TEXT NOT NULL,
  metric_value REAL NOT NULL,
  recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Technical debt tracking
CREATE TABLE IF NOT EXISTS debt_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('todo', 'fixme', 'hack', 'deferred', 'skipped')),
  file_path TEXT NOT NULL,
  line_number INTEGER NOT NULL,
  text TEXT NOT NULL,
  author TEXT,
  found_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Wave history
CREATE TABLE IF NOT EXISTS waves (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  wave_id TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done', 'blocked')),
  assignee TEXT,
  tasks_done INTEGER DEFAULT 0,
  tasks_total INTEGER DEFAULT 0,
  started_at DATETIME,
  completed_at DATETIME,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Task history
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  wave_id TEXT NOT NULL,
  task_id TEXT NOT NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'skipped')),
  assignee TEXT,
  priority TEXT CHECK(priority IN ('P0', 'P1', 'P2', 'P3')),
  type TEXT CHECK(type IN ('bug', 'feature', 'chore', 'doc', 'test')),
  duration_minutes INTEGER,
  started_at DATETIME,
  completed_at DATETIME,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Collector runs log
CREATE TABLE IF NOT EXISTS collector_runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  collector TEXT NOT NULL CHECK(collector IN ('git', 'github', 'tests', 'debt', 'quality', 'all')),
  status TEXT NOT NULL CHECK(status IN ('success', 'error')),
  output TEXT,
  error_message TEXT,
  duration_ms INTEGER,
  run_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_snapshots_project ON snapshots(project_id, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_project ON metrics_history(project_id, metric_name, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_debt_project ON debt_items(project_id, type, resolved_at);
CREATE INDEX IF NOT EXISTS idx_waves_project ON waves(project_id, wave_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id, wave_id, task_id);
CREATE INDEX IF NOT EXISTS idx_collector_runs ON collector_runs(project_id, collector, run_at DESC);

-- Views for common queries
CREATE VIEW IF NOT EXISTS v_project_summary AS
SELECT
  p.id,
  p.name,
  p.path,
  (SELECT COUNT(*) FROM snapshots s WHERE s.project_id = p.id) as snapshot_count,
  (SELECT captured_at FROM snapshots s WHERE s.project_id = p.id ORDER BY captured_at DESC LIMIT 1) as last_snapshot,
  (SELECT COUNT(*) FROM debt_items d WHERE d.project_id = p.id AND d.resolved_at IS NULL) as open_debt
FROM projects p;

CREATE VIEW IF NOT EXISTS v_metrics_latest AS
SELECT
  project_id,
  metric_name,
  metric_value,
  recorded_at
FROM metrics_history m1
WHERE recorded_at = (
  SELECT MAX(recorded_at)
  FROM metrics_history m2
  WHERE m2.project_id = m1.project_id
  AND m2.metric_name = m1.metric_name
);
