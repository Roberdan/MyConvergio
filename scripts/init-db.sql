-- Dashboard SQLite Schema
-- Version: 1.3.0 | Created: 3 Gennaio 2026

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -8000;       -- 8MB cache (default 2MB)
PRAGMA temp_store = MEMORY;      -- temp tables in RAM
PRAGMA mmap_size = 268435456;    -- 256MB memory-mapped I/O

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
  status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'merging')),
  assignee TEXT,
  tasks_done INTEGER DEFAULT 0,
  tasks_total INTEGER DEFAULT 0,
  started_at DATETIME,
  completed_at DATETIME,
  plan_id INTEGER,
  position INTEGER DEFAULT 0,
  planned_start DATETIME,
  planned_end DATETIME,
  depends_on TEXT,
  estimated_hours INTEGER DEFAULT 8,
  markdown_path TEXT,
  precondition TEXT DEFAULT NULL,
  worktree_path TEXT,
  branch_name TEXT,
  pr_number INTEGER,
  pr_url TEXT,
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
  type TEXT CHECK(type IN ('bug', 'feature', 'fix', 'refactor', 'test', 'config', 'documentation', 'chore', 'doc')),
  duration_minutes INTEGER,
  started_at DATETIME,
  completed_at DATETIME,
  tokens INTEGER DEFAULT 0,
  validated_at DATETIME,
  validated_by TEXT,
  markdown_path TEXT,
  executor_session_id TEXT,
  executor_started_at DATETIME,
  executor_last_activity DATETIME,
  executor_status TEXT CHECK(executor_status IN ('idle', 'running', 'paused', 'completed', 'failed')),
  notes TEXT,
  wave_id_fk INTEGER,
  plan_id INTEGER REFERENCES plans(id),
  test_criteria TEXT,
  model TEXT DEFAULT 'haiku',
  description TEXT,
  output_data TEXT DEFAULT NULL,
  executor_agent TEXT DEFAULT NULL,
  executor_host TEXT DEFAULT NULL,
  effort_level INTEGER DEFAULT 1 CHECK(effort_level IN (1, 2, 3)),
  validation_report TEXT,
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
FROM (
  SELECT
    project_id,
    metric_name,
    metric_value,
    recorded_at,
    ROW_NUMBER() OVER (PARTITION BY project_id, metric_name ORDER BY recorded_at DESC) AS rn
  FROM metrics_history
)
WHERE rn = 1;

-- Plans table for centralized plan management
CREATE TABLE IF NOT EXISTS plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  plan_name TEXT NOT NULL,
  plan_file TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('draft', 'active', 'completed', 'abandoned')),
  tasks_total INTEGER DEFAULT 0,
  tasks_done INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
  UNIQUE(project_id, plan_name)
);

-- Plan versions for tracking modifications and learning
CREATE TABLE IF NOT EXISTS plan_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  plan_name TEXT NOT NULL,
  version INTEGER NOT NULL,
  change_type TEXT NOT NULL CHECK(change_type IN ('created', 'user_edit', 'scope_add', 'scope_remove', 'blocker', 'replan', 'task_split', 'completed')),
  change_reason TEXT,
  tasks_before INTEGER,
  tasks_after INTEGER,
  diff_summary TEXT,
  git_commit_hash TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Indexes for plan queries
CREATE INDEX IF NOT EXISTS idx_plans_project ON plans(project_id, status);
CREATE INDEX IF NOT EXISTS idx_plan_versions_project ON plan_versions(project_id, plan_name, version);

-- View for plan intervention statistics (learning/optimization)
CREATE VIEW IF NOT EXISTS v_plan_intervention_stats AS
SELECT
  project_id,
  plan_name,
  COUNT(*) as total_versions,
  SUM(CASE WHEN change_type = 'user_edit' THEN 1 ELSE 0 END) as user_edits,
  SUM(CASE WHEN change_type = 'blocker' THEN 1 ELSE 0 END) as blockers,
  SUM(CASE WHEN change_type = 'scope_add' THEN 1 ELSE 0 END) as scope_additions,
  SUM(CASE WHEN change_type = 'task_split' THEN 1 ELSE 0 END) as task_splits,
  MAX(version) as latest_version,
  MIN(created_at) as first_created,
  MAX(created_at) as last_modified
FROM plan_versions
GROUP BY project_id, plan_name;

-- View for aggregate learning metrics
CREATE VIEW IF NOT EXISTS v_learning_metrics AS
SELECT
  COUNT(DISTINCT project_id || '/' || plan_name) as total_plans,
  AVG(total_versions) as avg_versions_per_plan,
  SUM(user_edits) as total_user_edits,
  SUM(blockers) as total_blockers,
  CAST(SUM(user_edits) AS REAL) / COUNT(DISTINCT project_id || '/' || plan_name) as avg_edits_per_plan,
  CAST(SUM(blockers) AS REAL) / COUNT(DISTINCT project_id || '/' || plan_name) as avg_blockers_per_plan
FROM v_plan_intervention_stats;

-- Notifications for system alerts and user messages
CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT,
  type TEXT NOT NULL CHECK(type IN ('info', 'warning', 'error', 'success', 'task', 'thor')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  source TEXT,
  is_read INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  read_at DATETIME,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Conversation logs for tracking agent interactions
CREATE TABLE IF NOT EXISTS conversation_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('user', 'assistant', 'tool', 'system')),
  content TEXT NOT NULL,
  tool_name TEXT,
  tool_input TEXT,
  tool_output TEXT,
  tokens_in INTEGER DEFAULT 0,
  tokens_out INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Token usage tracking for cost analysis
CREATE TABLE IF NOT EXISTS token_usage (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT NOT NULL,
  session_id TEXT,
  task_id TEXT,
  model TEXT NOT NULL,
  tokens_input INTEGER NOT NULL DEFAULT 0,
  tokens_output INTEGER NOT NULL DEFAULT 0,
  cost_usd REAL,
  recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Indexes for new tables
CREATE INDEX IF NOT EXISTS idx_notifications_project ON notifications(project_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversation_logs_session ON conversation_logs(project_id, session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_token_usage_project ON token_usage(project_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_task ON token_usage(task_id, recorded_at DESC);

-- Indexes for task/wave lookups
CREATE INDEX IF NOT EXISTS idx_tasks_wave_fk ON tasks(wave_id_fk);
CREATE INDEX IF NOT EXISTS idx_tasks_plan ON tasks(plan_id);
CREATE INDEX IF NOT EXISTS idx_waves_plan ON waves(plan_id, position);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);

-- Covering index for frequent plan+status+wave queries
CREATE INDEX IF NOT EXISTS idx_tasks_plan_status ON tasks(plan_id, status, wave_id_fk);

-- Alias views for common agent naming mistakes
CREATE VIEW IF NOT EXISTS plan_tasks AS SELECT * FROM tasks;

-- ============================================================
-- Plan Intelligence System tables (F-05)
-- ============================================================

-- Plan reviews from reviewer agents
CREATE TABLE IF NOT EXISTS plan_reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL,
    reviewer_agent TEXT NOT NULL,
    verdict TEXT NOT NULL CHECK(verdict IN ('APPROVED', 'NEEDS_REVISION')),
    fxx_coverage_score INTEGER,
    completeness_score INTEGER,
    suggestions TEXT,
    gaps TEXT,
    risk_assessment TEXT,
    raw_report TEXT,
    reviewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

-- Business value assessments
CREATE TABLE IF NOT EXISTS plan_business_assessments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL,
    traditional_effort_days REAL,
    complexity_rating INTEGER CHECK(complexity_rating BETWEEN 1 AND 5),
    business_value_score INTEGER CHECK(business_value_score BETWEEN 1 AND 10),
    risk_assessment TEXT,
    roi_projection REAL,
    assessed_by TEXT,
    assessed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

-- Structured learnings from plan execution
CREATE TABLE IF NOT EXISTS plan_learnings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL,
    category TEXT NOT NULL,
    severity TEXT NOT NULL CHECK(severity IN ('insight', 'warning', 'critical')),
    title TEXT NOT NULL,
    detail TEXT,
    task_id TEXT,
    wave_id TEXT,
    tags TEXT,
    actionable INTEGER DEFAULT 0,
    action_taken TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

-- Token estimates per scope (task/wave/plan)
CREATE TABLE IF NOT EXISTS plan_token_estimates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL,
    scope TEXT NOT NULL CHECK(scope IN ('task', 'wave', 'plan')),
    scope_id TEXT NOT NULL,
    estimated_tokens INTEGER,
    estimated_cost_usd REAL,
    actual_tokens INTEGER,
    actual_cost_usd REAL,
    variance_pct REAL,
    model TEXT,
    executor_agent TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

-- Aggregated actuals per plan
CREATE TABLE IF NOT EXISTS plan_actuals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL UNIQUE,
    total_tokens INTEGER,
    total_cost_usd REAL,
    ai_duration_minutes REAL,
    user_spec_minutes REAL,
    total_tasks INTEGER,
    tasks_revised_by_thor INTEGER,
    thor_rejection_rate REAL,
    actual_roi REAL,
    completed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);

-- Indexes for Plan Intelligence tables
CREATE INDEX IF NOT EXISTS idx_plan_reviews_plan ON plan_reviews(plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_learnings_plan_cat ON plan_learnings(plan_id, category);
CREATE INDEX IF NOT EXISTS idx_plan_token_est_plan ON plan_token_estimates(plan_id, scope, scope_id);
CREATE INDEX IF NOT EXISTS idx_plan_actuals_plan ON plan_actuals(plan_id);

-- ============================================================
-- Plan Intelligence views (F-06)
-- ============================================================

-- ROI analysis: joins plans + business assessments + actuals
CREATE VIEW IF NOT EXISTS v_plan_roi AS
SELECT
    p.id AS plan_id,
    p.project_id,
    p.plan_name,
    p.status,
    ba.traditional_effort_days,
    ba.complexity_rating,
    ba.business_value_score,
    ba.roi_projection AS estimated_roi,
    pa.total_tokens,
    pa.total_cost_usd,
    pa.ai_duration_minutes,
    pa.user_spec_minutes,
    pa.actual_roi,
    pa.thor_rejection_rate,
    pa.tasks_revised_by_thor,
    pa.total_tasks
FROM plans p
LEFT JOIN plan_business_assessments ba ON ba.plan_id = p.id
LEFT JOIN plan_actuals pa ON pa.plan_id = p.id;

-- Learning patterns: aggregated by category with count
CREATE VIEW IF NOT EXISTS v_learning_patterns AS
SELECT
    category,
    severity,
    COUNT(*) AS occurrence_count,
    SUM(CASE WHEN actionable = 1 THEN 1 ELSE 0 END) AS actionable_count,
    SUM(CASE WHEN action_taken IS NOT NULL THEN 1 ELSE 0 END) AS resolved_count,
    COUNT(DISTINCT plan_id) AS plans_affected
FROM plan_learnings
GROUP BY category, severity;

-- Token accuracy: estimation vs actual trends by model and effort
CREATE VIEW IF NOT EXISTS v_token_accuracy AS
SELECT
    model,
    scope,
    COUNT(*) AS sample_count,
    AVG(estimated_tokens) AS avg_estimated,
    AVG(actual_tokens) AS avg_actual,
    AVG(variance_pct) AS avg_variance_pct,
    MIN(variance_pct) AS min_variance_pct,
    MAX(variance_pct) AS max_variance_pct,
    AVG(estimated_cost_usd) AS avg_estimated_cost,
    AVG(actual_cost_usd) AS avg_actual_cost
FROM plan_token_estimates
WHERE actual_tokens IS NOT NULL
GROUP BY model, scope;

-- ============================================================
-- Tasks table type CHECK update (table-rebuild approach)
-- ============================================================

-- SQLite does not support ALTER TABLE to modify CHECK constraints.
-- Rebuild tasks table with expanded type enum.
CREATE TABLE IF NOT EXISTS tasks_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id TEXT NOT NULL,
    wave_id TEXT NOT NULL,
    task_id TEXT NOT NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'skipped')),
    assignee TEXT,
    priority TEXT CHECK(priority IN ('P0', 'P1', 'P2', 'P3')),
    type TEXT CHECK(type IN ('bug', 'feature', 'fix', 'refactor', 'test', 'config', 'documentation', 'chore', 'doc')),
    duration_minutes INTEGER,
    started_at DATETIME,
    completed_at DATETIME,
    tokens INTEGER DEFAULT 0,
    validated_at DATETIME,
    validated_by TEXT,
    markdown_path TEXT,
    executor_session_id TEXT,
    executor_started_at DATETIME,
    executor_last_activity DATETIME,
    executor_status TEXT CHECK(executor_status IN ('idle', 'running', 'paused', 'completed', 'failed')),
    notes TEXT,
    wave_id_fk INTEGER,
    plan_id INTEGER REFERENCES plans(id),
    test_criteria TEXT,
    model TEXT DEFAULT 'haiku',
    description TEXT,
    output_data TEXT DEFAULT NULL,
    executor_agent TEXT DEFAULT NULL,
    executor_host TEXT DEFAULT NULL,
    effort_level INTEGER DEFAULT 1 CHECK(effort_level IN (1, 2, 3)),
    validation_report TEXT,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

INSERT INTO tasks_new SELECT * FROM tasks;
DROP TABLE IF EXISTS tasks;
ALTER TABLE tasks_new RENAME TO tasks;

-- Recreate indexes on rebuilt tasks table
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id, wave_id, task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_wave_fk ON tasks(wave_id_fk);
CREATE INDEX IF NOT EXISTS idx_tasks_plan ON tasks(plan_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_plan_status ON tasks(plan_id, status, wave_id_fk);

-- Recreate alias view (dropped with old table)
DROP VIEW IF EXISTS plan_tasks;
CREATE VIEW IF NOT EXISTS plan_tasks AS SELECT * FROM tasks;
