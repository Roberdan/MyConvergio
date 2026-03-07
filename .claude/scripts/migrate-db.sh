#!/usr/bin/env bash
set -euo pipefail
# ARCHIVED: Migration already applied. Kept for reference only.
# This script should not be run again on existing databases.
#
# migrate-db.sh - Database migration script for dashboard.db
# Safe idempotent migrations - can be run multiple times without issue
# Version: 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_PATH="${HOME}/.claude/data/dashboard.db"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if database exists
if [[ ! -f "$DB_PATH" ]]; then
	log_warn "Database not found at $DB_PATH"
	log_info "Creating new database with full schema..."
	mkdir -p "$(dirname "$DB_PATH")"
	sqlite3 "$DB_PATH" <"${SCRIPT_DIR}/init-db.sql"
	log_info "Database initialized successfully"
	exit 0
fi

log_info "Migrating database at $DB_PATH"

# Function to check if table exists
table_exists() {
	local table_name="$1"
	local result
	result=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table_name';")
	[[ -n "$result" ]]
}

# Function to check if column exists in table
column_exists() {
	local table_name="$1"
	local column_name="$2"
	local result
	result=$(sqlite3 "$DB_PATH" "PRAGMA table_info($table_name);" | grep -c "^[0-9]*|$column_name|" || true)
	[[ "$result" -gt 0 ]]
}

# Migration 1: Add notifications table
if ! table_exists "notifications"; then
	log_info "Adding notifications table..."
	sqlite3 "$DB_PATH" <<'SQL'
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
CREATE INDEX IF NOT EXISTS idx_notifications_project ON notifications(project_id, is_read, created_at DESC);
SQL
	log_info "notifications table created"
else
	log_info "notifications table already exists"
fi

# Migration 2: Add conversation_logs table
if ! table_exists "conversation_logs"; then
	log_info "Adding conversation_logs table..."
	sqlite3 "$DB_PATH" <<'SQL'
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
CREATE INDEX IF NOT EXISTS idx_conversation_logs_session ON conversation_logs(project_id, session_id, created_at);
SQL
	log_info "conversation_logs table created"
else
	log_info "conversation_logs table already exists"
fi

# Migration 3: Add token_usage table
if ! table_exists "token_usage"; then
	log_info "Adding token_usage table..."
	sqlite3 "$DB_PATH" <<'SQL'
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
CREATE INDEX IF NOT EXISTS idx_token_usage_project ON token_usage(project_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_task ON token_usage(task_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_plan_task ON token_usage(plan_id, task_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_plan_created ON token_usage(plan_id, created_at DESC);
SQL
	log_info "token_usage table created"
else
	log_info "token_usage table already exists"
fi

for coldef in \
	"plan_id INTEGER" \
	"wave_id TEXT" \
	"agent TEXT" \
	"input_tokens INTEGER DEFAULT 0" \
	"output_tokens INTEGER DEFAULT 0" \
	"created_at DATETIME DEFAULT CURRENT_TIMESTAMP" \
	"execution_host TEXT"; do
	col="${coldef%% *}"
	if ! column_exists "token_usage" "$col"; then
		log_info "Adding token_usage.$col..."
		sqlite3 "$DB_PATH" "ALTER TABLE token_usage ADD COLUMN $coldef;"
	fi
done
sqlite3 "$DB_PATH" <<'SQL'
CREATE INDEX IF NOT EXISTS idx_token_usage_project ON token_usage(project_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_task ON token_usage(task_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_plan_task ON token_usage(plan_id, task_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_plan_created ON token_usage(plan_id, created_at DESC);
SQL

if ! table_exists "delegation_log"; then
	log_info "Adding delegation_log table..."
	sqlite3 "$DB_PATH" <<'SQL'
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
CREATE INDEX IF NOT EXISTS idx_delegation_log_plan_id ON delegation_log(plan_id);
CREATE INDEX IF NOT EXISTS idx_delegation_log_task_db_id ON delegation_log(task_db_id);
CREATE INDEX IF NOT EXISTS idx_delegation_log_created_at ON delegation_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delegation_log_plan_task_created ON delegation_log(plan_id, task_db_id, created_at DESC);
SQL
	log_info "delegation_log table created"
else
	sqlite3 "$DB_PATH" <<'SQL'
CREATE INDEX IF NOT EXISTS idx_delegation_log_plan_id ON delegation_log(plan_id);
CREATE INDEX IF NOT EXISTS idx_delegation_log_task_db_id ON delegation_log(task_db_id);
CREATE INDEX IF NOT EXISTS idx_delegation_log_created_at ON delegation_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delegation_log_plan_task_created ON delegation_log(plan_id, task_db_id, created_at DESC);
SQL
fi

# Migration 4: Add plans table if missing
if ! table_exists "plans"; then
	log_info "Adding plans table..."
	sqlite3 "$DB_PATH" <<'SQL'
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
CREATE INDEX IF NOT EXISTS idx_plans_project ON plans(project_id, status);
SQL
	log_info "plans table created"
else
	log_info "plans table already exists"
fi

# Migration 5: Add plan_versions table if missing
if ! table_exists "plan_versions"; then
	log_info "Adding plan_versions table..."
	sqlite3 "$DB_PATH" <<'SQL'
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
CREATE INDEX IF NOT EXISTS idx_plan_versions_project ON plan_versions(project_id, plan_name, version);
SQL
	log_info "plan_versions table created"
else
	log_info "plan_versions table already exists"
fi

# Migration 6: Add worktree_path to plans table
if ! column_exists "plans" "worktree_path"; then
	log_info "Adding worktree_path column to plans..."
	sqlite3 "$DB_PATH" "ALTER TABLE plans ADD COLUMN worktree_path TEXT;"
	log_info "worktree_path column added"
else
	log_info "plans.worktree_path already exists"
fi

# Migration 7: Add mesh_events table
if ! table_exists "mesh_events"; then
	log_info "Adding mesh_events table..."
	sqlite3 "$DB_PATH" <<'SQL'
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
SQL
	log_info "mesh_events table created"
else
	log_info "mesh_events table already exists"
fi

# Migration 8: Add live orchestration telemetry tables
if ! table_exists "agent_runs"; then
	log_info "Adding live orchestration telemetry tables..."
	sqlite3 "$DB_PATH" <<'SQL'
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
SQL
	log_info "live orchestration telemetry tables created"
else
	log_info "live orchestration telemetry tables already exist"
fi

# Verify database integrity
log_info "Verifying database integrity..."
integrity=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;")
if [[ "$integrity" == "ok" ]]; then
	log_info "Database integrity check passed"
else
	log_error "Database integrity check failed: $integrity"
	exit 1
fi

# Show table summary
log_info "Migration complete. Tables in database:"
sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" | while read -r table; do
	count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM $table;")
	echo "  - $table: $count rows"
done
