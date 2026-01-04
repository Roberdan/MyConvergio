-- Dashboard SQLite Schema
-- Version: 3.0 | Created: 4 Gennaio 2026
-- DB-first architecture: single source of truth

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  path TEXT NOT NULL,
  branch TEXT DEFAULT 'main',
  github_url TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Plans table (central plan management)
CREATE TABLE IF NOT EXISTS plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  name TEXT NOT NULL,
  source_file TEXT,
  is_master BOOLEAN DEFAULT 0,
  parent_plan_id INTEGER,
  status TEXT NOT NULL DEFAULT 'todo' CHECK(status IN ('todo', 'doing', 'done')),
  tasks_total INTEGER DEFAULT 0,
  tasks_done INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  started_at DATETIME,
  completed_at DATETIME,
  validated_at DATETIME,
  validated_by TEXT,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_plan_id) REFERENCES plans(id) ON DELETE SET NULL,
  UNIQUE(project_id, name)
);

-- Waves (belong to plans)
CREATE TABLE IF NOT EXISTS waves (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  wave_id TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'in_progress', 'done', 'blocked')),
  assignee TEXT,
  tasks_done INTEGER DEFAULT 0,
  tasks_total INTEGER DEFAULT 0,
  position INTEGER DEFAULT 0,
  started_at DATETIME,
  completed_at DATETIME,
  FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

-- Tasks (belong to waves)
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  wave_id INTEGER NOT NULL,
  task_id TEXT NOT NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'skipped')),
  assignee TEXT,
  priority TEXT DEFAULT 'P1' CHECK(priority IN ('P0', 'P1', 'P2', 'P3')),
  type TEXT DEFAULT 'feature' CHECK(type IN ('bug', 'feature', 'chore', 'doc', 'test', 'qa')),
  files TEXT,
  notes TEXT,
  position INTEGER DEFAULT 0,
  duration_minutes INTEGER,
  tokens INTEGER DEFAULT 0,
  started_at DATETIME,
  completed_at DATETIME,
  validated_at DATETIME,
  validated_by TEXT,
  FOREIGN KEY (wave_id) REFERENCES waves(id) ON DELETE CASCADE
);

-- Plan versions for tracking modifications
CREATE TABLE IF NOT EXISTS plan_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  version INTEGER NOT NULL,
  change_type TEXT NOT NULL CHECK(change_type IN ('created', 'started', 'user_edit', 'scope_add', 'scope_remove', 'blocker', 'task_split', 'completed', 'validated')),
  change_reason TEXT,
  tasks_before INTEGER,
  tasks_after INTEGER,
  changed_by TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

-- Metrics history
CREATE TABLE IF NOT EXISTS metrics_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  metric_name TEXT NOT NULL,
  metric_value REAL NOT NULL,
  recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_plans_project ON plans(project_id, status);
CREATE INDEX IF NOT EXISTS idx_plans_master ON plans(project_id, is_master);
CREATE INDEX IF NOT EXISTS idx_waves_plan ON waves(plan_id, position);
CREATE INDEX IF NOT EXISTS idx_tasks_wave ON tasks(wave_id, position);
CREATE INDEX IF NOT EXISTS idx_versions_plan ON plan_versions(plan_id, version);

-- View: Kanban board cross-project
CREATE VIEW IF NOT EXISTS v_kanban AS
SELECT
  p.id as plan_id,
  p.name as plan_name,
  p.status,
  p.is_master,
  p.tasks_done,
  p.tasks_total,
  CASE WHEN p.tasks_total > 0 THEN ROUND(100.0 * p.tasks_done / p.tasks_total) ELSE 0 END as progress,
  p.created_at,
  p.started_at,
  p.completed_at,
  pr.id as project_id,
  pr.name as project_name,
  pr.path as project_path
FROM plans p
JOIN projects pr ON p.project_id = pr.id
ORDER BY
  CASE p.status WHEN 'doing' THEN 1 WHEN 'todo' THEN 2 WHEN 'done' THEN 3 END,
  p.updated_at DESC;

-- View: Plan details with waves and tasks
CREATE VIEW IF NOT EXISTS v_plan_details AS
SELECT
  p.id as plan_id,
  p.name as plan_name,
  p.status as plan_status,
  w.id as wave_id,
  w.wave_id as wave_code,
  w.name as wave_name,
  w.status as wave_status,
  w.assignee as wave_assignee,
  t.id as task_db_id,
  t.task_id,
  t.title as task_title,
  t.status as task_status,
  t.assignee as task_assignee,
  t.priority,
  t.type,
  t.files
FROM plans p
LEFT JOIN waves w ON w.plan_id = p.id
LEFT JOIN tasks t ON t.wave_id = w.id
ORDER BY p.id, w.position, t.position;

-- View: Project plans summary
CREATE VIEW IF NOT EXISTS v_project_plans AS
SELECT
  pr.id as project_id,
  pr.name as project_name,
  COUNT(CASE WHEN p.status = 'todo' THEN 1 END) as plans_todo,
  COUNT(CASE WHEN p.status = 'doing' THEN 1 END) as plans_doing,
  COUNT(CASE WHEN p.status = 'done' THEN 1 END) as plans_done,
  COUNT(*) as plans_total
FROM projects pr
LEFT JOIN plans p ON p.project_id = pr.id
GROUP BY pr.id;
