#!/usr/bin/env bash
set -euo pipefail

DB_PATH="${PLAN_DB_FILE:-$HOME/.claude/data/dashboard.db}"
MODE="${1:---check}"

if [[ ! -f "$DB_PATH" ]]; then
  echo "dashboard.db not found: $DB_PATH" >&2
  exit 1
fi

read -r -d '' CHECK_SQL <<'SQL' || true
WITH missing AS (
  SELECT d.id
  FROM delegation_log d
  JOIN tasks t ON t.id = d.task_db_id
  WHERE COALESCE(d.prompt_tokens, 0) + COALESCE(d.response_tokens, 0) > 0
    AND NOT EXISTS (
      SELECT 1
      FROM token_usage tu
      WHERE tu.plan_id = COALESCE(d.plan_id, t.plan_id)
        AND tu.task_id = t.task_id
        AND COALESCE(tu.agent, '') = COALESCE(NULLIF(d.provider, ''), 'delegation-log')
        AND COALESCE(tu.model, '') = COALESCE(d.model, '')
        AND COALESCE(tu.input_tokens, 0) = COALESCE(d.prompt_tokens, 0)
        AND COALESCE(tu.output_tokens, 0) = COALESCE(d.response_tokens, 0)
        AND COALESCE(tu.created_at, '') = COALESCE(d.created_at, '')
    )
)
SELECT
  (SELECT COUNT(*) FROM missing) AS missing_rows,
  (SELECT COUNT(*) FROM tasks t
   WHERE COALESCE(t.tokens, 0) = 0
     AND EXISTS (
       SELECT 1
       FROM delegation_log d
       WHERE d.task_db_id = t.id
         AND COALESCE(d.prompt_tokens, 0) + COALESCE(d.response_tokens, 0) > 0
     )) AS zero_token_tasks;
SQL

if [[ "$MODE" == "--check" ]]; then
  sqlite3 -header -column "$DB_PATH" "$CHECK_SQL"
  exit 0
fi

if [[ "$MODE" != "--apply" ]]; then
  echo "Usage: $0 [--check|--apply]" >&2
  exit 2
fi

sqlite3 "$DB_PATH" <<'SQL'
BEGIN IMMEDIATE;

CREATE INDEX IF NOT EXISTS idx_token_usage_plan_task ON token_usage(plan_id, task_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_usage_plan_created ON token_usage(plan_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delegation_log_plan_task_created ON delegation_log(plan_id, task_db_id, created_at DESC);

INSERT INTO token_usage (
  project_id,
  plan_id,
  wave_id,
  task_id,
  agent,
  model,
  input_tokens,
  output_tokens,
  cost_usd,
  created_at,
  execution_host
)
SELECT
  COALESCE(d.project_id, t.project_id),
  COALESCE(d.plan_id, t.plan_id),
  t.wave_id,
  t.task_id,
  COALESCE(NULLIF(d.provider, ''), 'delegation-log'),
  d.model,
  COALESCE(d.prompt_tokens, 0),
  COALESCE(d.response_tokens, 0),
  COALESCE(d.cost_estimate, 0),
  d.created_at,
  t.executor_host
FROM delegation_log d
JOIN tasks t ON t.id = d.task_db_id
WHERE COALESCE(d.prompt_tokens, 0) + COALESCE(d.response_tokens, 0) > 0
  AND NOT EXISTS (
    SELECT 1
    FROM token_usage tu
    WHERE tu.plan_id = COALESCE(d.plan_id, t.plan_id)
      AND tu.task_id = t.task_id
      AND COALESCE(tu.agent, '') = COALESCE(NULLIF(d.provider, ''), 'delegation-log')
      AND COALESCE(tu.model, '') = COALESCE(d.model, '')
      AND COALESCE(tu.input_tokens, 0) = COALESCE(d.prompt_tokens, 0)
      AND COALESCE(tu.output_tokens, 0) = COALESCE(d.response_tokens, 0)
      AND COALESCE(tu.created_at, '') = COALESCE(d.created_at, '')
  );

UPDATE tasks
SET tokens = COALESCE((
  SELECT SUM(COALESCE(tu.input_tokens, 0) + COALESCE(tu.output_tokens, 0))
  FROM token_usage tu
  WHERE tu.plan_id = tasks.plan_id
    AND tu.task_id = tasks.task_id
), tokens, 0)
WHERE EXISTS (
  SELECT 1
  FROM token_usage tu
  WHERE tu.plan_id = tasks.plan_id
    AND tu.task_id = tasks.task_id
);

COMMIT;
SQL

sqlite3 -header -column "$DB_PATH" "$CHECK_SQL"
