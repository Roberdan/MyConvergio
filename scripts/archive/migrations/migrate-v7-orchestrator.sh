#!/usr/bin/env bash
set -euo pipefail
# migrate-v7-orchestrator.sh - Orchestrator delegation and env-vault tracking
# Adds: delegation_log, env_vault_log tables, indexes, views
# Idempotent: uses CREATE TABLE/INDEX IF NOT EXISTS, DROP+CREATE VIEW
# Version: 1.0.0
set -euo pipefail

DB_FILE="${DB_FILE:-${CLAUDE_HOME:-$HOME/.claude}/data/dashboard.db}"

echo "=== Database Migration v7: Orchestrator Support ==="
echo "Database: $DB_FILE"

# If DB file doesn't exist, create it (allows use with a fresh temp DB)
if [[ ! -f "$DB_FILE" ]]; then
	mkdir -p "$(dirname "$DB_FILE")"
	sqlite3 "$DB_FILE" "SELECT 1;" >/dev/null
fi

# ---------------------------------------------------------------------------
# delegation_log table
# ---------------------------------------------------------------------------
echo ""
echo "Creating delegation_log table..."
sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS delegation_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    task_db_id      INTEGER,
    plan_id         INTEGER,
    project_id      TEXT,
    provider        TEXT,
    model           TEXT,
    prompt_tokens   INTEGER,
    response_tokens INTEGER,
    duration_ms     INTEGER,
    exit_code       INTEGER,
    thor_result     TEXT,
    cost_estimate   REAL,
    privacy_level   TEXT,
    created_at      DATETIME DEFAULT (datetime('now'))
);
SQL
echo "  [OK] delegation_log"

# ---------------------------------------------------------------------------
# env_vault_log table
# ---------------------------------------------------------------------------
echo ""
echo "Creating env_vault_log table..."
sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS env_vault_log (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id    TEXT,
    action        TEXT CHECK(action IN ('backup','restore','diff','audit')),
    target        TEXT CHECK(target IN ('gh','az','both')),
    vars_count    INTEGER,
    env_file      TEXT,
    status        TEXT CHECK(status IN ('success','error')),
    error_message TEXT,
    created_at    DATETIME DEFAULT (datetime('now'))
);
SQL
echo "  [OK] env_vault_log"

# ---------------------------------------------------------------------------
# Indexes
# ---------------------------------------------------------------------------
echo ""
echo "Creating indexes..."
sqlite3 "$DB_FILE" <<'SQL'
CREATE INDEX IF NOT EXISTS idx_delegation_log_task_db_id
    ON delegation_log(task_db_id);
CREATE INDEX IF NOT EXISTS idx_delegation_log_plan_id
    ON delegation_log(plan_id);
CREATE INDEX IF NOT EXISTS idx_delegation_log_created_at
    ON delegation_log(created_at);
CREATE INDEX IF NOT EXISTS idx_env_vault_log_project_id
    ON env_vault_log(project_id);
CREATE INDEX IF NOT EXISTS idx_env_vault_log_created_at
    ON env_vault_log(created_at);
SQL
echo "  [OK] Indexes created"

# ---------------------------------------------------------------------------
# Views (DROP IF EXISTS + CREATE for idempotency)
# ---------------------------------------------------------------------------
echo ""
echo "Creating views..."

sqlite3 "$DB_FILE" <<'SQL'
DROP VIEW IF EXISTS v_model_effectiveness;
CREATE VIEW v_model_effectiveness AS
SELECT
    provider,
    model,
    COUNT(*)                                AS total_delegations,
    AVG(duration_ms)                        AS avg_duration_ms,
    SUM(prompt_tokens + response_tokens)    AS total_tokens,
    SUM(cost_estimate)                      AS total_cost,
    AVG(cost_estimate)                      AS avg_cost,
    SUM(CASE WHEN exit_code = 0 THEN 1 ELSE 0 END)       AS success_count,
    SUM(CASE WHEN thor_result = 'PASS' THEN 1 ELSE 0 END) AS thor_pass_count,
    ROUND(
        100.0 * SUM(CASE WHEN exit_code = 0 THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                       AS success_rate_pct
FROM delegation_log
GROUP BY provider, model;
SQL

sqlite3 "$DB_FILE" <<'SQL'
DROP VIEW IF EXISTS v_daily_cost;
CREATE VIEW v_daily_cost AS
SELECT
    date(created_at)        AS day,
    provider,
    model,
    COUNT(*)                AS delegations,
    SUM(prompt_tokens)      AS total_prompt_tokens,
    SUM(response_tokens)    AS total_response_tokens,
    ROUND(SUM(cost_estimate), 6) AS total_cost
FROM delegation_log
GROUP BY date(created_at), provider, model
ORDER BY day DESC, total_cost DESC;
SQL

sqlite3 "$DB_FILE" <<'SQL'
DROP VIEW IF EXISTS v_delegation_summary;
CREATE VIEW v_delegation_summary AS
SELECT
    project_id,
    plan_id,
    COUNT(*)                                               AS total_delegations,
    SUM(CASE WHEN exit_code = 0  THEN 1 ELSE 0 END)       AS successes,
    SUM(CASE WHEN exit_code != 0 THEN 1 ELSE 0 END)       AS failures,
    SUM(CASE WHEN thor_result = 'PASS' THEN 1 ELSE 0 END) AS thor_passes,
    ROUND(SUM(cost_estimate), 6)                           AS total_cost,
    MIN(created_at)                                        AS first_delegation,
    MAX(created_at)                                        AS last_delegation
FROM delegation_log
GROUP BY project_id, plan_id;
SQL

sqlite3 "$DB_FILE" <<'SQL'
DROP VIEW IF EXISTS v_env_vault_status;
CREATE VIEW v_env_vault_status AS
SELECT
    project_id,
    action,
    target,
    COUNT(*)                                               AS total_ops,
    SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END)   AS success_count,
    SUM(CASE WHEN status = 'error'   THEN 1 ELSE 0 END)   AS error_count,
    MAX(created_at)                                        AS last_run,
    SUM(vars_count)                                        AS total_vars_processed
FROM env_vault_log
GROUP BY project_id, action, target;
SQL

echo "  [OK] v_model_effectiveness"
echo "  [OK] v_daily_cost"
echo "  [OK] v_delegation_summary"
echo "  [OK] v_env_vault_status"

# ---------------------------------------------------------------------------
# Verification summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Verification ==="
TABLES=$(sqlite3 "$DB_FILE" \
	"SELECT name FROM sqlite_master WHERE type='table' \
     AND name IN ('delegation_log','env_vault_log') ORDER BY name;")
echo "Tables: $(echo "$TABLES" | tr '\n' ' ')"

VIEWS=$(sqlite3 "$DB_FILE" \
	"SELECT name FROM sqlite_master WHERE type='view' \
     AND name IN ('v_model_effectiveness','v_daily_cost','v_delegation_summary','v_env_vault_status') \
     ORDER BY name;")
echo "Views:  $(echo "$VIEWS" | tr '\n' ' ')"

IDX_COUNT=$(sqlite3 "$DB_FILE" \
	"SELECT COUNT(*) FROM sqlite_master WHERE type='index' \
     AND (tbl_name='delegation_log' OR tbl_name='env_vault_log') \
     AND name NOT LIKE 'sqlite_%';")
echo "Indexes on new tables: $IDX_COUNT"

echo ""
echo "=== Migration v7 Complete ==="
