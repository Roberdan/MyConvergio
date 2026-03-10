-- init-db-migrate.sql — SAFE post-pull migration
-- Run after db-pull.sh replaces local DB with remote copy.
-- ONLY additive: CREATE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS.
-- ZERO DROP statements. ZERO ALTER TABLE on existing columns.
-- Version: 1.1.0 | 08 Mar 2026

PRAGMA journal_mode = WAL;

-- Core tables (should exist, but safety net after full DB replace)
CREATE TABLE IF NOT EXISTS notifications (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, title TEXT, message TEXT, link TEXT, link_type TEXT, is_read INTEGER DEFAULT 0, is_dismissed INTEGER DEFAULT 0, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS mesh_events (id INTEGER PRIMARY KEY AUTOINCREMENT, event_type TEXT NOT NULL, plan_id INTEGER, source_peer TEXT, target_peer TEXT, payload TEXT, status TEXT DEFAULT 'pending', created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS token_usage (id INTEGER PRIMARY KEY AUTOINCREMENT, project_id TEXT, plan_id INTEGER, task_id TEXT, model TEXT, input_tokens INTEGER DEFAULT 0, output_tokens INTEGER DEFAULT 0, cost_usd REAL DEFAULT 0, agent_type TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS conversation_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, project_id TEXT, session_id TEXT, role TEXT, content TEXT, tokens INTEGER DEFAULT 0, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS delegation_log (id INTEGER PRIMARY KEY AUTOINCREMENT, plan_id INTEGER, task_id TEXT, from_host TEXT, to_host TEXT, status TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);

-- Tables that may be missing on remote nodes
CREATE TABLE IF NOT EXISTS agent_activity (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id TEXT NOT NULL,
  task_db_id INTEGER, plan_id INTEGER,
  agent_type TEXT NOT NULL, model TEXT, description TEXT,
  status TEXT NOT NULL DEFAULT 'running',
  tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0,
  tokens_total INTEGER DEFAULT 0, cost_usd REAL DEFAULT 0,
  started_at TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at TEXT, duration_s REAL,
  host TEXT, region TEXT, metadata TEXT, parent_session TEXT
);

CREATE TABLE IF NOT EXISTS agent_runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER, wave_id TEXT, task_id TEXT,
  agent_name TEXT, agent_role TEXT, model TEXT, peer_name TEXT,
  status TEXT DEFAULT 'running',
  started_at TEXT DEFAULT (datetime('now')),
  last_heartbeat TEXT, current_task TEXT
);

CREATE TABLE IF NOT EXISTS github_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER, event_type TEXT,
  status TEXT DEFAULT 'pending',
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS earned_skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE, domain TEXT, content TEXT NOT NULL,
  confidence TEXT DEFAULT 'low', hit_count INTEGER DEFAULT 0,
  source TEXT DEFAULT 'earned',
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS plan_commits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER, commit_sha TEXT, commit_message TEXT,
  lines_added INTEGER DEFAULT 0, lines_removed INTEGER DEFAULT 0,
  files_changed INTEGER DEFAULT 0, authored_at TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS nightly_job_definitions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE, description TEXT,
  schedule TEXT NOT NULL DEFAULT '0 3 * * *',
  script_path TEXT NOT NULL,
  target_host TEXT DEFAULT 'local',
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_agent_activity_status ON agent_activity(status);
CREATE INDEX IF NOT EXISTS idx_agent_activity_plan ON agent_activity(plan_id);
CREATE INDEX IF NOT EXISTS idx_agent_activity_task ON agent_activity(task_db_id);
CREATE INDEX IF NOT EXISTS idx_agent_activity_started_at ON agent_activity(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_activity_status_started ON agent_activity(status, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_activity_status_completed ON agent_activity(status, completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_activity_model ON agent_activity(model);
CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_activity_agent_id ON agent_activity(agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_runs_started_at ON agent_runs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_runs_status ON agent_runs(status);
CREATE INDEX IF NOT EXISTS idx_agent_runs_peer ON agent_runs(peer_name);
CREATE INDEX IF NOT EXISTS idx_mesh_events_created_at ON mesh_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mesh_events_status ON mesh_events(status);
CREATE INDEX IF NOT EXISTS idx_token_usage_model ON token_usage(model);
CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage(created_at);
CREATE INDEX IF NOT EXISTS idx_github_events_plan_status ON github_events(plan_id, status);
CREATE INDEX IF NOT EXISTS idx_plan_commits_plan_id ON plan_commits(plan_id);
CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name COLLATE NOCASE);
