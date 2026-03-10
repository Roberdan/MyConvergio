-- Dashboard SQLite Schema
-- Version: 1.5.0 | Created: 3 Gennaio 2026 | Updated: 8 Marzo 2026

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
  status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done', 'blocked', 'merging', 'cancelled')),
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
  status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'submitted', 'done', 'blocked', 'skipped', 'cancelled')),
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
  status TEXT NOT NULL CHECK(status IN ('todo', 'doing', 'done', 'cancelled')),
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

-- Mesh event queue for worker→coordinator communication
CREATE TABLE IF NOT EXISTS mesh_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_type TEXT NOT NULL,
  plan_id INTEGER,
  source_peer TEXT NOT NULL,
  payload TEXT,
  status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'delivered', 'acknowledged')),
  created_at INTEGER DEFAULT (unixepoch()),
  delivered_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_mesh_events_pending ON mesh_events(status, created_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_mesh_events_plan ON mesh_events(plan_id, event_type);

-- Nightly job runs (generic: guardian, backups, audits, custom)
CREATE TABLE IF NOT EXISTS nightly_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT,
  job_name TEXT DEFAULT 'guardian',
  started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  finished_at DATETIME,
  host TEXT,
  status TEXT NOT NULL CHECK(status IN ('running','ok','action_required','failed')),
  sentry_unresolved INTEGER DEFAULT 0,
  github_open_issues INTEGER DEFAULT 0,
  processed_items INTEGER DEFAULT 0,
  fixed_items INTEGER DEFAULT 0,
  branch_name TEXT,
  pr_url TEXT,
  summary TEXT,
  report_json TEXT
);
CREATE INDEX IF NOT EXISTS idx_nightly_jobs_started ON nightly_jobs(started_at DESC);

-- Nightly job definitions (templates for recurring jobs)
CREATE TABLE IF NOT EXISTS nightly_job_definitions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  schedule TEXT NOT NULL DEFAULT '0 3 * * *',
  script_path TEXT NOT NULL,
  target_host TEXT DEFAULT 'local',
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Live orchestration telemetry for dashboard neural/system view
CREATE TABLE IF NOT EXISTS agent_runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER,
  wave_id TEXT,
  task_id TEXT,
  parent_run_id INTEGER,
  agent_name TEXT NOT NULL,
  agent_role TEXT,
  model TEXT,
  peer_name TEXT,
  status TEXT NOT NULL CHECK(status IN ('queued','running','waiting','handoff','validating','blocked','completed','failed','cancelled')),
  current_task TEXT,
  metadata_json TEXT,
  started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_heartbeat DATETIME DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME,
  FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
);

-- Agent activity tracking (background agents, sub-agents, sessions)
CREATE TABLE IF NOT EXISTS agent_activity (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id TEXT NOT NULL,
  task_db_id INTEGER,
  plan_id INTEGER,
  agent_type TEXT NOT NULL,
  model TEXT,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'running' CHECK(status IN ('running','completed','failed','cancelled')),
  tokens_in INTEGER DEFAULT 0,
  tokens_out INTEGER DEFAULT 0,
  tokens_total INTEGER DEFAULT 0,
  cost_usd REAL DEFAULT 0,
  started_at TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at TEXT,
  duration_s REAL,
  host TEXT,
  region TEXT,
  metadata TEXT,
  parent_session TEXT,
  FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_agent_activity_status ON agent_activity(status);
CREATE INDEX IF NOT EXISTS idx_agent_activity_plan ON agent_activity(plan_id);
CREATE INDEX IF NOT EXISTS idx_agent_activity_task ON agent_activity(task_db_id);

-- GitHub integration events
CREATE TABLE IF NOT EXISTS github_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER,
  event_type TEXT,
  event_action TEXT,
  github_id TEXT,
  status TEXT DEFAULT 'pending',
  event_at TEXT,
  processed_at TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_github_events_plan ON github_events(plan_id);

-- Earned skills from knowledge base pattern recognition
CREATE TABLE IF NOT EXISTS earned_skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  domain TEXT,
  content TEXT NOT NULL,
  confidence TEXT DEFAULT 'low' CHECK(confidence IN ('low','medium','high')),
  hit_count INTEGER DEFAULT 0,
  source TEXT DEFAULT 'earned',
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Performance indexes for agent_activity (hot table: queried on every dashboard load)
CREATE INDEX IF NOT EXISTS idx_agent_activity_started_at ON agent_activity(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_activity_status_started ON agent_activity(status, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_activity_status_completed ON agent_activity(status, completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_activity_model ON agent_activity(model);
CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_activity_agent_id ON agent_activity(agent_id);

-- Performance indexes for agent_runs
CREATE INDEX IF NOT EXISTS idx_agent_runs_started_at ON agent_runs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_runs_status ON agent_runs(status);
CREATE INDEX IF NOT EXISTS idx_agent_runs_peer ON agent_runs(peer_name);

-- Performance indexes for mesh/token/commit tables
CREATE INDEX IF NOT EXISTS idx_mesh_events_created_at ON mesh_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mesh_events_status ON mesh_events(status);
CREATE INDEX IF NOT EXISTS idx_token_usage_model ON token_usage(model);
CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage(created_at);
CREATE INDEX IF NOT EXISTS idx_github_events_plan_status ON github_events(plan_id, status);
CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name COLLATE NOCASE);

-- Plan commits tracking (git integration)
CREATE TABLE IF NOT EXISTS plan_commits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER,
  commit_sha TEXT,
  commit_message TEXT,
  lines_added INTEGER DEFAULT 0,
  lines_removed INTEGER DEFAULT 0,
  files_changed INTEGER DEFAULT 0,
  authored_at TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_plan_commits_plan_id ON plan_commits(plan_id);

CREATE TABLE IF NOT EXISTS task_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER,
  wave_id TEXT,
  task_id TEXT,
  run_id INTEGER,
  event_type TEXT NOT NULL,
  status TEXT,
  severity TEXT DEFAULT 'info',
  source_agent TEXT,
  target_agent TEXT,
  peer_name TEXT,
  message TEXT,
  payload TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE,
  FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
);
CREATE TABLE IF NOT EXISTS agent_handoffs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER,
  task_id TEXT,
  from_run_id INTEGER,
  to_run_id INTEGER,
  handoff_kind TEXT DEFAULT 'delegate',
  status TEXT NOT NULL CHECK(status IN ('proposed','accepted','completed','rejected','expired')),
  reason TEXT,
  payload TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  accepted_at DATETIME,
  completed_at DATETIME,
  FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE,
  FOREIGN KEY (from_run_id) REFERENCES agent_runs(id) ON DELETE SET NULL,
  FOREIGN KEY (to_run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_agent_runs_active ON agent_runs(status, peer_name, last_heartbeat);
CREATE INDEX IF NOT EXISTS idx_agent_runs_plan ON agent_runs(plan_id, task_id);
CREATE INDEX IF NOT EXISTS idx_task_events_plan ON task_events(plan_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_task_events_run ON task_events(run_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_handoffs_plan ON agent_handoffs(plan_id, created_at DESC);

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
  project_id TEXT,
  plan_id INTEGER,
  wave_id TEXT,
  task_id TEXT,
  agent TEXT,
  model TEXT,
  input_tokens INTEGER DEFAULT 0,
  output_tokens INTEGER DEFAULT 0,
  cost_usd REAL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  execution_host TEXT,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Delegation-level token/cost telemetry for runs that predate full token_usage attribution
CREATE TABLE IF NOT EXISTS delegation_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_db_id INTEGER,
  plan_id INTEGER,
  project_id TEXT,
  provider TEXT,
  model TEXT,
  prompt_tokens INTEGER DEFAULT 0,
  response_tokens INTEGER DEFAULT 0,
  duration_ms INTEGER DEFAULT 0,
  exit_code INTEGER DEFAULT 0,
  thor_result TEXT,
  cost_estimate REAL DEFAULT 0,
  privacy_level TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for new tables
CREATE INDEX IF NOT EXISTS idx_notifications_project ON notifications(project_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversation_logs_session ON conversation_logs(project_id, session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_token_usage_project ON token_usage(project_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_task ON token_usage(task_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_plan_task ON token_usage(plan_id, task_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_plan_created ON token_usage(plan_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delegation_log_plan_id ON delegation_log(plan_id);
CREATE INDEX IF NOT EXISTS idx_delegation_log_task_db_id ON delegation_log(task_db_id);
CREATE INDEX IF NOT EXISTS idx_delegation_log_created_at ON delegation_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delegation_log_plan_task_created ON delegation_log(plan_id, task_db_id, created_at DESC);

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
    status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'submitted', 'done', 'blocked', 'skipped', 'cancelled')),
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

-- MIGRATION: tasks_new → tasks rebuild (APPLIED, DO NOT RE-RUN)
-- This was a one-time migration. On fresh DBs, tasks_new won't exist.
-- On already-migrated DBs, tasks already has the correct schema.
INSERT OR IGNORE INTO tasks SELECT * FROM tasks_new WHERE EXISTS (SELECT 1 FROM sqlite_master WHERE name='tasks_new');
DROP TABLE IF EXISTS tasks_new;

-- Recreate indexes on tasks table
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id, wave_id, task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_wave_fk ON tasks(wave_id_fk);
CREATE INDEX IF NOT EXISTS idx_tasks_plan ON tasks(plan_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_plan_status ON tasks(plan_id, status, wave_id_fk);

-- Recreate alias view (dropped with old table)
DROP VIEW IF EXISTS plan_tasks;
CREATE VIEW IF NOT EXISTS plan_tasks AS SELECT * FROM tasks;

-- Auto-increment wave/plan done counters when task goes to done
CREATE TRIGGER IF NOT EXISTS task_done_counter
AFTER UPDATE OF status ON tasks
WHEN NEW.status = 'done' AND OLD.status != 'done'
BEGIN
    UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = NEW.wave_id_fk;
    UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = NEW.plan_id;
END;

CREATE TRIGGER IF NOT EXISTS task_undone_counter
AFTER UPDATE OF status ON tasks
WHEN OLD.status = 'done' AND NEW.status != 'done'
BEGIN
    UPDATE waves SET tasks_done = tasks_done - 1 WHERE id = NEW.wave_id_fk;
    UPDATE plans SET tasks_done = tasks_done - 1 WHERE id = NEW.plan_id;
END;

-- ============================================================
-- Ideas capture system
-- ============================================================

-- Ideas table for capturing and tracking ideas
CREATE TABLE IF NOT EXISTS ideas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT,
  tags TEXT,
  priority TEXT DEFAULT 'P2' CHECK(priority IN ('P0','P1','P2','P3')),
  status TEXT DEFAULT 'draft' CHECK(status IN ('draft','elaborating','ready','promoted','archived')),
  project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
  links TEXT,
  plan_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Notes attached to ideas
CREATE TABLE IF NOT EXISTS idea_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  idea_id INTEGER NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ideas_status ON ideas(status);
CREATE INDEX IF NOT EXISTS idx_ideas_project ON ideas(project_id);
CREATE INDEX IF NOT EXISTS idx_idea_notes_idea ON idea_notes(idea_id);

-- Auto-complete wave when all tasks are done
CREATE TRIGGER IF NOT EXISTS wave_auto_complete
AFTER UPDATE OF tasks_done ON waves
WHEN NEW.tasks_done = NEW.tasks_total AND NEW.tasks_total > 0 AND NEW.status != 'done'
BEGIN
    UPDATE waves SET status = 'done', completed_at = COALESCE(completed_at, datetime('now')) WHERE id = NEW.id;
END;
