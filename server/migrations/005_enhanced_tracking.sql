-- Migration 005: Enhanced Plan Tracking with Markdown Paths, Archiving, and Session Management
-- Created: 2026-01-05
-- Purpose: Add markdown file paths, plan archiving, and executor session tracking

-- ==================================================
-- PART 1: Markdown File Path Tracking
-- ==================================================

-- Add markdown directory path to plans table
-- Path to plan directory (e.g., ~/.claude/plans/active/myproject/plan-8/)
ALTER TABLE plans ADD COLUMN markdown_dir TEXT;

-- Add markdown file paths to waves and tasks
-- Path to wave markdown file (e.g., plan-8/waves/W1-pedagogical/wave.md)
ALTER TABLE waves ADD COLUMN markdown_path TEXT;

-- Path to task markdown file (e.g., plan-8/waves/W1/tasks/T1-analysis.md)
ALTER TABLE tasks ADD COLUMN markdown_path TEXT;

CREATE INDEX idx_plans_markdown ON plans(markdown_dir) WHERE markdown_dir IS NOT NULL;
CREATE INDEX idx_waves_markdown ON waves(markdown_path) WHERE markdown_path IS NOT NULL;
CREATE INDEX idx_tasks_markdown ON tasks(markdown_path) WHERE markdown_path IS NOT NULL;

-- ==================================================
-- PART 2: Plan Archiving
-- ==================================================

ALTER TABLE plans ADD COLUMN archived_at DATETIME;
-- Path after archiving (e.g., ~/.claude/plans/archived/2026-01/myproject/plan-8/)
ALTER TABLE plans ADD COLUMN archived_path TEXT;

CREATE INDEX idx_plans_archived ON plans(archived_at) WHERE archived_at IS NOT NULL;

-- ==================================================
-- PART 3: Executor Session Tracking
-- ==================================================

-- Claude session ID executing this task
ALTER TABLE tasks ADD COLUMN executor_session_id TEXT;
ALTER TABLE tasks ADD COLUMN executor_started_at DATETIME;
ALTER TABLE tasks ADD COLUMN executor_last_activity DATETIME;
-- Real-time executor status for live monitoring
ALTER TABLE tasks ADD COLUMN executor_status TEXT CHECK(executor_status IN ('idle', 'running', 'paused', 'completed', 'failed'));

CREATE INDEX idx_tasks_executor ON tasks(executor_session_id) WHERE executor_session_id IS NOT NULL;
CREATE INDEX idx_tasks_executor_active ON tasks(executor_status) WHERE executor_status IN ('running', 'paused');

-- ==================================================
-- PART 4: Conversation Logs
-- ==================================================

CREATE TABLE conversation_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL,
  session_id TEXT NOT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  role TEXT NOT NULL CHECK(role IN ('user', 'assistant', 'tool', 'system')),
  content TEXT,
  tool_name TEXT,
  tool_input JSON,
  tool_output JSON,
  metadata JSON,
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE INDEX idx_conversation_task ON conversation_logs(task_id, timestamp);
CREATE INDEX idx_conversation_session ON conversation_logs(session_id, timestamp);
CREATE INDEX idx_conversation_role ON conversation_logs(role, timestamp);

-- Real-time conversation log for executor sessions
-- role: user (input), assistant (Claude response), tool (tool call), system (internal)
-- metadata: Additional context like tokens, model, thinking_time, etc.

-- ==================================================
-- PART 5: Views for Monitoring
-- ==================================================

-- View: Active executing tasks with latest activity
CREATE VIEW v_active_executions AS
SELECT
  t.id,
  t.project_id,
  t.wave_id,
  t.task_id,
  t.title,
  t.executor_session_id,
  t.executor_status,
  t.executor_started_at,
  t.executor_last_activity,
  (julianday('now') - julianday(t.executor_last_activity)) * 24 * 60 AS minutes_since_activity,
  w.name AS wave_name,
  p.name AS plan_name
FROM tasks t
JOIN waves w ON t.wave_id = w.wave_id AND t.project_id = w.project_id
LEFT JOIN plans p ON w.plan_id = p.id
WHERE t.executor_status IN ('running', 'paused')
ORDER BY t.executor_last_activity DESC;

-- View: Conversation summary per task
CREATE VIEW v_task_conversations AS
SELECT
  task_id,
  session_id,
  COUNT(*) AS message_count,
  SUM(CASE WHEN role = 'tool' THEN 1 ELSE 0 END) AS tool_calls,
  MIN(timestamp) AS session_start,
  MAX(timestamp) AS session_end,
  MAX(timestamp) AS last_activity
FROM conversation_logs
GROUP BY task_id, session_id;

-- ==================================================
-- MIGRATION COMPLETE
-- ==================================================
