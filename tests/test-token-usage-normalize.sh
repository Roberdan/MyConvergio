#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
DB_PATH="$TMP_DIR/dashboard.db"

sqlite3 "$DB_PATH" <<'SQL'
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY,
  project_id TEXT,
  plan_id INTEGER,
  wave_id TEXT,
  task_id TEXT,
  executor_host TEXT,
  tokens INTEGER DEFAULT 0
);
CREATE TABLE delegation_log (
  id INTEGER PRIMARY KEY,
  task_db_id INTEGER,
  plan_id INTEGER,
  project_id TEXT,
  provider TEXT,
  model TEXT,
  prompt_tokens INTEGER,
  response_tokens INTEGER,
  cost_estimate REAL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE token_usage (
  id INTEGER PRIMARY KEY,
  project_id TEXT,
  plan_id INTEGER,
  wave_id TEXT,
  task_id TEXT,
  agent TEXT,
  model TEXT,
  input_tokens INTEGER,
  output_tokens INTEGER,
  cost_usd REAL,
  created_at DATETIME,
  execution_host TEXT
);

INSERT INTO tasks (id, project_id, plan_id, wave_id, task_id, executor_host, tokens)
VALUES (101, 'proj', 9, 'W1', 'T1-01', 'node-a', 0);
INSERT INTO delegation_log (id, task_db_id, plan_id, project_id, provider, model, prompt_tokens, response_tokens, cost_estimate, created_at)
VALUES (1, 101, 9, 'proj', 'copilot', 'gpt-5.3-codex', 100, 250, 0.0, '2026-03-07 09:00:00');
SQL

PLAN_DB_FILE="$DB_PATH" bash "$ROOT/scripts/token-usage-normalize.sh" --apply >/dev/null

rows="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM token_usage;")"
tokens="$(sqlite3 "$DB_PATH" "SELECT tokens FROM tasks WHERE id=101;")"
task_id="$(sqlite3 "$DB_PATH" "SELECT task_id FROM token_usage LIMIT 1;")"

[[ "$rows" == "1" ]]
[[ "$tokens" == "350" ]]
[[ "$task_id" == "T1-01" ]]

echo "test-token-usage-normalize: ok"
